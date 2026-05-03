# hcloud
VPS management on Hetzner Cloud

## Quick Start

```bash
# Install wrangler to interact with cloudflare
bun install
# Create the R2 bucket to store the terraform state
bun run create

# Copy and fill in the R2 backend credentials
cp backend.hcl.example backend.hcl

# Copy and fill in terraform variables (hcloud token, cloudflare token, subdomains, purelymail_ownership_proof, etc.)
cp terraform.tfvars.example terraform.tfvars

terraform init -backend-config=backend.hcl
terraform plan
terraform apply
terraform destroy
```

Hetzner server DNS A/AAAA records, and PurelyMail email DNS records (MX, SPF, DKIM, DMARC) are all managed in the same Terraform root via `modules/cloudflare`.

## How to find available images

1. Use curl

```bash
curl \
	-H "Authorization: Bearer $H_API_TOKEN" \
	"https://api.hetzner.cloud/v1/images"

curl \
	-H "Authorization: Bearer $H_API_TOKEN" \
	"https://api.hetzner.cloud/v1/images/$ID"
```

2. Use [hcloud cli](https://github.com/hetznercloud/cli)

```bash
hcloud context create <ur-project-name>
hcloud image list -t system -a x86
```

## SSH Tunnels

To access the remote Postgres and K3S cluster without modifying the firewall rules,
which only open 80, 443, and ssh for security concerns, we can use the ssh tunnel
enabling the connection from the local machine to the remote services.

The *sshtunnels* folder has the systemd configurations and installation bash, following
the commands will install the systemd services.

```bash
cd sshtunnels/
# Ensure the SSH_USER and REMOTE_HOST are configured in tne env
# e.g., 
# - export SSH_USER=xxx
# - export REMOTE_HOST=xxx
bash install_tunnel.sh

# Check the install services
systemctl status --user postgres-tunnel.service
systemctl status --user k3s-ssh-tunnel.service
# To see the logs
journalctl --user --unit=postgres-tunnel.service --no-pager
journalctl --user --unit=k3s-ssh-tunnel.service --no-pager
```

## Reference

- [developer.hashicorp.com/terraform/intro](https://developer.hashicorp.com/terraform/intro)
- [docs.hetzner.com/cloud](https://docs.hetzner.com/cloud)
- [registry.terraform.io/providers/hetznercloud/hcloud/latest/docs](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs)
- [developer.hashicorp.com/terraform/tutorials/provision/cloud-init](https://developer.hashicorp.com/terraform/tutorials/provision/cloud-init)
- [dennmart.com/articles/get-started-with-hetzner-cloud-and-terraform-for-easy-deployments/](https://dennmart.com/articles/get-started-with-hetzner-cloud-and-terraform-for-easy-deployments/)
- [medium.com/@orestovyevhen/set-up-infrastructure-in-hetzner-cloud-using-terraform-ce85491e92d](https://medium.com/@orestovyevhen/set-up-infrastructure-in-hetzner-cloud-using-terraform-ce85491e92d)
- [community.hetzner.com/tutorials/setup-your-own-scalable-kubernetes-cluster](https://community.hetzner.com/tutorials/setup-your-own-scalable-kubernetes-cluster)
- [scottspence.com/posts/setting-up-my-vps-on-hetzner](https://scottspence.com/posts/setting-up-my-vps-on-hetzner)
- [github.com/hetznercloud/cli](https://github.com/hetznercloud/cli)
- [registry.terraform.io/providers/cloudflare/cloudflare/latest/docs](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [developers.cloudflare.com/workers/wrangler/install-and-update](https://developers.cloudflare.com/workers/wrangler/install-and-update/)
- [developers.cloudflare.com/terraform/advanced-topics/remote-backend](https://developers.cloudflare.com/terraform/advanced-topics/remote-backend/)
- [medium.com/@GarisSpace/terraform-state-management-integrating-cloudflare-r2](https://medium.com/@GarisSpace/terraform-state-management-integrating-cloudflare-r2-b2e82798896d)
