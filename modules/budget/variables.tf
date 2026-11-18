variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "tenancy_ocid" {
  description = "Budgets are created against the tenancy"
  type        = string
}

variable "target_compartment_id" {
  description = "Compartment whose spend is tracked"
  type        = string
}

variable "amount" {
  description = "Budget amount in USD"
  type        = number
  default     = 50
}

variable "alert_email" {
  type = string
}

variable "alert_thresholds" {
  description = "Map of label to percentage threshold"
  type        = map(number)
  default = {
    "50"  = 50
    "80"  = 80
    "100" = 100
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
