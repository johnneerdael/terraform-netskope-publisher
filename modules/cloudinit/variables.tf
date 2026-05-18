variable "publishers" {
  description = "Map of publisher name => registration token."
  type        = map(string)
  sensitive   = true
}

variable "wizard_path" {
  description = "Absolute path to npa_publisher_wizard on the VM."
  type        = string
  default     = "/home/ubuntu/npa_publisher_wizard"
}
