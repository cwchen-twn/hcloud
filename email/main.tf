terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }

  backend "s3" {
    bucket = "tf-state"
    key = "cloudflare-email.tfstate"
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

variable "cloudflare_api_token_dns" {
  type = string
  description = "Cloudflare API token"
}

variable "domain" {
  type = string
  description = "Domain name"
}

# variable "dkim_selector" {
#   type = string
#   description = "DKIM selector"
# }

# variable "dkim_pubkey" {
#   type = string
#   description = "DKIM public key"
# }

variable "purelymail_ownership_proof" {
  type = string
  description = "Purely Mail ownership proof token"
}

data "cloudflare_zone" "domain" {
  filter = {
    name = var.domain
  }
}

// Purely Mail Configuration
// REF:
// - https://purelymail.com/docs/domainDocs
// - https://purelymail.com/manage/domain
resource "cloudflare_dns_record" "purelymail_ownership" {
  zone_id = data.cloudflare_zone.domain.zone_id
  comment = "Terraform created SPF record for Purely Mail"
  content = "\"purelymail_ownership_proof=${var.purelymail_ownership_proof}\""
  name = "@"
  type = "TXT"
  ttl = 1
}

resource "cloudflare_dns_record" "purelymail_mx" {
  zone_id = data.cloudflare_zone.domain.zone_id
  comment = "Terraform created MX record for Purely Mail"
  content = "mailserver.purelymail.com"
  name = "@"
  type = "MX"
  ttl = 1 // 1 hour
  priority = 50
}

resource "cloudflare_dns_record" "purelymail_spf" {
  zone_id = data.cloudflare_zone.domain.zone_id
  comment = "Terraform created SPF record for Purely Mail"
  content = "\"v=spf1 include:_spf.purelymail.com ~all\""
  name = "@"
  type = "TXT"
  ttl = 1
}

resource "cloudflare_dns_record" "purelymail_dkim_1" {
  zone_id = data.cloudflare_zone.domain.zone_id
  comment = "Terraform created DKIM record for Purely Mail 1"
  name = "purelymail1._domainkey"
  content = "key1.dkimroot.purelymail.com"
  type = "CNAME"
  ttl = 1
  proxied = false
}

resource "cloudflare_dns_record" "purelymail_dkim_2" {
  zone_id = data.cloudflare_zone.domain.zone_id
  comment = "Terraform created DKIM record for Purely Mail 2"
  name = "purelymail2._domainkey"
  content = "key2.dkimroot.purelymail.com"
  type = "CNAME"
  ttl = 1
  proxied = false
}

resource "cloudflare_dns_record" "purelymail_dkim_3" {
  zone_id = data.cloudflare_zone.domain.zone_id
  comment = "Terraform created DKIM record for Purely Mail 3"
  name = "purelymail3._domainkey"
  content = "key3.dkimroot.purelymail.com"
  type = "CNAME"
  ttl = 1
  proxied = false
}

resource "cloudflare_dns_record" "purelymail_dmark" {
  zone_id = data.cloudflare_zone.domain.zone_id
  comment = "Terraform created DMARC record for Purely Mail"
  name = "_dmarc"
  content = "dmarcroot.purelymail.com"
  type = "CNAME"
  ttl = 1
  proxied = false
}


// Polaris Mail Server Configuration
// REF: https://wiki.polarismail.com/display/Support/Autodiscover
# resource "cloudflare_dns_record" "polarismail_autodiscover" {
#   zone_id = data.cloudflare_zone.domain.zone_id
#   comment = "Terraform created A record for Polaris Mail Autodiscover"
#   content = "69.28.212.195"
#   name = "autodiscover"
#   type = "A"
#   ttl = 1
#   proxied = false
# }

// REF: https://wiki.polarismail.com/display/Support/DNS+Configuration
# resource "cloudflare_dns_record" "polarismail_webmail" {
#   zone_id = data.cloudflare_zone.domain.zone_id
#   comment = "Terraform created CNAME record for Polaris Mail Webmail"
#   content = "webredirect.emailarray.com"
#   name = "webmail"
#   type = "CNAME"
#   ttl = 1
#   proxied = true
# }

# resource "cloudflare_dns_record" "polarismail_mx1" {
#   zone_id = data.cloudflare_zone.domain.zone_id
#   comment = "Terraform created MX record for Polaris Mail"
#   content = "mx.emailarray.com"
#   name = "@"
#   type = "MX"
#   ttl = 3600 // 1 hour
#   priority = 5
# }
# 
# resource "cloudflare_dns_record" "polarismail_mx2" {
#   zone_id = data.cloudflare_zone.domain.zone_id
#   comment = "Terraform created MX record for Polaris Mail"
#   content = "mx2.emailarray.com"
#   name = "@"
#   type = "MX"
#   ttl = 3600 // 1 hour
#   priority = 10
# }

# resource "cloudflare_dns_record" "polarismail_spf" {
#   zone_id = data.cloudflare_zone.domain.zone_id
#   comment = "Terraform created SPF record for Polaris Mail"
#   content = "\"v=spf1 include:emailarray.com -all\""
#   name = "@"
#   type = "TXT"
#   ttl = 1800 // 30 minutes
# }

# resource "cloudflare_dns_record" "polarismail_dkim" {
#   zone_id = data.cloudflare_zone.domain.zone_id
#   comment = "Terraform created DKIM record for Polaris Mail"
#   content = "\"${var.dkim_pubkey}\""
#   name = var.dkim_selector
#   type = "TXT"
#   ttl = 1 // automatic
# }
