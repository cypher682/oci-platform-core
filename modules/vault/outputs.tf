output "vault_id" {
  value = oci_kms_vault.this.id
}

output "key_id" {
  value = oci_kms_key.this.id
}

output "management_endpoint" {
  value = oci_kms_vault.this.management_endpoint
}

output "db_secret_id" {
  value = oci_vault_secret.db_admin.id
}

output "db_secret_name" {
  value = oci_vault_secret.db_admin.secret_name
}
