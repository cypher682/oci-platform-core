output "topic_id" {
  value = oci_ons_notification_topic.alerts.id
}

output "topic_name" {
  value = oci_ons_notification_topic.alerts.name
}

output "cpu_alarm_id" {
  value = oci_monitoring_alarm.compute_cpu.id
}

output "lb_alarm_id" {
  value = oci_monitoring_alarm.lb_unhealthy_backend.id
}

output "log_group_id" {
  value = oci_logging_log_group.platform.id
}
