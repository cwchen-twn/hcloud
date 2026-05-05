# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Infrastructure-as-code for a single-node Hetzner VPS running a K3S cluster, with Cloudflare for DNS. The stack is:

- **Terraform** — provisions the Hetzner server, network, firewall, primary IPs, and Cloudflare DNS records
- **Cloud-init** (`modules/hetzner/cloud-init.yaml`) — bootstraps PostgreSQL 17 and K3S on first boot; K3S uses Postgres as its datastore
- **Helm charts** (`k3s/helm/`) — local charts deployed to the K3S cluster
- **SSH tunnels** (`sshtunnels/`) — systemd user services forwarding ports 5432 (Postgres) and 16443 (K3S API) from the remote VPS to localhost

## Terraform state

State is stored in a Cloudflare R2 bucket (`tf-state`). Before the first `terraform init`, the bucket must exist:

```bash
bun install
bun run create          # creates the tf-state R2 bucket via wrangler
cp backend.hcl.example backend.hcl   # fill in R2 credentials
terraform init -backend-config=backend.hcl
```

## Common Terraform commands

```bash
terraform plan
terraform apply
terraform destroy
```

## SSH tunnels setup

```bash
cd sshtunnels/
# Set SSH_USER and REMOTE_HOST in sshtunnels/.env
bash install_tunnel.sh

systemctl status --user k3s-ssh-tunnel.service
systemctl status --user postgres-tunnel.service
journalctl --user --unit=k3s-ssh-tunnel.service --no-pager
```

After the tunnel is running, copy the K3S kubeconfig:

```bash
scp -i ~/.ssh/id_ed25519_hetzner <user>@<host>:/etc/rancher/k3s/k3s.yaml ~/.kube/config
# Edit server to: https://127.0.0.1:16443
# Set context/cluster/user names to: hcloud
kubectl get nodes
```

## Helm charts

### cf-certificate (local chart)

Installs a cert-manager `ClusterIssuer` (Let's Encrypt via Cloudflare DNS-01) and a wildcard `Certificate`:

```bash
helm install cf-certificate k3s/helm/cf-certificate \
  --set cfToken="xxx" \
  --set cfDnsZone=example.com \
  --set leEmail=xxx@example.com \
  --set cfEmail=xxx@example.com \
  --create-namespace -n cert-manager

# Render to inspect
helm template k3s/helm/cf-certificate --set cfToken="x" --set cfDnsZone=example.com ...
```

cert-manager itself must be pre-installed:

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.17.2 --set crds.enabled=true
```

### monitoring (local chart with sub-chart dependencies)

Uses `k3s/helm/monitoring/`. Deploys Prometheus, Grafana, Node Exporter, and Postgres Exporter as Helm sub-chart dependencies. Also creates a `ClusterIP` service (`traefik-metrics.kube-system`) so Prometheus can scrape Traefik. Traefik metrics are enabled via `k3s/traefik-helmchartconfig.yaml` (a K3S-level config applied separately with `kubectl apply` — see below).

Sensitive values come from the `monitor-secrets` Kubernetes secret:

```bash
kubectl create secret generic monitor-secrets -n monitoring \
  --from-literal=GF_ADMIN_USER="admin" \
  --from-literal=GF_ADMIN_PASSWORD="xxx" \
  --from-literal=PG_DATA_SOURCE="postgresql://user:pass@10.0.1.1:5432/postgres?sslmode=disable"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm dependency update k3s/helm/monitoring

helm install monitoring k3s/helm/monitoring -n monitoring --create-namespace

# Upgrade
helm dependency update k3s/helm/monitoring
helm upgrade -i monitoring k3s/helm/monitoring -n monitoring --reset-then-reuse-values
```

Grafana is accessible at `https://grafana.chenantunez.com`. Three dashboards (Node Exporter Full ID 1860, PostgreSQL ID 9628, Traefik ID 17346) are downloaded from grafana.com on first startup. The release name **must** be `monitoring` — the Prometheus server URL and scrape targets in `values.yaml` are hardcoded to `monitoring-prometheus-server.monitoring.svc.cluster.local` and related service names derived from that release name.

### Vaultwarden (upstream chart + local values)

Uses `k3s/helm/vaultwarden/values.yaml`. Sensitive values come from the `vw-secrets` Kubernetes secret:

```bash
kubectl create secret generic vw-secrets -n vaultwarden \
  --from-literal=PG_URI="postgresql://user:pass@host:port/vaultwarden" \
  --from-literal=VW_HOST="vw.example.com" \
  --from-literal=VW_ADMIN_TOKEN="xxx" \
  --from-literal=SMTP_USER="xxx" \
  --from-literal=SMTP_PASSWD="xxx"

# Apply PVC before installing
kubectl apply -f k3s/helm/vaultwarden/vw-pvc.yaml

helm install vaultwarden vaultwarden/vaultwarden \
  -n vaultwarden \
  --set domain="https://vw.example.com/" \
  --set ingress.hostname="vw.example.com" \
  --set ingress.tlsSecret="example.com-tls" \
  --set smtp.host="smtp.purelymail.com" \
  --set smtp.port=465 \
  --set smtp.from="xxx@example.com" \
  -f k3s/helm/vaultwarden/values.yaml

# Upgrade
helm upgrade -i vaultwarden vaultwarden/vaultwarden \
  -n vaultwarden --version 0.36.2 --reset-then-reuse-values
```

### Gitea (local chart wrapper with sub-chart dependency)

Uses `k3s/helm/gitea/`. A local chart wrapper (same pattern as monitoring) that bundles a cert-manager `Certificate`, a `PersistentVolumeClaim`, and the upstream `gitea/gitea` chart as a sub-chart dependency. Registration is disabled; SSH git access is on port 2222.

Sensitive values come from the `gitea-secrets` Kubernetes secret:

```bash
kubectl create secret generic gitea-secrets -n gitea \
  --from-literal=username="<admin_user>" \
  --from-literal=password="<admin_password>" \
  --from-literal=DB_HOST="xx.xx.xx.xx:xxx" \
  --from-literal=DB_PASSWORD="<db_password>"
```

Before installing, create the Postgres database on the VPS:

```bash
psql -U postgres -c "CREATE USER cwc1222 WITH PASSWORD 'xxx';"
psql -U postgres -c "CREATE DATABASE gitea OWNER cwc1222;"
```

```bash
helm repo add gitea https://dl.gitea.com/charts/
helm repo update
helm dependency update k3s/helm/gitea

helm install gitea k3s/helm/gitea -n gitea --create-namespace

# Upgrade
helm upgrade -i gitea k3s/helm/gitea -n gitea
```

Gitea is accessible at `https://git.chenantunez.com`. SSH git clones use port 2222: `ssh://git@git.chenantunez.com:2222/<user>/<repo>.git`.

**Admin password note:** `passwordMode: initialOnlyNoReset` means the password is only set on the very first user creation. If you need to reset it (e.g. after wiping and recreating the DB), use:

```bash
kubectl exec -n gitea -c gitea \
  $(kubectl get pod -n gitea -l app.kubernetes.io/name=gitea -o jsonpath='{.items[0].metadata.name}') \
  -- gitea admin user change-password --username <user> --password <new_password>
```

**Fresh install note:** Gitea user data lives in Postgres, not the PVC (the PVC stores git repositories). Deleting the PVC alone does not give a clean slate — you must also drop and recreate the `gitea` database.

## Architecture notes

- The firewall opens ports 22, 80, 443, and 2222 (Gitea SSH); all other access (Postgres, K3S API) goes through SSH tunnels.
- PostgreSQL on the VPS serves K3S (as its HA datastore), Vaultwarden, and Gitea. K3S pods reach Postgres via the host's private IP (`10.0.1.1`) on the `10.0.1.0/24` subnet; `pg_hba.conf` allows `10.42.0.0/16` (K3S pod CIDR) with password auth.
- The `cf-certificate` chart creates a single wildcard cert (`*.domain.tld`) stored as `<domain>-tls` secret, shared by all ingresses.
- Vaultwarden's `values.yaml` references `vw-secrets` for all sensitive config; nothing sensitive lives in values files.
- K3S uses Traefik as its ingress controller (installed by default). `k3s/traefik-helmchartconfig.yaml` is a cluster-level config applied with `kubectl apply` (not Helm) that enables Prometheus metrics and preserves the existing access-log settings. K3S's addon system owns the `traefik` HelmChartConfig, so Helm cannot manage it; changes here cause a Traefik pod restart.
- Automated K3S upgrades are managed by the system-upgrade-controller, installed via cloud-init.
- The monitoring and Gitea charts each create their own cert-manager `Certificate` resource in their respective namespaces (via `templates/certificate.yaml`), which causes cert-manager to copy the wildcard TLS secret into that namespace. All ingresses reference `chenantunez.com-tls` locally.
- The Gitea chart uses `strategy.type: Recreate` instead of `RollingUpdate` because `hostPort: 2222` cannot be held by two pods simultaneously during a rolling update.
- PurelyMail email DNS records (MX, SPF, DKIM×3, DMARC, ownership proof) are managed in `modules/cloudflare/main.tf` as part of the main Terraform root — there is no separate `email/` root. `purelymail_ownership_proof` and `subdomains` are root-level variables set in `terraform.tfvars`.
- The Hetzner server resource has `lifecycle { ignore_changes = [user_data] }` so that changes to `cloud-init.yaml` after initial provisioning do not trigger a server rebuild.
