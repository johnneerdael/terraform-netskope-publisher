variable "netskope_tenant_url" {
  type = string
}

variable "netskope_api_token" {
  type      = string
  sensitive = true
}

variable "hyperv_host" {
  description = "Hyper-V host hostname or IP (reachable via WinRM)."
  type        = string
}

variable "hyperv_user" {
  description = "Local admin or domain user on the Hyper-V host."
  type        = string
}

variable "hyperv_password" {
  type      = string
  sensitive = true
}

variable "vswitch_name" {
  description = "Existing virtual switch on the Hyper-V host."
  type        = string
}
