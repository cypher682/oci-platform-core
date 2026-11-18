output "lb_id" {
  value = oci_load_balancer_load_balancer.this.id
}

output "lb_public_ips" {
  description = "Public IP addresses of the load balancer"
  value       = [for detail in oci_load_balancer_load_balancer.this.ip_address_details : detail.ip_address]
}

output "backend_set_name" {
  value = oci_load_balancer_backend_set.app.name
}

output "http_endpoint" {
  description = "Ready-to-curl HTTP endpoint"
  value       = "http://${oci_load_balancer_load_balancer.this.ip_address_details[0].ip_address}/health"
}
