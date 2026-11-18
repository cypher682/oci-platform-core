variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "compartment_id" {
  type = string
}

variable "target_subnet_id" {
  description = "Subnet that contains the private targets (app subnet)"
  type        = string
}

variable "allowed_cidrs" {
  description = "Client CIDRs allowed to open bastion sessions. Use x.x.x.x/32."
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
