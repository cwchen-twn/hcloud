---
name: grafana-dashboard
description: Add a new Grafana dashboard to the monitoring Helm chart in this repository. Use when the user asks to add, create, or expose metrics in Grafana.
---

# Adding a Grafana dashboard to this repo

The monitoring stack lives in `k3s/helm/monitoring/`. Grafana discovers dashboards via a sidecar that watches ConfigMaps labeled `grafana_dashboard: "1"`.

## Step 1 — Find the right dashboard

Search grafana.com for a community dashboard. Prefer ones that say "cAdvisor metrics only" or match the exporters already scraped (see `values.yaml` `extraScrapeConfigs`).

**Already-scraped jobs** (no new scrape config needed):
- `node-exporter` — node CPU/memory/disk/network
- `postgres-exporter` — PostgreSQL
- `traefik` — Traefik ingress
- `gitea` — Gitea
- `kubernetes-nodes-cadvisor` — container/pod CPU, memory, network (built-in, `instance="catopia"`)
- `kubernetes-nodes` — kubelet metrics (built-in, `instance="catopia"`)
- `kubernetes-apiservers` — K3S API server (built-in)

**Before adding a new scrape job**, check if the Prometheus chart already creates it:
```bash
kubectl exec -n monitoring <prometheus-pod> -c prometheus-server -- \
  wget -qO- 'http://localhost:9090/api/v1/targets?state=active' | python3 -m json.tool | grep '"job"'
```

## Step 2 — Download the dashboard JSON

```bash
curl -s https://grafana.com/api/dashboards/<ID>/revisions/latest/download \
  > k3s/helm/monitoring/files/dashboards/<name>.json
```

## Step 3 — Fix the datasource UID

Community dashboards use a hardcoded UID or `${DS_PROMETHEUS}`. Replace both with the string `"Prometheus"` to match the provisioned datasource:

```bash
# Find what UID is used
python3 -c "
import json
with open('k3s/helm/monitoring/files/dashboards/<name>.json') as f:
    d = json.load(f)
for p in d.get('panels', []):
    if 'datasource' in p:
        print(p['datasource'])
        break
print('inputs:', d.get('__inputs', []))
"

# Replace hardcoded UID (do this for every unique UID found)
sed -i 's/"<HARDCODED_UID>"/"Prometheus"/g' k3s/helm/monitoring/files/dashboards/<name>.json

# Also replace the ${DS_PROMETHEUS} input variable reference
sed -i 's/"\${DS_PROMETHEUS}"/"Prometheus"/g' k3s/helm/monitoring/files/dashboards/<name>.json

python3 -m json.tool k3s/helm/monitoring/files/dashboards/<name>.json > /dev/null && echo "Valid JSON"
```

## Step 4 — Check template variables against actual labels

Dashboard template variables often query labels that don't exist in the collected data.

```bash
# See what labels the dashboard variable queries
python3 -c "
import json
with open('k3s/helm/monitoring/files/dashboards/<name>.json') as f:
    d = json.load(f)
for v in d['templating']['list']:
    print(v['name'], ':', v.get('query', {}).get('query', ''))
"

# Verify the queried label exists in Prometheus
kubectl exec -n monitoring <prometheus-pod> -c prometheus-server -- \
  wget -qO- 'http://localhost:9090/api/v1/label/<label_name>/values'
```

### Common label mismatch — `node` vs `instance`

Dashboard 19972 (K3S Monitoring) uses `node=~"^$Node$"` but the Prometheus chart's
`kubernetes-nodes-cadvisor` job sets `instance="catopia"` (the hostname), not a `node` label.

**Fix with Python:**
```python
import json, re

path = 'k3s/helm/monitoring/files/dashboards/<name>.json'
with open(path) as f:
    d = json.load(f)

# Fix $Node variable to query instance label from the right job
for var in d['templating']['list']:
    if var['name'] == 'Node':
        q = 'label_values(container_cpu_usage_seconds_total{job="kubernetes-nodes-cadvisor"}, instance)'
        var['definition'] = q
        var['query']['query'] = q

# Replace node label filter with instance in all PromQL expressions
def fix_expr(expr):
    expr = re.sub(r'\bnode=~"([^"]*)"', r'instance=~"\1"', expr)
    expr = re.sub(r'\bby\s*\(\s*node\b', 'by (instance', expr)
    return expr

def walk(obj):
    if isinstance(obj, dict):
        if 'expr' in obj: obj['expr'] = fix_expr(obj['expr'])
        for v in obj.values(): walk(v)
    elif isinstance(obj, list):
        for v in obj: walk(v)

walk(d)

with open(path, 'w') as f:
    json.dump(d, f, indent=2)
```

## Step 5 — Create the ConfigMap template

```bash
cat > k3s/helm/monitoring/templates/grafana-dashboard-<name>.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-<name>
  namespace: {{ .Release.Namespace }}
  labels:
    grafana_dashboard: "1"
data:
  <name>.json: |-
{{ .Files.Get "files/dashboards/<name>.json" | indent 4 }}
EOF
```

## Step 6 — Validate and deploy

```bash
# Helm dry-run (look for "Error" lines that aren't inside JSON strings)
helm template monitoring k3s/helm/monitoring 2>&1 | grep -i "^Error"

# Deploy
helm upgrade -i monitoring k3s/helm/monitoring -n monitoring --reset-then-reuse-values

# Verify the ConfigMap was picked up by the Grafana sidecar (give it ~30s)
kubectl get configmap -n monitoring | grep grafana-dashboard

# Verify the template variable resolves to actual values
kubectl exec -n monitoring <prometheus-pod> -c prometheus-server -- \
  wget -qO- 'http://localhost:9090/api/v1/label/instance/values?match[]=container_cpu_usage_seconds_total{job="kubernetes-nodes-cadvisor"}'
```

## Adding a new Prometheus scrape job

Only add a job if the data is not already collected (check Step 1 first). Add to `extraScrapeConfigs` in `values.yaml`:

```yaml
prometheus:
  extraScrapeConfigs: |
    - job_name: 'my-exporter'
      static_configs:
        - targets:
            - 'my-service.my-namespace.svc.cluster.local:9100'
```

For HTTPS endpoints (e.g. kubelet) use the service account token:
```yaml
    - job_name: 'my-https-exporter'
      scheme: https
      tls_config:
        insecure_skip_verify: true
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      static_configs:
        - targets:
            - '10.0.1.1:10250'
      metrics_path: /metrics/cadvisor
```

**Do not** add static-IP scrape jobs for kubelet or cAdvisor — they duplicate the chart's
built-in `kubernetes-nodes`, `kubernetes-nodes-cadvisor`, and `kubernetes-apiservers` jobs.

## File layout summary

```
k3s/helm/monitoring/
├── files/dashboards/
│   ├── k3s.json                         ← dashboard 19972, patched
│   ├── node-exporter.json
│   ├── postgres-exporter.json
│   └── traefik.json
└── templates/
    ├── grafana-dashboard-k3s.yaml       ← ConfigMap, label grafana_dashboard: "1"
    ├── grafana-dashboard-node-exporter.yaml
    ├── grafana-dashboard-postgres-exporter.yaml
    └── grafana-dashboard-traefik.yaml
```
