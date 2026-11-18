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

variable "compute_count" {
  description = "ECPUs allocated to the database. 2 is the minimum for an Autonomous Database."
  type        = number
  default     = 2
}

variable "data_storage_size_in_gb" {
  description = "Data storage in GB. 20 is the minimum for a paid Autonomous Database."
  type        = number
  default     = 20
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
