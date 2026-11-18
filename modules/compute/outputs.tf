output "instance_ids" {
  value = oci_core_instance.this[*].id
}

output "display_names" {
  value = oci_core_instance.this[*].display_name
}

output "private_ips" {
  description = "Private IPs — used for the Terraform-managed load balancer backends"
  value       = oci_core_instance.this[*].private_ip
}

output "public_ips" {
  description = "Public IPs — only the ops runner has one"
  value       = oci_core_instance.this[*].public_ip
}

output "availability_domain" {
  value = var.availability_domain
}

output "ssh_command_ops" {
  description = "SSH command for the ops runner (replace key path if needed)"
  value       = var.assign_public_ip ? "ssh -i ~/.ssh/oci_platform deploy@${oci_core_instance.this[0].public_ip}" : "no public IP"
}
