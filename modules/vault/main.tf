# ─────────────────────────────────────────────
# Vault — software-protected master key + secret storage
# ─────────────────────────────────────────────
resource "oci_kms_vault" "this" {
  compartment_id = var.compartment_id
  display_name   = "${var.project}-${var.environment}-vault"
  vault_type     = "DEFAULT"

  freeform_tags = var.tags
}

resource "oci_kms_key" "this" {
  compartment_id      = var.compartment_id
  display_name        = "${var.project}-${var.environment}-master-key"
  management_endpoint = oci_kms_vault.this.management_endpoint
  protection_mode     = "SOFTWARE"

  key_shape {
    algorithm = "AES"
    length    = 32
  }

  freeform_tags = var.tags
}

resource "oci_vault_secret" "db_admin" {
  compartment_id = var.compartment_id
  vault_id       = oci_kms_vault.this.id
  key_id         = oci_kms_key.this.id
  secret_name    = "${var.project}-${var.environment}-db-admin-password"
  description    = "ADMIN password for the platform Autonomous Database"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.db_admin_password)
  }

  freeform_tags = var.tags
}

locals {
  key_scope = startswith(var.compartment_id, "ocid1.tenancy.") ? "in tenancy" : "in compartment id ${var.compartment_id}"
}

resource "oci_identity_policy" "objectstorage_kms" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project}-${var.environment}-objectstorage-kms"
  description    = "Allow Object Storage in ${var.region} to use the platform master key"

  statements = [
    "Allow service objectstorage-${var.region} to use keys ${local.key_scope} where target.key.id = '${oci_kms_key.this.id}'"
  ]

  freeform_tags = var.tags
}
