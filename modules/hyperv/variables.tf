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
  description = "Netskope tenant URL, e.g. https://tenant.goskope.com."
  type        = string

  validation {
    condition     = can(regex("^https://", var.tenant_url))
    error_message = "tenant_url must start with https://."
  }
}

variable "api_token" {
  description = "Netskope NPA API token."
  type        = string
  sensitive   = true
}

variable "wizard_path" {
  description = "Absolute path to npa_publisher_wizard on the VM."
  type        = string
  default     = "/home/ubuntu/npa_publisher_wizard"
}

variable "tags" {
  description = "Written into each VM's `notes` field as a JSON object (Hyper-V has no native tag concept)."
  type        = map(string)
  default     = {}
}

variable "vswitch_name" {
  description = "Name of the Hyper-V virtual switch to attach the publisher NIC to."
  type        = string
}

variable "hyperv_winrm_config" {
  description = "WinRM connection settings used by the null_resource provisioners. Mirror your provider \"hyperv\" block."
  type = object({
    host     = string
    user     = string
    password = string
    port     = optional(number, 5986)
    https    = optional(bool, true)
    insecure = optional(bool, false)
    use_ntlm = optional(bool, true)
  })
  sensitive = true
}

variable "vhdx_source_url" {
  description = "URL to the master Netskope publisher VHDX."
  type        = string
  default     = "https://s3-us-west-2.amazonaws.com/publisher.netskope.com/latest/NetskopePrivateAccessPublisher.vhdx"
}

variable "vhdx_cache_path" {
  description = "Absolute path on the Hyper-V host where the master VHDX is cached."
  type        = string
  default     = "C:\\hyperv\\netskope\\NetskopePrivateAccessPublisher.vhdx"
}

variable "vhd_dir" {
  description = "Directory on the host for per-VM cloned VHDs."
  type        = string
  default     = "C:\\hyperv\\netskope\\vhds"
}

variable "iso_dir" {
  description = "Directory on the host for per-VM NoCloud seed ISOs."
  type        = string
  default     = "C:\\hyperv\\netskope\\iso"
}

variable "vm_dir" {
  description = "Directory on the host for per-VM Hyper-V VM config."
  type        = string
  default     = "C:\\hyperv\\netskope\\vms"
}

variable "processor_count" {
  type    = number
  default = 2
}

variable "memory_startup_bytes" {
  type    = number
  default = 4294967296
}

variable "dynamic_memory" {
  type    = bool
  default = false
}

variable "generation" {
  type    = number
  default = 2
}

variable "enable_secure_boot" {
  type    = string
  default = "Off"
}

variable "vlan_id" {
  type    = number
  default = null
}

variable "force_redownload" {
  description = "Re-fetch the master VHDX even if cached. Use for upgrades."
  type        = bool
  default     = false
}
