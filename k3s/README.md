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
```

## Helm Charts

### Cert Manager and CF-Certificates

**REF**
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

**REF**
- https://github.com/guerzon/vaultwarden/blob/main/charts/vaultwarden/README.md

```bash
# Installation
export RELEASE_NAME=vaultwarden
export NAMESPACE=catopia

helm install \
  $RELEASE_NAME vaultwarden/vaultwarden \
  -n $NAMESPACE \
  --set domain="https://vw.chenantunez.com/" \
  --set ingress.hostname="vw.chenantunez.com" \
  --set ingress.tlsSecret="chenantunez.com-tls" \
  # --set smtp.host="xxx.xxx.xxx" \
  # --set smtp.port=xxx \
  # --set smtp.from="xxx@xxx.xxx" \
  -f values.yaml

# Upgrade
# helm search repo vaultwarden --versions
helm upgrade -i \
  $RELEASE_NAME vaultwarden/vaultwarden \
  -n $NAMESPACE \
  --version 1.18.2 \
  --reset-then-reuse-values
```