output "compartment_id" {
  description = "Compartment that owns the platform"
  value       = module.iam.compartment_id
}

output "vcn_id" {
  value = module.network.vcn_id
}

output "lb_public_ip" {
  description = "Public IP of the Terraform-managed load balancer"
  value       = module.loadbalancer.lb_public_ips[0]
}

output "health_url" {
  description = "Live health endpoint — capture this as evidence"
  value       = module.loadbalancer.http_endpoint
}

output "ocir_image" {
  description = "Push target for the sample application"
  value       = "${module.ocir.image_path}:latest"
}

output "ocir_registry" {
  value = module.ocir.registry
}

output "oke_cluster_id" {
  value = try(module.oke[0].cluster_id, null)
}

output "oke_endpoint" {
  value = try(module.oke[0].cluster_endpoint, null)
}

output "oke_kubeconfig_command" {
  value = try(module.oke[0].kubeconfig_command, null)
}

output "adb_id" {
  value = try(module.database[0].adb_id, null)
}

output "adb_private_endpoint" {
  value = try(module.database[0].private_endpoint, null)
}

output "vault_secret_id" {
  value = module.vault.db_secret_id
}

output "ops_runner_public_ip" {
  value = try(module.compute_ops[0].public_ips[0], null)
}

output "ops_runner_ssh" {
  value = try(module.compute_ops[0].ssh_command_ops, null)
}

output "app_private_ips" {
  value = module.compute_app.private_ips
}

output "alert_topic" {
  value = module.observability.topic_name
}

output "ansible_inventory" {
  description = "Write this to ansible/inventory/hosts.ini and run Ansible ON the ops runner"
  value       = <<-EOT
    [app]
    %{for ip in module.compute_app.private_ips~}
    ${ip} ansible_user=deploy
    %{endfor~}

    [ops]
    localhost ansible_connection=local
  EOT
}

output "evidence_bundle" {
  description = "Machine-readable snapshot for the evidence pack"
  value = jsonencode({
    project              = var.project
    environment          = var.environment
    region               = var.region
    compartment_id       = module.iam.compartment_id
    vcn_id               = module.network.vcn_id
    lb_public_ip         = module.loadbalancer.lb_public_ips[0]
    health_url           = module.loadbalancer.http_endpoint
    app_private_ips      = module.compute_app.private_ips
    ops_public_ip        = try(module.compute_ops[0].public_ips[0], null)
    oke_cluster_id       = try(module.oke[0].cluster_id, null)
    oke_endpoint         = try(module.oke[0].cluster_endpoint, null)
    adb_id               = try(module.database[0].adb_id, null)
    adb_private_endpoint = try(module.database[0].private_endpoint, null)
    ocir_image           = "${module.ocir.image_path}:latest"
    vault_secret_id      = module.vault.db_secret_id
    alert_topic          = module.observability.topic_name
  })
}
