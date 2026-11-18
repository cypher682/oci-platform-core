# ─────────────────────────────────────────────
# Bastion — managed SSH entry point, no public SSH on private hosts
# Sessions are created on demand and expire automatically.
# ─────────────────────────────────────────────
resource "oci_bastion_bastion" "this" {
  bastion_type                 = "STANDARD"
  compartment_id               = var.compartment_id
  target_subnet_id             = var.target_subnet_id
  name                         = "${var.project}-${var.environment}-bastion"
  client_cidr_block_allow_list = var.allowed_cidrs

  freeform_tags = var.tags
}
