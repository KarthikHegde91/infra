# versions.tf — Tell Terraform which plugins (providers) we need
#
# Think of this like package.json or requirements.txt:
# "I need the Oracle Cloud plugin v5.x and Cloudflare plugin v4.x"

terraform {
  # Minimum Terraform version required
  required_version = ">= 1.5.0"

  required_providers {
    # Oracle Cloud Infrastructure provider
    # This plugin knows how to create VMs, networks, etc. on Oracle Cloud
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }

    # Cloudflare provider
    # This plugin knows how to create DNS records on Cloudflare
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}
