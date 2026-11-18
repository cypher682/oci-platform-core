output "cluster_id" {
  value = oci_containerengine_cluster.this.id
}

output "cluster_name" {
  value = oci_containerengine_cluster.this.name
}

output "cluster_endpoint" {
  description = "Public Kubernetes API endpoint"
  value       = oci_containerengine_cluster.this.endpoints[0].public_endpoint
}

output "kubernetes_version" {
  value = local.kubernetes_version
}

output "node_pool_id" {
  value = oci_containerengine_node_pool.this.id
}

output "kubeconfig_command" {
  description = "Run this locally to produce a kubeconfig for the cluster"
  value       = "oci ce cluster create-kubeconfig --cluster-id ${oci_containerengine_cluster.this.id} --file $HOME/.kube/config-${var.project} --region ${var.region} --token-version 2.0.0 --kube-endpoint PUBLIC_ENDPOINT"
}
