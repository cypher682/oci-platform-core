output "vcn_id" {
  value = oci_core_vcn.this.id
}

output "public_subnet_id" {
  value = oci_core_subnet.public.id
}

output "app_subnet_id" {
  value = oci_core_subnet.app.id
}

output "db_subnet_id" {
  value = oci_core_subnet.db.id
}

output "oke_node_subnet_id" {
  value = oci_core_subnet.oke_nodes.id
}

output "nsg_lb_id" {
  value = oci_core_network_security_group.lb.id
}

output "nsg_app_id" {
  value = oci_core_network_security_group.app.id
}

output "nsg_ops_id" {
  value = oci_core_network_security_group.ops.id
}

output "nsg_db_id" {
  value = oci_core_network_security_group.db.id
}

output "nsg_oke_api_id" {
  value = oci_core_network_security_group.oke_api.id
}

output "nsg_oke_nodes_id" {
  value = oci_core_network_security_group.oke_nodes.id
}

output "vcn_cidr" {
  value = var.vcn_cidr
}

output "flow_log_group_id" {
  value = oci_logging_log_group.network.id
}
