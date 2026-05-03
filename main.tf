terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "~> 1.50"
    }

    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }

  backend "s3" {
    bucket = "tf-state"
    key = "hcloud.tfstate"
    region = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token_dns
}

provider "hcloud" {
  token = var.hcloud_token
}

module "hetzner" {
  source = "./modules/hetzner"

  ssh_pubkey = var.ssh_pubkey
  ssh_user = var.ssh_user
  postgres_password = var.postgres_password
  cloud_init_fqdn = var.cloud_init_fqdn
  cloud_init_hostname = var.cloud_init_hostname
  cloud_init_locale = var.cloud_init_locale
  cloud_init_timezone = var.cloud_init_timezone
  server_name = var.server_name
  server_type = var.server_type
  image = var.image
  location_zone = var.location_zone
  datacenter = var.datacenter
  labels = var.labels
  firewall_name = var.firewall_name
  network_name = var.network_name
}

data "hcloud_primary_ip" "primary_ip_ipv4" {
  name = "${var.domain}.ipv4"
  depends_on = [ module.hetzner ]
}

data "hcloud_primary_ip" "primary_ip_ipv6" {
  name = "${var.domain}.ipv6"
  depends_on = [ module.hetzner ]
}

data "cloudflare_zone" "domain" {
  filter = {
    name = var.domain
  }
}

module "cloudflare" {
  source = "./modules/cloudflare"

  hetzner_ipv4 = data.hcloud_primary_ip.primary_ip_ipv4.ip_address
  hetzner_ipv6 = data.hcloud_primary_ip.primary_ip_ipv6.ip_address
  zone_id = data.cloudflare_zone.domain.zone_id
  subdomains = var.subdomains
  purelymail_ownership_proof = var.purelymail_ownership_proof
  depends_on = [ module.hetzner ]
}
