# outputs.tf — Values printed after "terraform apply" succeeds
#
# After Terraform creates all the resources, these outputs show you
# the important information you need (like the VM's IP address).

output "vm_public_ip" {
  description = "Public IP of the K3s VM — use this to SSH in"
  value       = oci_core_instance.k3s.public_ip
}

output "vm_private_ip" {
  description = "Private IP of the VM within the VCN"
  value       = oci_core_instance.k3s.private_ip
}

output "ssh_command" {
  description = "Copy-paste this to SSH into the VM"
  value       = "ssh ubuntu@${oci_core_instance.k3s.public_ip}"
}

output "vm_state" {
  description = "Current state of the VM (RUNNING, STOPPED, etc.)"
  value       = oci_core_instance.k3s.state
}
