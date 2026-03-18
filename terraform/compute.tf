# compute.tf — The ARM VM (the actual server)
#
# This creates an Always Free ARM Ampere A1 instance with:
# - 4 OCPUs (ARM cores)
# - 24 GB RAM
# - 200 GB boot volume
# - Ubuntu 22.04
# - K3s pre-installed via cloud-init
#
# IMPORTANT: ARM A1 instances are very popular on Always Free.
# You may get "Out of host capacity" errors. Solutions:
# 1. Retry "terraform apply" every few minutes
# 2. Try early morning IST (2-6 AM) when demand is lower
# 3. If Mumbai doesn't work, try Hyderabad region

# ------------------------------------------
# Data Sources — Look up existing information
# ------------------------------------------

# Find the list of Availability Domains (data centers) in Mumbai
# Mumbai has 1 AD. This query fetches it dynamically so we don't hardcode it.
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.oci_tenancy_ocid
}

# Find the latest Ubuntu 22.04 ARM image
# Instead of hardcoding an image ID (which changes over time),
# we query OCI for the latest Ubuntu 22.04 image that works with ARM.
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = var.vm_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# ------------------------------------------
# The VM Instance
# ------------------------------------------
resource "oci_core_instance" "k3s" {
  compartment_id      = var.compartment_ocid
  display_name        = "k3s-node"

  # Which data center to place the VM in
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name

  # VM shape — ARM Flex (you choose CPU + RAM)
  shape = var.vm_shape

  # How much CPU and RAM
  shape_config {
    ocpus         = var.vm_ocpus          # 4 ARM cores
    memory_in_gbs = var.vm_memory_gb      # 24 GB RAM
  }

  # What OS to install and how big the disk should be
  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb  # 200 GB
  }

  # Network configuration — put it in our subnet with a public IP
  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    # Public IP is needed temporarily for SSH setup.
    # After Cloudflare Tunnel is running, you could optionally remove it,
    # but keeping it doesn't hurt since the firewall blocks all inbound traffic.
  }

  # Metadata — SSH key and cloud-init script
  metadata = {
    # Your SSH public key — allows you to SSH into the VM
    ssh_authorized_keys = var.ssh_public_key

    # cloud-init script — runs automatically when the VM first boots
    # This installs K3s and fixes Oracle's iptables rules
    user_data = base64encode(file("${path.module}/../bootstrap/cloud-init.yaml"))
    # ${path.module} = the directory where this .tf file lives (terraform/)
    # ../ goes up one level to infra/
    # So it reads infra/bootstrap/cloud-init.yaml
  }
}
