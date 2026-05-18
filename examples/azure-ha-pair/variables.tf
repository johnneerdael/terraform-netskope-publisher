variable "netskope_tenant_url" {
  type = string
}

variable "netskope_api_token" {
  type      = string
  sensitive = true
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "subnet_id" {
  type = string
}

variable "admin_ssh_public_key" {
  type = string
}

variable "azure_image_id" {
  description = "Optional pre-baked image resource ID. Leave null (default) to boot the Canonical Ubuntu 22.04 LTS Minimal marketplace image via bootstrap mode."
  type        = string
  default     = null
}
