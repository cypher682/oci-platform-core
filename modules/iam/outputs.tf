output "compartment_id" {
  description = "Compartment that holds all platform resources"
  value       = local.platform_compartment_id
}

output "compartment_name" {
  description = "Display name of the platform compartment"
  value       = local.compartment_name
}

output "admins_group_name" {
  description = "IAM group with full platform control"
  value       = oci_identity_group.admins.name
}

output "readers_group_name" {
  description = "IAM group with inspect-only access"
  value       = oci_identity_group.readers.name
}

output "instance_dynamic_group_name" {
  description = "Dynamic group used by instance principals"
  value       = oci_identity_dynamic_group.instances.name
}
