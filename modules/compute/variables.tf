variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "compartment_id" {
  type = string
}

variable "availability_domain" {
  description = "Availability domain name from data.oci_identity_availability_domains"
  type        = string
}

variable "subnet_id" {
  type = string
}

variable "nsg_ids" {
  type    = list(string)
  default = []
}

variable "shape" {
  description = "Compute shape. VM.Standard.E5.Flex matches the capacity this tenancy has; VM.Standard.A1.Flex is ARM."
  type        = string
  default     = "VM.Standard.E5.Flex"
}

variable "flex_shape" {
  description = "Whether the shape uses a flexible shape_config block"
  type        = bool
  default     = true
}

variable "ocpus" {
  type    = number
  default = 1
}

variable "memory_in_gbs" {
  type    = number
  default = 8
}

variable "boot_volume_size_in_gbs" {
  type    = number
  default = 50
}

variable "instance_count" {
  type    = number
  default = 1
}

variable "instance_role" {
  description = "Short role label: app, ops, runner"
  type        = string
}

variable "assign_public_ip" {
  type    = bool
  default = false
}

variable "ssh_public_key" {
  description = "SSH public key material (ssh-ed25519 AAAA...)"
  type        = string
}

variable "operating_system_version" {
  type    = string
  default = "9"
}

variable "tags" {
  type    = map(string)
  default = {}
}
