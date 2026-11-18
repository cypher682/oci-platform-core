output "bastion_id" {
  value = oci_bastion_bastion.this.id
}

output "bastion_name" {
  value = oci_bastion_bastion.this.name
}

output "managed_ssh_example" {
  description = "Example managed-SSH session command; fill in the target instance and key"
  value       = "oci bastion session create-managed-ssh --bastion-id ${oci_bastion_bastion.this.id} --target-resource-id <instance-ocid> --target-os-username deploy --ssh-public-key-file ~/.ssh/id_ed25519.pub --wait-for-state SUCCEEDED"
}
