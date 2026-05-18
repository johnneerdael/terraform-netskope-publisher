variable "platform" {
  description = "Target platform: aws | azure | gcp | vsphere."
  type        = string

  validation {
    condition     = contains(["aws", "azure", "gcp", "vsphere"], var.platform)
    error_message = "platform must be one of: aws, azure, gcp, vsphere."
  }
}

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
  description = "Number of publishers to create when var.names is null."
  type        = number
  default     = 1

  validation {
    condition     = var.replicas >= 1
    error_message = "replicas must be >= 1."
  }
}

variable "tags" {
  description = "Map of tags / labels applied per platform."
  type        = map(string)
  default     = {}
}

variable "netskope_tenant_url" {
  description = "Netskope tenant URL, e.g. https://tenant.goskope.com."
  type        = string
}

variable "netskope_api_token" {
  description = "Netskope NPA API token."
  type        = string
  sensitive   = true
}

variable "wizard_path" {
  description = "Absolute path to npa_publisher_wizard on the VM."
  type        = string
  default     = "/home/ubuntu/npa_publisher_wizard"
}

variable "aws" {
  description = "AWS-specific inputs (see modules/aws/variables.tf)."
  type        = any
  default     = null
}

variable "azure" {
  description = "Azure-specific inputs (see modules/azure/variables.tf)."
  type        = any
  default     = null
}

variable "gcp" {
  description = "GCP-specific inputs (see modules/gcp/variables.tf)."
  type        = any
  default     = null
}

variable "vsphere" {
  description = "vSphere-specific inputs (see modules/vsphere/variables.tf)."
  type        = any
  default     = null
}
