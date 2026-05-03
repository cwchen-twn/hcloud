terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}

variable "hetzner_ipv4" {
  type = string
  description = "Hetzner IPv4"
}

variable "hetzner_ipv6" {
  type = string
  description = "Hetzner IPv6"
}

variable "subdomains" {
  description = "List of subdomains to create A and AAAA records for"
  type        = list(string)
}

variable "purelymail_ownership_proof" {
  type = string
  description = "Purely Mail ownership proof token"
}

variable "zone_id" {
  type = string
  description = "Cloudflare zone ID"
}

resource "cloudflare_dns_record" "a_record" {
  for_each = toset(var.subdomains)
  zone_id  = var.zone_id
  comment  = "Terraform created A record for ${each.key}"
  content  = var.hetzner_ipv4
  name     = each.key
  type     = "A"
  ttl      = 1
  proxied  = true
}

resource "cloudflare_dns_record" "aaaa_record" {
  for_each = toset(var.subdomains)
  zone_id  = var.zone_id
  comment  = "Terraform created AAAA record for ${each.key}"
  content  = var.hetzner_ipv6
  name     = each.key
  type     = "AAAA"
  ttl      = 1
  proxied  = true
}

// Purely Mail Configuration
// Purely Mail Configuration
// REF:
// - https://purelymail.com/docs/domainDocs
// - https://purelymail.com/manage/domain
resource "cloudflare_dns_record" "purelymail_ownership" {
  zone_id = var.zone_id
  comment = "Terraform created SPF record for Purely Mail"
  content = "\"purelymail_ownership_proof=${var.purelymail_ownership_proof}\""
  name = "@"
  type = "TXT"
  ttl = 1
}

resource "cloudflare_dns_record" "purelymail_mx" {
  zone_id = var.zone_id
  comment = "Terraform created MX record for Purely Mail"
  content = "mailserver.purelymail.com"
  name = "@"
  type = "MX"
  ttl = 1 // 1 hour
  priority = 50
}

resource "cloudflare_dns_record" "purelymail_spf" {
  zone_id = var.zone_id
  comment = "Terraform created SPF record for Purely Mail"
  content = "\"v=spf1 include:_spf.purelymail.com ~all\""
  name = "@"
  type = "TXT"
  ttl = 1
}

resource "cloudflare_dns_record" "purelymail_dkim_1" {
  zone_id = var.zone_id
  comment = "Terraform created DKIM record for Purely Mail 1"
  name = "purelymail1._domainkey"
  content = "key1.dkimroot.purelymail.com"
  type = "CNAME"
  ttl = 1
  proxied = false
}

resource "cloudflare_dns_record" "purelymail_dkim_2" {
  zone_id = var.zone_id
  comment = "Terraform created DKIM record for Purely Mail 2"
  name = "purelymail2._domainkey"
  content = "key2.dkimroot.purelymail.com"
  type = "CNAME"
  ttl = 1
  proxied = false
}

resource "cloudflare_dns_record" "purelymail_dkim_3" {
  zone_id = var.zone_id
  comment = "Terraform created DKIM record for Purely Mail 3"
  name = "purelymail3._domainkey"
  content = "key3.dkimroot.purelymail.com"
  type = "CNAME"
  ttl = 1
  proxied = false
}

resource "cloudflare_dns_record" "purelymail_dmark" {
  zone_id = var.zone_id
  comment = "Terraform created DMARC record for Purely Mail"
  name = "_dmarc"
  content = "dmarcroot.purelymail.com"
  type = "CNAME"
  ttl = 1
  proxied = false
}
