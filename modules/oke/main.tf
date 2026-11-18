# ─────────────────────────────────────────────
# OKE — basic cluster + managed node pool on a private subnet
# Basic clusters have no cluster-management fee; workers are billed normally.
# ─────────────────────────────────────────────
data "oci_containerengine_cluster_option" "this" {
  cluster_option_id = "all"
  compartment_id    = var.compartment_id
}

locals {
  kubernetes_version = var.kubernetes_version != null ? var.kubernetes_version : data.oci_containerengine_cluster_option.this.kubernetes_versions[0]
}

resource "oci_containerengine_cluster" "this" {
  compartment_id     = var.compartment_id
  name               = "${var.project}-${var.environment}-oke"
  vcn_id             = var.vcn_id
  kubernetes_version = local.kubernetes_version
  type               = "BASIC_CLUSTER"

  endpoint_config {
    subnet_id            = var.api_subnet_id
    nsg_ids              = [var.nsg_api_id]
    is_public_ip_enabled = true
  }

  options {
    service_lb_subnet_ids = [var.lb_subnet_id]
  }

  freeform_tags = var.tags
}

data "oci_containerengine_node_pool_option" "this" {
  compartment_id        = var.compartment_id
  node_pool_option_id   = oci_containerengine_cluster.this.id
  node_pool_os_arch     = "x86_64"
  node_pool_k8s_version = local.kubernetes_version
}

locals {
  node_image_id = [
    for source in data.oci_containerengine_node_pool_option.this.sources :
    source.image_id
    if source.source_type == "IMAGE"
  ][0]
}

resource "oci_containerengine_node_pool" "this" {
  cluster_id     = oci_containerengine_cluster.this.id
  compartment_id = var.compartment_id
  name           = "${var.project}-${var.environment}-np"
  node_shape     = var.node_shape
  ssh_public_key = var.ssh_public_key

  dynamic "node_shape_config" {
    for_each = var.node_flex ? [1] : []
    content {
      ocpus         = var.node_ocpus
      memory_in_gbs = var.node_memory_in_gbs
    }
  }

  node_config_details {
    size = var.node_count

    placement_configs {
      availability_domain = var.availability_domain
      subnet_id           = var.node_subnet_id
    }

    nsg_ids = [var.nsg_nodes_id]
  }

  node_source_details {
    source_type             = "IMAGE"
    image_id                = local.node_image_id
    boot_volume_size_in_gbs = var.node_boot_volume_size_in_gbs
  }

  initial_node_labels {
    key   = "role"
    value = "worker"
  }

  freeform_tags = var.tags
}
