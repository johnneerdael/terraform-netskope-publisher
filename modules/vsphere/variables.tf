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

variable "datacenter" {
  type = string
}

variable "cluster" {
  type    = string
  default = null
}

variable "host" {
  type    = string
  default = null
}

variable "datastore" {
  type = string
}

variable "network_name" {
  type = string
}

variable "template_name" {
  type = string
}

variable "folder" {
  type    = string
  default = null
}

variable "num_cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 4096
}
