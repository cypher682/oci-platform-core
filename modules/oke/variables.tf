variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "compartment_id" {
  type = string
}

variable "region" {
  description = "OCI region identifier — used in the kubeconfig helper"
  type        = string
}

variable "vcn_id" {
  type = string
}

variable "api_subnet_id" {
  description = "Subnet for the OKE API endpoint (public subnet recommended for CI access)"
  type        = string
}

variable "lb_subnet_id" {
  description = "Subnet used by OCI load balancers created by Kubernetes Services"
  type        = string
}

variable "node_subnet_id" {
  type = string
}

variable "nsg_api_id" {
  type = string
}

variable "nsg_nodes_id" {
  type = string
}

variable "availability_domain" {
  type = string
}

variable "kubernetes_version" {
  description = "Pin a version such as v1.30.1. Null selects the latest supported version."
  type        = string
  default     = null
}

variable "node_shape" {
  type    = string
  default = "VM.Standard.E4.Flex"
}

variable "node_flex" {
  type    = bool
  default = true
}

variable "node_ocpus" {
  type    = number
  default = 2
}

variable "node_memory_in_gbs" {
  type    = number
  default = 16
}

variable "node_count" {
  type    = number
  default = 1
}

variable "node_boot_volume_size_in_gbs" {
  type    = number
  default = 100
}

variable "ssh_public_key" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
