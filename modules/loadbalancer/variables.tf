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
  description = "Public subnet for the load balancer"
  type        = string
}

variable "nsg_id" {
  description = "NSG that allows 80/443 from the internet and egress to the app subnet"
  type        = string
}

variable "backend_ips" {
  description = "Private IPs of the application VMs"
  type        = list(string)
}

variable "backend_port" {
  type    = number
  default = 80
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "min_bandwidth_mbps" {
  type    = number
  default = 10
}

variable "max_bandwidth_mbps" {
  type    = number
  default = 100
}

variable "certificate_id" {
  description = "Optional OCI Certificates OCID to enable an HTTPS listener"
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
