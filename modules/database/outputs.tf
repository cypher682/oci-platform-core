output "adb_id" {
  value = oci_database_autonomous_database.this.id
}

output "adb_state" {
  value = oci_database_autonomous_database.this.state
}

output "private_endpoint" {
  value = oci_database_autonomous_database.this.private_endpoint
}

output "connection_strings" {
  description = "All connection strings exposed by the ADB"
  value       = try(oci_database_autonomous_database.this.connection_strings[0].all_connection_strings, {})
  sensitive   = true
}
