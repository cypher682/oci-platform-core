variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "compartment_id" {
  description = "Compartment that owns the VCN"
  type        = string
}

variable "vcn_cidr" {
  description = "VCN CIDR block"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet — OCI load balancer, OKE API endpoint, ops runner"
  type        = string
  default     = "10.20.0.0/24"
}

variable "app_subnet_cidr" {
  description = "Private subnet — Ansible-managed application VMs"
  type        = string
  default     = "10.20.10.0/24"
}

variable "db_subnet_cidr" {
  description = "Private subnet — Autonomous Database private endpoint"
  type        = string
  default     = "10.20.20.0/24"
}

variable "oke_node_subnet_cidr" {
  description = "Private subnet — OKE worker nodes"
  type        = string
  default     = "10.20.30.0/24"
}

variable "admin_cidr" {
  description = "Your public IP in CIDR form (x.x.x.x/32). Only this address can SSH to the ops runner."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
