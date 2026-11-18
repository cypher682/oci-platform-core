output "artifacts_bucket_name" {
  value = oci_objectstorage_bucket.artifacts.name
}

output "logs_bucket_name" {
  value = oci_objectstorage_bucket.logs.name
}

output "backups_bucket_name" {
  value = oci_objectstorage_bucket.backups.name
}

output "namespace" {
  value = var.namespace
}
