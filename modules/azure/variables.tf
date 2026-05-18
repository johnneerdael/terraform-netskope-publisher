variable "name_prefix" {
  description = "Prefix used to derive publisher names when var.names is null."
  type        = string
  default     = "npa-publisher"
}

variable "names" {
  description = "Explicit publisher names. When set, overrides name_prefix + replicas."
  type        = list(string)
  default     = null
}

variable "replicas" {
  description = "Number of publishers to derive from name_prefix when var.names is null."
  type        = number
  default     = 1

  validation {
    condition     = var.replicas >= 1
    error_message = "replicas must be >= 1."
  }
}

variable "tenant_url" {
  type = string
}

variable "api_token" {
  type      = string
  sensitive = true
}

variable "wizard_path" {
  type    = string
  default = "/home/ubuntu/npa_publisher_wizard"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "admin_username" {
  type    = string
  default = "ubuntu"
}

variable "admin_ssh_public_key" {
  type = string
}

variable "network_security_group_id" {
  type    = string
  default = null
}

variable "assign_public_ip" {
  type    = bool
  default = false
}

variable "os_disk" {
  type = object({
    type    = optional(string, "Premium_LRS")
    size_gb = optional(number, 64)
  })
  default = {}
}

variable "image_id" {
  description = "Resource ID of an existing image. Mutually exclusive with marketplace."
  type        = string
  default     = null
}

variable "marketplace" {
  description = "Marketplace image reference. Used when image_id is null."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = optional(string, "latest")
  })
  default = null
}

variable "accept_marketplace_terms" {
  type    = bool
  default = false
}
