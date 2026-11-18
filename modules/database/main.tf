# ─────────────────────────────────────────────
# Autonomous Database — OLTP instance on a private endpoint
# ─────────────────────────────────────────────
resource "oci_database_autonomous_database" "this" {
  compartment_id = var.compartment_id
  db_name        = var.db_name
  display_name   = "${var.project}-${var.environment}-adb"

  db_workload    = "OLTP"
  admin_password = var.admin_password
  is_free_tier   = false

  # New Autonomous Databases must use the ECPU compute model; OCPU is rejected.
  compute_model           = "ECPU"
  compute_count           = var.compute_count
  data_storage_size_in_gb = var.data_storage_size_in_gb

  license_model  = "LICENSE_INCLUDED"
  character_set  = "AL32UTF8"
  ncharacter_set = "AL16UTF16"

  subnet_id              = var.subnet_id
  nsg_ids                = [var.nsg_id]
  private_endpoint_label = var.private_endpoint_label

  freeform_tags = var.tags
}
