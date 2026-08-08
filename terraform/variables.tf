# variables.tf — All inputs that Terraform needs from you
#
# Variables are like function parameters. The actual values go in
# terraform.tfvars (which is gitignored — never commit secrets).
#
# When you run "terraform apply", Terraform reads these variable
# definitions and looks for their values in terraform.tfvars.

# ===========================================
# OCI Authentication
# These 4 values tell Terraform HOW to connect to your Oracle Cloud account
# ===========================================

variable "oci_tenancy_ocid" {
  description = "Your Oracle Cloud Tenancy OCID (found in Settings > Tenancy Information)"
  type        = string
}

variable "oci_user_ocid" {
  description = "Your Oracle Cloud User OCID (found in Profile > User Settings)"
  type        = string
}

variable "oci_fingerprint" {
  description = "Fingerprint of the API key you uploaded to OCI (shown after upload)"
  type        = string
}

variable "oci_private_key_path" {
  description = "Path to the private key file on your machine"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "oci_region" {
  description = "OCI region — Mumbai is closest to Bengaluru"
  type        = string
  default     = "ap-mumbai-1"
}

# ===========================================
# OCI Compute — VM specifications
# These define WHAT to create on Oracle Cloud
# ===========================================

variable "compartment_ocid" {
  description = "Compartment OCID — use root compartment (same as tenancy OCID)"
  type        = string
}

variable "vm_shape" {
  description = "VM shape — ARM Always Free tier shape"
  type        = string
  default     = "VM.Standard.A1.Flex"
  # VM.Standard.A1.Flex = ARM-based Ampere processor
  # "Flex" means you can choose how many CPUs and how much RAM
}

# ----------------------------------------------------------------------
# $0 GUARDRAILS — read before changing anything below.
#
# This tenancy is Pay As You Go, not Always Free. The Always Free
# ALLOWANCES still apply and still cost nothing — but the safety net is
# gone. On Always Free, asking for more than the allowance simply FAILS.
# On PAYG the identical request SUCCEEDS and starts billing, silently.
#
# Free allowances are TENANCY-WIDE totals, not per-instance:
#   Ampere A1 compute   4 OCPU + 24 GB RAM   across ALL A1 instances
#   Block storage       200 GB               across ALL volumes,
#                                            boot volumes included
#   Outbound transfer   10 TB / month
#
# What that means for this stack:
#   - The defaults below are 3 OCPU / 18 GB — deliberately UNDER the 4/24
#     ceiling. Still $0, still triple the CPU the Jul 2026 recovery left
#     this node at, and it holds 1 OCPU / 6 GB of allowance in reserve.
#     That reserve is the point: a future recovery can stand a replacement
#     instance up ALONGSIDE this one without crossing into billing.
#   - Taking the full 4 OCPU / 24 GB is also $0, but it consumes the entire
#     tenancy allowance, so any second A1 instance bills from hour one.
#     The spare OCPU is cheap insurance against the exact failure mode that
#     caused five days of downtime in Jul 2026.
#   - boot_volume_gb = 200 sits exactly ON the storage cap, leaving no room
#     for a second volume. Preserving this boot volume and launching a
#     replacement — the Jul 2026 recovery pattern, which
#     preserve_boot_volume = true in compute.tf now makes more likely —
#     puts ~200 GB over the cap and bills until the orphan is deleted.
#     Delete the old volume promptly, or drop this to 100 GB on the next
#     rebuild so preserved + replacement both fit inside the cap.
#   - A second A1 instance is free only while the TOTAL stays within 4/24.
#
# Set an OCI Budget alert at $1. It is free to configure and it is the only
# thing that will actually tell you when one of the above stops holding.
# ----------------------------------------------------------------------

variable "vm_ocpus" {
  description = "Number of OCPUs (ARM cores) — free up to 4 tenancy-wide; 3 leaves one spare for a recovery instance"
  type        = number
  default     = 3
}

variable "vm_memory_gb" {
  description = "RAM in GB — free up to 24 tenancy-wide; 18 leaves 6 spare for a recovery instance"
  type        = number
  default     = 18
}

variable "boot_volume_gb" {
  description = "Boot disk size in GB — Always Free allows up to 200GB total"
  type        = number
  default     = 200
}

variable "ad_index" {
  description = "Index of the Availability Domain to use (0, 1, or 2). Change if one AD is out of capacity"
  type        = number
  default     = 0
}

variable "ssh_public_key" {
  description = "Your SSH public key (contents of ~/.ssh/id_rsa.pub) for VM access"
  type        = string
}

variable "ssh_allowed_ip" {
  description = "Your current public IP for temporary SSH access (format: 1.2.3.4/32). Find it at whatismyip.com"
  type        = string
}

# ===========================================
# Cloudflare — DNS management
# ===========================================

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:DNS:Edit permission"
  type        = string
  sensitive   = true
  # "sensitive = true" means Terraform will hide this value in logs
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for karthikhegde.in (found in domain Overview page, right sidebar)"
  type        = string
}

variable "tunnel_id" {
  description = "Cloudflare Tunnel ID — leave empty initially, fill in after creating the tunnel in Step 7"
  type        = string
  default     = ""
}
