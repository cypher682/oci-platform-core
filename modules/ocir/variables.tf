variable "compartment_id" {
  type = string
}

variable "repository_name" {
  description = "Repository name, for example platform/app"
  type        = string
}

variable "region_key" {
  description = "OCIR region key, iad for us-ashburn-1"
  type        = string
}

variable "namespace" {
  description = "Object Storage namespace (also the OCIR tenancy namespace)"
  type        = string
}

variable "is_immutable" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
