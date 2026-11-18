# ─────────────────────────────────────────────
# IAM — compartments, groups, policies, instance principals
# ─────────────────────────────────────────────
locals {
  platform_compartment_id = var.create_compartments ? oci_identity_compartment.platform[0].id : var.parent_compartment_id
  compartment_name        = var.create_compartments ? oci_identity_compartment.platform[0].name : "parent-compartment"
  is_root_tenancy         = !var.create_compartments && startswith(var.parent_compartment_id, "ocid1.tenancy.")
  resource_scope          = local.is_root_tenancy ? "in tenancy" : "in compartment id ${local.platform_compartment_id}"
}

resource "oci_identity_compartment" "platform" {
  count = var.create_compartments ? 1 : 0

  compartment_id = var.parent_compartment_id
  name           = "${var.project}-${var.environment}"
  description    = "Platform compartment for ${var.project} (${var.environment}) — managed by Terraform"
  enable_delete  = false

  freeform_tags = var.tags
}

# ─────────────────────────────────────────────
# Human access groups
# ─────────────────────────────────────────────
resource "oci_identity_group" "admins" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project}-${var.environment}-admins"
  description    = "Platform administrators — full control of the ${var.project} compartment"

  freeform_tags = var.tags
}

resource "oci_identity_group" "readers" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project}-${var.environment}-readers"
  description    = "Platform readers — inspect-only access for auditors and stakeholders"

  freeform_tags = var.tags
}

resource "oci_identity_policy" "admins" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project}-${var.environment}-admins-policy"
  description    = "Full control of platform resources for the admins group"

  statements = [
    "Allow group ${oci_identity_group.admins.name} to manage all-resources ${local.resource_scope}",
  ]

  freeform_tags = var.tags
}

resource "oci_identity_policy" "readers" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project}-${var.environment}-readers-policy"
  description    = "Inspect-only access for auditors"

  statements = [
    "Allow group ${oci_identity_group.readers.name} to read all-resources ${local.resource_scope}",
  ]

  freeform_tags = var.tags
}

# ─────────────────────────────────────────────
# Workload identity — instances and OKE nodes
# Used for instance principals (Vault reads, Object Storage, Monitoring)
# ─────────────────────────────────────────────
resource "oci_identity_dynamic_group" "instances" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project}-${var.environment}-instances"
  description    = "Dynamic group for all compute instances in the platform compartment"
  matching_rule  = "instance.compartment.id = '${local.platform_compartment_id}'"

  freeform_tags = var.tags
}

resource "oci_identity_policy" "instance_principals" {
  compartment_id = var.tenancy_ocid
  name           = "${var.project}-${var.environment}-instance-principals"
  description    = "Least-privilege permissions for platform workloads using instance principals"

  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.instances.name} to read secret-bundles ${local.resource_scope}",
    "Allow dynamic-group ${oci_identity_dynamic_group.instances.name} to read objects ${local.resource_scope}",
    "Allow dynamic-group ${oci_identity_dynamic_group.instances.name} to use metrics ${local.resource_scope}",
    "Allow dynamic-group ${oci_identity_dynamic_group.instances.name} to read repos ${local.resource_scope}",
    "Allow dynamic-group ${oci_identity_dynamic_group.instances.name} to read instances ${local.resource_scope}",
    "Allow dynamic-group ${oci_identity_dynamic_group.instances.name} to read vnics ${local.resource_scope}",
  ]

  freeform_tags = var.tags
}
