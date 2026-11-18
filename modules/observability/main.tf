# ─────────────────────────────────────────────
# Observability — ONS topic, email subscription, Monitoring alarms, app logs
# ─────────────────────────────────────────────
resource "oci_ons_notification_topic" "alerts" {
  compartment_id = var.compartment_id
  name           = "${var.project}-${var.environment}-alerts"
  description    = "Platform alert topic"

  freeform_tags = var.tags
}

resource "oci_ons_subscription" "email" {
  compartment_id = var.compartment_id
  endpoint       = var.alert_email
  protocol       = "EMAIL"
  topic_id       = oci_ons_notification_topic.alerts.id

  freeform_tags = var.tags
}

resource "oci_monitoring_alarm" "compute_cpu" {
  compartment_id = var.compartment_id
  display_name   = "${var.project}-${var.environment}-compute-cpu-high"
  is_enabled     = true
  namespace      = "oci_computeagent"
  severity       = "WARNING"

  destinations          = [oci_ons_notification_topic.alerts.id]
  metric_compartment_id = var.compartment_id

  query = "CpuUtilization[5m].mean() > ${var.cpu_threshold_percent}"

  body = "CPU utilisation above ${var.cpu_threshold_percent}% on a platform compute instance."

  freeform_tags = var.tags
}

resource "oci_monitoring_alarm" "lb_unhealthy_backend" {
  compartment_id = var.compartment_id
  display_name   = "${var.project}-${var.environment}-lb-unhealthy-backend"
  is_enabled     = true
  namespace      = "oci_lbaas"
  severity       = "CRITICAL"

  destinations          = [oci_ons_notification_topic.alerts.id]
  metric_compartment_id = var.compartment_id

  query = "UnHealthyBackendCount[1m].sum() > 0"

  body = "At least one load balancer backend is unhealthy. Check the health endpoint and application logs."

  freeform_tags = var.tags
}

resource "oci_monitoring_alarm" "adb_storage" {
  count = var.enable_adb_alarm ? 1 : 0

  compartment_id = var.compartment_id
  display_name   = "${var.project}-${var.environment}-adb-storage-high"
  is_enabled     = true
  namespace      = "oci_autonomous_database"
  severity       = "WARNING"

  destinations          = [oci_ons_notification_topic.alerts.id]
  metric_compartment_id = var.compartment_id

  query = "StorageUtilization[5m].mean() > ${var.adb_storage_threshold_percent}"

  body = "Autonomous Database storage utilisation above ${var.adb_storage_threshold_percent}%."

  freeform_tags = var.tags
}

resource "oci_logging_log_group" "platform" {
  compartment_id = var.compartment_id
  display_name   = "${var.project}-${var.environment}-platform-logs"
  freeform_tags  = var.tags
}
