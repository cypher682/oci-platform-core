variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "compartment_id" {
  type = string
}

variable "namespace" {
  description = "Object Storage namespace OCID-adjacent namespace string"
  type        = string
}

variable "kms_key_id" {
  description = "Optional Vault key for customer-managed encryption. Null uses Oracle-managed AES-256."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
