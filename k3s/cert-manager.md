# How to setup the cert manager

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
```

```bash
# https://cert-manager.io/docs/installation/helm/

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.17.2 \
  --set crds.enabled=true
```

```bash
# https://cert-manager.io/docs/installation/upgrade/
helm upgrade --reset-then-reuse-values --version <version> <release_name> jetstack/cert-manager
```

```bash
# https://cert-manager.io/docs/installation/kubectl/#verify
helm ls --all-namespaces
kubectl get pods -n cert-manager
```
