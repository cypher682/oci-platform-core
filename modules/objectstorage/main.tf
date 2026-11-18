# ─────────────────────────────────────────────
# Object Storage — artifacts, logs and backup buckets
# ─────────────────────────────────────────────
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

  rules {
    action      = "DELETE"
    name        = "expire-backups-after-14-days"
    time_amount = 14
    time_unit   = "DAYS"
    is_enabled  = true
    target      = "objects"
  }
}
