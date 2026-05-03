terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "~> 1.50"
    }
  }
}

resource "hcloud_firewall" "firewall" {
  name = var.firewall_name

  rule {
    description = "Allow SSH traffic"
    direction = "in"
    protocol = "tcp"
    port = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Allow HTTP traffic"
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    description = "Allow HTTPS traffic"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    description = "Allow Gitea SSH traffic"
    direction   = "in"
    protocol    = "tcp"
    port        = "2222"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_network" "network" {
  name = var.network_name
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "subnet" {
  network_id = hcloud_network.network.id
  type = "cloud"
  network_zone = var.location_zone
  ip_range = "10.0.1.0/24"
}

resource "hcloud_primary_ip" "primary_ip_ipv4" {
  name = "chenantunez.com.ipv4"
  datacenter = var.datacenter
  type = "ipv4"
  assignee_type = "server"
  auto_delete = true
}

resource "hcloud_primary_ip" "primary_ip_ipv6" {
  name = "chenantunez.com.ipv6"
  datacenter = var.datacenter
  type = "ipv6"
  assignee_type = "server"
  auto_delete = true
}

resource "hcloud_server" "server" {
  name = var.server_name
  image = var.image
  server_type = var.server_type
  datacenter = var.datacenter
  firewall_ids = [hcloud_firewall.firewall.id]
  user_data = templatefile("${path.module}/cloud-init.yaml", {
    ssh_pubkey = var.ssh_pubkey
    ssh_user = var.ssh_user
    postgres_password = var.postgres_password
    fqdn = var.cloud_init_fqdn
    hostname = var.cloud_init_hostname
    locale = var.cloud_init_locale
    timezone = var.cloud_init_timezone
  })
  lifecycle {
    ignore_changes = [
      user_data
    ]
  }

  labels = var.labels

  public_net {
    ipv4_enabled = true
    ipv4 = hcloud_primary_ip.primary_ip_ipv4.id
    ipv6_enabled = true
    ipv6 = hcloud_primary_ip.primary_ip_ipv6.id
  }

  network {
    network_id = hcloud_network.network.id
    ip = "10.0.1.1"
  }

  depends_on = [ hcloud_network_subnet.subnet ]
}

output "server_location" {
  description = "Server Location and Zone"
  value = "zone: ${var.location_zone}, datacenter: ${var.datacenter}"
}

output "server_ipv4" {
  description = "Server IPv4"
  value = hcloud_primary_ip.primary_ip_ipv4.ip_address
}

output "server_ipv6" {
  description = "Server IPv6"
  value = hcloud_primary_ip.primary_ip_ipv6.ip_address
}

output "server_ssh_user" {
  description = "Server SSH User"
  value = var.ssh_user
}
