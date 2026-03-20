# main.tf — Provider configuration
#
# This file tells Terraform HOW to authenticate with Oracle Cloud and Cloudflare.
# Think of it like logging into the cloud console, but via code.

# Connect to Oracle Cloud using your API key credentials
provider "oci" {
  tenancy_ocid     = var.oci_tenancy_ocid
  user_ocid        = var.oci_user_ocid
  fingerprint      = var.oci_fingerprint
  private_key_path = var.oci_private_key_path
  region           = var.oci_region
}

# Connect to Cloudflare using your API token
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
