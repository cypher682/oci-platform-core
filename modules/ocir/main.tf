# ─────────────────────────────────────────────
# OCIR — private container repository
# ─────────────────────────────────────────────
resource "oci_artifacts_container_repository" "this" {
  compartment_id = var.compartment_id
  display_name   = var.repository_name
  is_immutable   = var.is_immutable
  is_public      = false

  freeform_tags = var.tags
}
