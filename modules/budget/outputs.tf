output "budget_id" {
  value = oci_budget_budget.this.id
}

output "budget_name" {
  value = oci_budget_budget.this.display_name
}
