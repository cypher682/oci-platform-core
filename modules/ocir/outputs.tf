output "repository_id" {
  value = oci_artifacts_container_repository.this.id
}

output "repository_name" {
  value = oci_artifacts_container_repository.this.display_name
}

output "registry" {
  value = "${var.region_key}.ocir.io"
}

output "image_path" {
  description = "Repository path without tag — append :<tag>"
  value       = "${var.region_key}.ocir.io/${var.namespace}/${var.repository_name}"
}
