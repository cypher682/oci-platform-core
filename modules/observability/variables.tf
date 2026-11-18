variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "compartment_id" {
  type = string
}

variable "alert_email" {
  description = "Email subscribed to the ONS alert topic — must confirm the subscription"
  type        = string
}

variable "cpu_threshold_percent" {
  type    = number
  default = 80
}

variable "adb_storage_threshold_percent" {
  type    = number
  default = 80
}

variable "enable_adb_alarm" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
