# ─────────────────────────────────────────────
# Object Storage — artifacts, logs and backup buckets
# ─────────────────────────────────────────────
locals {
  # Object Storage runs lifecycle rules as its own service principal, so it needs
  # explicit permission on the object family. Policies live in the root
  # compartment, which is the tenancy itself when no compartment is created.
  is_tenancy_root = startswith(var.compartment_id, "ocid1.tenancy.")
  policy_scope    = local.is_tenancy_root ? "in tenancy" : "in compartment id ${var.compartment_id}"
}

resource "oci_identity_policy" "lifecycle" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project}-${var.environment}-objectstorage-lifecycle"
  description    = "Allow the Object Storage service in ${var.region} to apply lifecycle rules"

  statements = [
    "Allow service objectstorage-${var.region} to manage object-family ${local.policy_scope}"
  ]

  freeform_tags = var.tags
}

resource "oci_objectstorage_bucket" "artifacts" {
  compartment_id = var.compartment_id
  namespace      = var.namespace
  name           = "${var.project}-${var.environment}-artifacts"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Enabled"
  kms_key_id     = var.kms_key_id

  freeform_tags = merge(var.tags, { Purpose = "artifacts" })
}

resource "oci_objectstorage_bucket" "logs" {
  compartment_id        = var.compartment_id
  namespace             = var.namespace
  name                  = "${var.project}-${var.environment}-logs"
  access_type           = "NoPublicAccess"
  storage_tier          = "Standard"
  versioning            = "Enabled"
  object_events_enabled = true
  kms_key_id            = var.kms_key_id

  freeform_tags = merge(var.tags, { Purpose = "logs" })
}

resource "oci_objectstorage_bucket" "backups" {
  compartment_id = var.compartment_id
  namespace      = var.namespace
  name           = "${var.project}-${var.environment}-backups"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Enabled"
  kms_key_id     = var.kms_key_id

  freeform_tags = merge(var.tags, { Purpose = "backups" })
}

resource "oci_objectstorage_object_lifecycle_policy" "logs" {
  namespace = var.namespace
  bucket    = oci_objectstorage_bucket.logs.name

  depends_on = [oci_identity_policy.lifecycle]

  rules {
    action      = "DELETE"
    name        = "expire-logs-after-30-days"
    time_amount = 30
    time_unit   = "DAYS"
    is_enabled  = true
    target      = "objects"
  }
}

resource "oci_objectstorage_object_lifecycle_policy" "backups" {
  namespace = var.namespace
  bucket    = oci_objectstorage_bucket.backups.name

  depends_on = [oci_identity_policy.lifecycle]

  rules {
    action      = "DELETE"
    name        = "expire-backups-after-14-days"
    time_amount = 14
    time_unit   = "DAYS"
    is_enabled  = true
    target      = "objects"
  }
}
