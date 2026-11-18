variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "compartment_id" {
  type = string
}

variable "db_admin_password" {
  description = "Stored as a Vault secret so workloads never read it from source"
  type        = string
  sensitive   = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
