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

variable "vm_ocpus" {
  description = "Number of OCPUs (ARM cores) — Always Free allows up to 4"
  type        = number
  default     = 4
}

variable "vm_memory_gb" {
  description = "RAM in GB — Always Free allows up to 24GB"
  type        = number
  default     = 24
}

variable "boot_volume_gb" {
  description = "Boot disk size in GB — Always Free allows up to 200GB total"
  type        = number
  default     = 200
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
