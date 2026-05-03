# K3S client setup

The root of the project manages an remote k3s cluster on hetzner VPS.
After the VPS provision, we can use the local kubectl/helm to interact with the remote cluster.

## Quickstart Guide

First of all, ensure kubectl, kubectx, and helm are installed.
The *install-client.sh* in the same folder uses apt to install the clients.

```bash
bash install-client.sh
kubectl version
```

After the installation, setup the ssl tunnel to connect to the remote cluster

```bash
cd ../sshtunnels
# Ensure the ../sshtunnels.env file has the following two variables
# SSH_USER="xxx" your hetzner VPS SSH user
# REMOTE_HOST="xxx" hetzner VPS public IPv4 address
bash install_tunnel.sh
systemctl status --user k3s-ssh-tunnel.service
journalctl --user --unit=k3s-ssh-tunnel.service --no-pager
```

Then modify the local kube config using the remote cluster credentials

```bash
mkdir ~/.kube
scp -i ~/.ssh/id_ed25519_hetzner xxx@xxx:/etc/rancher/k3s/k3s.yaml ~/.kube/config
# Then modify the following variables:
# server: https://127.0.0.1:16443
# name: hcloud
# cluster: hcloud
# user: hcloud
# current-context: hcloud
kubectl get nodes

# https://docs.k3s.io/upgrades/automated
# Check the automated upgrades plans
kubectl -n system-upgrade get plans -o wide
kubectl -n system-upgrade get jobs
```

## Necessary Secrets

```bash
kubectl create secret generic vw-secrets -n catopia \
  --from-literal=PG_URI="postgresql://xxx:xxx@xx.xx.xx.xx:xxx/vaultwarden" \
  --from-literal=VW_HOST="xxx.xxx.xxx" \
  --from-literal=VW_ADMIN_TOKEN="xxx" \
  --from-literal=SMTP_USER="xxx" \
  --from-literal=SMTP_PASSWD="xxx"

kubectl create secret generic monitor-secrets -n monitoring \
  --from-literal=GF_ADMIN_USER="admin" \
  --from-literal=GF_ADMIN_PASSWORD="xxx" \
  --from-literal=PG_DATA_SOURCE="postgresql://xxx:xxx@xx.xx.xx.xx:xxx/postgres?sslmode=disable"

kubectl create secret generic gitea-secrets -n gitea \
  --from-literal=username="xxx" \
  --from-literal=password="xxx" \
  --from-literal=DB_HOST="xx.xx.xx.xx:xxx" \
  --from-literal=DB_PASSWORD="xxx"
```

## Traefik Configuration

`k3s/traefik-helmchartconfig.yaml` customizes K3S's managed Traefik deployment. It is applied with `kubectl apply` rather than Helm because K3S's internal addon system owns the `traefik` HelmChartConfig resource and Helm cannot adopt it.

```bash
kubectl apply -f k3s/traefik-helmchartconfig.yaml
```

Current config: access logging (JSON format) + Prometheus metrics endpoint on port 9100 (internal only, scraped by the monitoring chart).

## Helm Charts

### Cert Manager and CF-Certificates

#### Cert Manager - REF

- [cert-manager.io/docs/installation/helm](https://cert-manager.io/docs/installation/helm/)
- [cert-manager.io/docs/tutorials/acme/dns-validation](https://cert-manager.io/docs/tutorials/acme/dns-validation/)
- [gist.github.com/davidcallen](https://gist.github.com/davidcallen/86ea7b19ff74abb72b0d671d1885a889)
- [k3s.rocks/https-cert-manager-letsencrypt](https://k3s.rocks/https-cert-manager-letsencrypt/)

1. [Install the cert manager using helm](https://cert-manager.io/docs/installation/helm/#installing-with-helm)

    ```bash
    # https://cert-manager.io/docs/installation/helm/
    helm repo add jetstack https://charts.jetstack.io --force-update
    
    helm install \
      cert-manager jetstack/cert-manager \
      --namespace cert-manager \
      --create-namespace \
      --version v1.17.2 \
      --set crds.enabled=true

    # https://cert-manager.io/docs/installation/upgrade/
    helm search repo jetstack/cert-manager --versions
    helm upgrade \
      --namespace cert-manager \
      --reset-then-reuse-values \
      --version v1.18.2 \
      cert-manager jetstack/cert-manager

    # https://cert-manager.io/docs/installation/kubectl/#verify
    helm ls --all-namespaces
    kubectl get pods -n cert-manager
    ```

2. Install the cluster issuer

    ```bash
    helm install cf-certificate k3s/helm/cf-certificate \
      --set cfToken="xxx" \
      --set cfDnsZone=xxx.xxx \
      --set leEmail=xxx@xxx.xxx \
      --set cfEmail=xxx@xxx.xxx \
      --create-namespace \
      -n xxx
    ```

    ```bash
    helm template . \
      --set cfToken="xxx" \
      --set cfDnsZone=xxx.xxx \
      --set leEmail=xxx@xxx.xxx \
      --set cfEmail=xxx@xxx.xxx
    ```

### Vaultwarden

#### Vaultwarden - REF

- [github.com/guerzon/vaultwarden/Readme.md](https://github.com/guerzon/vaultwarden/blob/main/charts/vaultwarden/README.md)

```bash
# Installation
# helm uninstall vaultwarden -n catopia
export RELEASE_NAME=vaultwarden
export NAMESPACE=catopia

helm install \
  $RELEASE_NAME vaultwarden/vaultwarden \
  -n $NAMESPACE \
  --set domain="https://vw.chenantunez.com/" \
  --set ingress.hostname="vw.chenantunez.com" \
  --set ingress.tlsSecret="chenantunez.com-tls" \
  --set smtp.host="xxx" \
  --set smtp.port=xxx \
  --set smtp.from="xxx" \
  -f values.yaml

# Upgrade
# helm repo update
# helm search repo vaultwarden --versions
export VERSION=0.36.2

helm upgrade -i \
  $RELEASE_NAME vaultwarden/vaultwarden \
  -n $NAMESPACE \
  --version $VERSION \
  --reset-then-reuse-values
```

#### Vaultwarden - Postgres Backup

```bash
# Backup on the original digital ocean droplet using nerdctl
nerdctl exec --user postgres -it postgres pg_dump vaultwarden > vw.sql

# Restore on the hetzner VPS using psql
psql -U cwc1222 -d vaultwarden -f vw.sql
```

### Monitoring (Prometheus + Grafana)

Local chart at `k3s/helm/monitoring`. Deploys: Prometheus, Grafana, Node Exporter, Postgres Exporter, and enables Traefik metrics.

#### Add helm repos and fetch dependencies

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm dependency update k3s/helm/monitoring
```

#### Install

```bash
export RELEASE_NAME=monitoring
export NAMESPACE=monitoring

kubectl create namespace $NAMESPACE

# Create monitor-secrets before installing (see Necessary Secrets above)

# Apply Traefik metrics config if not already done (see Traefik Configuration above)
kubectl apply -f k3s/traefik-helmchartconfig.yaml

helm install \
  $RELEASE_NAME k3s/helm/monitoring \
  -n $NAMESPACE

# Verify all pods come up
kubectl get pods -n $NAMESPACE
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
```

Grafana is available at `https://grafana.chenantunez.com` once the ingress and TLS certificate are ready. The three dashboards (Node Exporter Full, PostgreSQL, Traefik) are downloaded from grafana.com on first pod startup.

#### Upgrade

```bash
helm dependency update k3s/helm/monitoring

helm upgrade -i \
  $RELEASE_NAME k3s/helm/monitoring \
  -n $NAMESPACE \
  --reset-then-reuse-values
```

#### Upgrade sub-chart versions (Prometheus, Grafana, Node Exporter, Postgres Exporter)

Sub-chart versions are constrained by the `^` (caret) ranges in `k3s/helm/monitoring/Chart.yaml`. Running `helm dependency update` pulls the latest version within each range automatically — no manual edits needed unless you want to cross a major version boundary.

```bash
# See what versions are currently locked
cat k3s/helm/monitoring/Chart.lock

# Check what newer versions are available within the current ranges
helm search repo prometheus-community/prometheus --versions | head -5
helm search repo grafana/grafana --versions | head -5
helm search repo prometheus-community/prometheus-node-exporter --versions | head -5
helm search repo prometheus-community/prometheus-postgres-exporter --versions | head -5

# Pull latest versions within the ^ ranges and upgrade
helm repo update
helm dependency update k3s/helm/monitoring
helm upgrade -i monitoring k3s/helm/monitoring -n monitoring --reset-then-reuse-values
```

To upgrade across a major version (e.g. grafana `^8` → `^9`), edit the version constraint in `k3s/helm/monitoring/Chart.yaml` first, then run the commands above. Check the chart's changelog for breaking changes before doing so.

#### Verify Traefik metrics

```bash
# After the HelmChartConfig is applied, Traefik pods restart automatically.
# Confirm the metrics service is up and reachable from within the cluster:
kubectl get svc traefik-metrics -n kube-system
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -s http://traefik-metrics.kube-system.svc.cluster.local:9100/metrics | head -20
```

### Gitea

Local chart wrapper at `k3s/helm/gitea`. Bundles a cert-manager `Certificate`, a `PersistentVolumeClaim`, and the upstream `gitea/gitea` chart as a sub-chart dependency. Uses the existing VPS Postgres instance; registration is disabled; SSH git access is on port 2222.

#### Add helm repo and fetch dependencies

```bash
helm repo add gitea https://dl.gitea.com/charts/
helm repo update

helm dependency update k3s/helm/gitea
```

#### Prepare Postgres (run on VPS)

```bash
psql -U postgres -c "CREATE USER cwc1222 WITH PASSWORD 'xxx';"
psql -U postgres -c "CREATE DATABASE gitea OWNER cwc1222;"
```

#### Install

```bash
export RELEASE_NAME=gitea
export NAMESPACE=gitea

kubectl create namespace $NAMESPACE

# Create gitea-secrets before installing (see Necessary Secrets above)

helm install $RELEASE_NAME k3s/helm/gitea -n $NAMESPACE

# Verify pods come up
kubectl get pods -n $NAMESPACE
```

Gitea is available at `https://git.chenantunez.com`. SSH git clones use port 2222:

```bash
git clone ssh://git@git.chenantunez.com:2222/<user>/<repo>.git
```

#### Upgrade

```bash
helm upgrade -i gitea k3s/helm/gitea -n gitea
```

#### Reset admin password

`passwordMode: initialOnlyNoReset` means the password is set only on the very first user creation. To reset it:

```bash
kubectl exec -n gitea -c gitea \
  $(kubectl get pod -n gitea -l app.kubernetes.io/name=gitea -o jsonpath='{.items[0].metadata.name}') \
  -- gitea admin user change-password --username <user> --password <new_password>
```

#### Fresh install (clean slate)

Gitea stores user accounts in Postgres, not the PVC (the PVC holds git repositories). Deleting the PVC alone is not enough — drop and recreate the database too:

```bash
psql -U postgres -c "DROP DATABASE gitea;"
psql -U postgres -c "CREATE DATABASE gitea OWNER cwc1222;"
```

Then reinstall:

```bash
helm upgrade -i gitea k3s/helm/gitea -n gitea
```

## Hetzner SMTP configurations

1. Test the email service provider

    ```bash
    swaks \
      --to xxx@gmail.com \
      --from xxx@xxx.com \
      --server smtp.purelymail.com \
      --port 465 \
      --auth LOGIN \
      --auth-user xxx@xxx.com \
      --auth-password 'xxxx' \
      --tls-on-connect \
      --header "Subject: Test email via swaks" \
      --body "This is a test email sent using swaks."
    ```

2. Request Hetzner to enable the SMTP

    ```bash
    - go to https://console.hetzner.com/support
    - Create a new support request > Technical > Server Issue: Sending mails not possible
    - Write down the requests, usages
    ```
