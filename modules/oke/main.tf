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
  compartment_id      = var.compartment_id
  node_pool_option_id = oci_containerengine_cluster.this.id
  node_pool_os_arch   = "X86_64"
}

locals {
  # Image names look like "Oracle-Linux-9.8-2026.08.14-0-OKE-1.33.10-1699".
  # The build version (1699) is not the Kubernetes version, so parse the OKE
  # suffix instead of relying on list order.
  node_images = [
    for source in data.oci_containerengine_node_pool_option.this.sources : {
      image_id = source.image_id
      name     = source.source_name
      version  = try(split("-", split("-OKE-", source.source_name)[1])[0], null)
    }
    if source.source_type == "IMAGE" && !can(regex("GPU", source.source_name))
  ]

  # Zero-padded keys make lexicographic sorting match version ordering.
  versioned_images = [
    for image in local.node_images : merge(image, {
      key = join("", [for part in split(".", image.version) : format("%05d", tonumber(part))])
    }) if image.version != null
  ]

  cluster_key = join("", [for part in split(".", trimprefix(local.kubernetes_version, "v")) : format("%05d", tonumber(part))])

  # Oracle does not always publish node images for the newest control plane
  # patch, and the node pool may only be one minor version behind the cluster.
  # Anything newer than the control plane is not a valid node version.
  usable_images = [for image in local.versioned_images : image if image.key <= local.cluster_key]

  candidate_images = length(local.usable_images) > 0 ? local.usable_images : local.versioned_images
  candidate_keys   = [for image in local.candidate_images : image.key]
  node_image       = [for image in local.candidate_images : image if image.key == sort(local.candidate_keys)[length(local.candidate_keys) - 1]][0]

  node_image_id    = local.node_image.image_id
  node_k8s_version = "v${local.node_image.version}"
}

resource "oci_containerengine_node_pool" "this" {
  cluster_id     = oci_containerengine_cluster.this.id
  compartment_id = var.compartment_id
  name           = "${var.project}-${var.environment}-np"
  node_shape     = var.node_shape
  ssh_public_key = var.ssh_public_key

  # Node versions are pinned to the newest image OCI publishes for this
  # control plane, which is often one patch or one minor behind it.
  kubernetes_version = local.node_k8s_version

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
