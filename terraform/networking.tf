# networking.tf — Virtual network, subnet, and firewall rules
#
# Before you can create a VM, you need a network for it to live in.
# Think of it like setting up the building (network) before moving
# in the furniture (VM).
#
# OCI networking hierarchy:
#   VCN (Virtual Cloud Network) → like your own private data center network
#     └── Subnet → a range of IP addresses within the VCN
#           └── Security List → firewall rules (what traffic is allowed)
#     └── Internet Gateway → the door to the public internet
#     └── Route Table → traffic directions (like a GPS for network packets)

# ------------------------------------------
# VCN — Your private virtual network
# ------------------------------------------
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "infra-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  # 10.0.0.0/16 gives you 65,536 private IP addresses
  # This is the standard range for private networks
  dns_label = "infra"
}

# ------------------------------------------
# Internet Gateway — Allows outbound internet access
# ------------------------------------------
# Without this, the VM can't reach the internet at all.
# Cloudflare Tunnel needs outbound access to work.
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "infra-igw"
  enabled        = true
}

# ------------------------------------------
# Route Table — Tells network traffic where to go
# ------------------------------------------
# This rule says: "Any traffic going to the internet (0.0.0.0/0)
# should go through the Internet Gateway"
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# ------------------------------------------
# Security List — Firewall rules
# ------------------------------------------
# This is the most important security piece.
# We allow:
#   - ALL outbound traffic (needed for Cloudflare Tunnel, package updates, etc.)
#   - SSH inbound ONLY from your IP (temporary — removed after tunnel is set up)
#   - ICMP (ping) for debugging
#
# After Cloudflare Tunnel is working, we remove the SSH rule
# so the VM has ZERO open inbound ports.
resource "oci_core_security_list" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "infra-security-list"

  # EGRESS (outbound) — Allow everything
  # The VM needs to reach the internet for:
  # - Cloudflare Tunnel (outbound connection to Cloudflare's edge)
  # - apt-get updates
  # - Docker image pulls
  # - K3s communication
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  # INGRESS (inbound) — SSH from your IP only
  # protocol "6" = TCP
  # This is temporary for initial setup. We'll remove it later.
  ingress_security_rules {
    protocol = "6"
    source   = var.ssh_allowed_ip

    tcp_options {
      min = 22
      max = 22
    }
  }

  # INGRESS — ICMP (ping) for debugging
  # protocol "1" = ICMP
  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
  }
}

# ------------------------------------------
# Subnet — A slice of the VCN for our VM
# ------------------------------------------
# The VM will get an IP address from this subnet (10.0.1.x)
resource "oci_core_subnet" "public" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = "10.0.1.0/24"
  # /24 = 256 IP addresses (10.0.1.0 to 10.0.1.255)
  display_name      = "public-subnet"
  dns_label         = "pub"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.main.id]
}
