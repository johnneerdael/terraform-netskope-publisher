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
  type = string
}
