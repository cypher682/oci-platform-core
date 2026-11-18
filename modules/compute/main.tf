# ─────────────────────────────────────────────
# Compute — Oracle Linux 9 instances with cloud-init bootstrap
# ─────────────────────────────────────────────
data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = var.operating_system_version
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "this" {
  count = var.instance_count

  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  display_name        = "${var.project}-${var.environment}-${var.instance_role}-${count.index + 1}"
  shape               = var.shape

  dynamic "shape_config" {
    for_each = var.flex_shape ? [1] : []
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_in_gbs
    }
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.oracle_linux.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    assign_public_ip = var.assign_public_ip
    nsg_ids          = var.nsg_ids
    hostname_label   = substr("${var.instance_role}${count.index + 1}", 0, 15)
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init.sh.tpl", {
      hostname       = "${var.project}-${var.environment}-${var.instance_role}-${count.index + 1}"
      ssh_public_key = var.ssh_public_key
      app_tier       = var.instance_role == "app"
    }))
  }

  freeform_tags = merge(var.tags, { Role = var.instance_role })

  # user_data is immutable in OCI: a changed bootstrap has to replace the
  # instance, so it is deliberately not ignored here.
}
