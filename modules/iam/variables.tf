variable "project" {
  description = "Project name — used in all resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "tenancy_ocid" {
  description = "OCI tenancy OCID — groups, dynamic groups and tenancy policies live here"
  type        = string
}

variable "parent_compartment_id" {
  description = "Compartment that owns the platform compartment (usually the tenancy OCID)"
  type        = string
}

variable "create_compartments" {
  description = "Create a dedicated platform compartment. Set false to reuse parent_compartment_id."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Freeform tags applied to every resource"
  type        = map(string)
  default     = {}
}
