# ─────────────────────────────────────────────
# Budget guardrail — stops a sprint from eating the credit silently
# ─────────────────────────────────────────────
resource "oci_budget_budget" "this" {
  compartment_id = var.tenancy_ocid
  display_name   = "${var.project}-${var.environment}-budget"
  description    = "Monthly budget guardrail for the platform sprint"
  amount         = var.amount
  reset_period   = "MONTHLY"
  target_type    = "COMPARTMENT"
  targets        = [var.target_compartment_id]

  freeform_tags = var.tags
}

resource "oci_budget_alert_rule" "threshold" {
  for_each = var.alert_thresholds

  budget_id      = oci_budget_budget.this.id
  display_name   = "${var.project}-${var.environment}-budget-${each.key}pct"
  type           = "ACTUAL"
  threshold      = each.value
  threshold_type = "PERCENTAGE"
  recipients     = var.alert_email
  message        = "Platform budget has reached ${each.value}% of $${var.amount}. Check running resources now."
}
