variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "compartment_id" {
  type = string
}

variable "subnet_id" {
  description = "Private DB subnet"
  type        = string
}

variable "nsg_id" {
  type = string
}

variable "db_name" {
  description = "Database name — alphanumeric, max 14 characters"
  type        = string
  default     = "PLATFORMDB"
}

variable "admin_password" {
  description = "ADMIN password. Must satisfy Oracle complexity rules. Never commit it."
  type        = string
  sensitive   = true
}

variable "private_endpoint_label" {
  description = "DNS label for the private endpoint — lowercase alphanumeric, max 63 characters"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
