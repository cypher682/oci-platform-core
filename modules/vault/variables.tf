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

variable "tenancy_ocid" {
  description = "Tenancy where the Object Storage service policy is created"
  type        = string
}

variable "region" {
  description = "Region identifier used in the Object Storage service principal"
  type        = string
}
