variable "project" {
  description = "Project name used in every resource name"
  type        = string
  default     = "oci-platform-core"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "owner" {
  type    = string
  default = "cypher682"
}

variable "region" {
  description = "OCI region identifier"
  type        = string
  default     = "us-ashburn-1"
}

variable "region_key" {
  description = "Three letter OCIR region key — iad for us-ashburn-1"
  type        = string
  default     = "iad"
}

variable "tenancy_ocid" {
  description = "Tenancy OCID (ocid1.tenancy.oc1..)"
  type        = string
}

variable "compartment_ocid" {
  description = "Parent compartment OCID — usually the tenancy OCID for a personal tenancy"
  type        = string
}

variable "create_compartments" {
  description = "Create a dedicated platform compartment under compartment_ocid"
  type        = bool
  default     = false
}

variable "availability_domain" {
  description = "Pin an AD, or null to use the first AD returned by the API"
  type        = string
  default     = null
}

variable "admin_cidr" {
  description = "Operator public IP in CIDR form — only this address may SSH to the ops runner"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key injected into every instance"
  type        = string
}

variable "db_admin_password" {
  description = "ADB ADMIN password. Provide via TF_VAR_db_admin_password, never in tfvars."
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email for ONS alerts and budget notifications"
  type        = string
}

variable "app_shape" {
  type    = string
  default = "VM.Standard.E4.Flex"
}

variable "app_ocpus" {
  type    = number
  default = 1
}

variable "app_memory_in_gbs" {
  type    = number
  default = 8
}

variable "app_instance_count" {
  type    = number
  default = 2
}

variable "enable_ops_runner" {
  description = "Provision an in-VCN ops runner. Required to run Ansible against private app VMs."
  type        = bool
  default     = true
}

variable "enable_oke" {
  type    = bool
  default = true
}

variable "oke_kubernetes_version" {
  description = "Null selects the latest version supported in the region"
  type        = string
  default     = null
}

variable "oke_node_shape" {
  type    = string
  default = "VM.Standard.E4.Flex"
}

variable "oke_node_ocpus" {
  type    = number
  default = 2
}

variable "oke_node_memory_in_gbs" {
  type    = number
  default = 16
}

variable "oke_node_count" {
  type    = number
  default = 1
}

variable "enable_adb" {
  type    = bool
  default = true
}

variable "adb_db_name" {
  type    = string
  default = "PLATFORMDB"
}

variable "enable_bastion" {
  type    = bool
  default = true
}

variable "enable_budget" {
  type    = bool
  default = true
}

variable "budget_amount" {
  description = "Monthly budget in USD — set below your credit balance"
  type        = number
  default     = 50
}

variable "lb_certificate_id" {
  description = "Optional OCI Certificates OCID — null keeps the LB HTTP-only"
  type        = string
  default     = null
}
