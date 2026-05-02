// Cloudflare DNS

variable "cloudflare_api_token_dns" {
  sensitive = true
  type = string
  description = "Cloudflare DNS API Token"
}

variable "domain" {
  type = string
  description = "Domain name"
}

variable "subdomains" {
  type = list(string)
  description = "List of subdomains to create A and AAAA records for"
}

variable "purelymail_ownership_proof" {
  type = string
  description = "Purely Mail ownership proof token"
}

// Hetzner Cloud

variable "hcloud_token" {
  sensitive = true
  type = string
  description = "Hetzner Cloud API Token"
}

variable "ssh_pubkey" {
  type = string
  description = "SSH Public Key"
}

variable "ssh_user" {
  type = string
  description = "SSH User"
}

variable "postgres_password" {
  sensitive = true
  type = string
  description = "PostgreSQL Password"
}

variable "cloud_init_fqdn" {
  type = string
  description = "Cloud-Init FQDN"
}

variable "cloud_init_hostname" {
  type = string
  description = "Cloud-Init Hostname"
}

variable "cloud_init_locale" {
  type = string
  default = "en_US.UTF-8"
  description = "Cloud-Init Locale"
}

variable "cloud_init_timezone" {
  type = string
  default = "Etc/UTC"
  description = "Cloud-Init Timezone"
}

variable "server_name" {
  type = string
  description = "Server Name"
}

variable "server_type" {
  # hcloud server-type list
  type = string
  default = "cx22"
  description = "Server Type, default to be cx22 shared intel 2vCPU 4GB RAM"
}

variable "image" {
  # https://docs.hetzner.cloud/#images
  # https://www.reddit.com/r/hetzner/comments/12jrh42/terraform_with_hetzner/
  # hcloud image list -t system -a x86
  type = string
  default = "debian-12"
  description = "Image"
}

variable "location_zone" {
  type = string
  default = "eu-central"
  description = "Location Zone"
}

variable "datacenter" {
  # hcloud datacenter list
  type = string
  default = "fsn1-dc14"
  description = "Datacenter"
}

variable "labels" {
  type = map(string)
  description = "Labels"
}

variable "firewall_name" {
  type = string
  description = "Firewall Name"
}

variable "network_name" {
  type = string
  description = "Network Name"
}
