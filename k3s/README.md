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
```

## Cert Manager

**REF**
- https://cert-manager.io/docs
- https://gist.github.com/davidcallen/86ea7b19ff74abb72b0d671d1885a889

1. [Install the cert manager using helm](https://cert-manager.io/docs/installation/helm/#installing-with-helm)
    ```bash
    helm repo add jetstack https://charts.jetstack.io --force-update
    
    helm install \
      cert-manager jetstack/cert-manager \
      --namespace cert-manager \
      --create-namespace \
      --version v1.17.2 \
      --set crds.enabled=true
    ```

2. Install the cluster issuer
    ```bash
    helm install 
    ```
    ```bash
    helm template . \
      --set cfToken=xxx \
      --set cfDnsZone=xxx \
      --set leEmail=xxx@xxx
    ```
