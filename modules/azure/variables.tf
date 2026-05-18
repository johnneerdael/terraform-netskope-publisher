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
  description = "Absolute path to npa_publisher_wizard on the VM. When null (default), derives from install_user as /home/<install_user>/npa_publisher_wizard."
  type        = string
  default     = null
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
  description = "Azure VM admin user. When null, defaults to install_user so the cloud-init user and the Azure admin are the same account."
  type        = string
  default     = null
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

variable "bootstrap" {
  description = "Run the Netskope generic bootstrap.sh during cloud-init on a vanilla Ubuntu image. Set false (default) when booting a pre-baked Netskope Publisher marketplace image."
  type        = bool
  default     = false
}

variable "bootstrap_url" {
  description = "URL to the Netskope generic bootstrap script."
  type        = string
  default     = "https://s3-us-west-2.amazonaws.com/publisher.netskope.com/latest/generic/bootstrap.sh"
}

variable "nonat" {
  description = "Enable Netskope No-NAT mode by creating ~/resources/.nonat. Default false on Azure."
  type        = bool
  default     = false
}

variable "install_user" {
  description = "Linux user that owns the Publisher install. Replaces the image's default 'ubuntu' user when different."
  type        = string
  default     = "ubuntu"
}

variable "install_user_password" {
  description = "Optional password for install_user. Null means key-only login."
  type        = string
  sensitive   = true
  default     = null
}

variable "install_user_password_is_hash" {
  description = "Set true when install_user_password is already a crypt(3) hash."
  type        = bool
  default     = false
}

variable "install_user_ssh_authorized_keys" {
  description = "Extra public SSH keys installed in ~install_user/.ssh/authorized_keys (in addition to admin_ssh_public_key, which Azure injects natively)."
  type        = list(string)
  default     = []
}

variable "delete_default_user" {
  description = "When true and install_user is not 'ubuntu', cloud-init deletes the image's default ubuntu user."
  type        = bool
  default     = true
}

variable "guest_network_interface" {
  description = "Optional guest-OS primary interface override applied via netplan during cloud-init. Null leaves the image default (DHCP) untouched. Distinct from the Azure subnet / NIC configuration."
  type = object({
    name        = string
    dhcp4       = optional(bool, false)
    addresses   = optional(list(string), [])
    gateway4    = optional(string)
    nameservers = optional(list(string), [])
    mtu         = optional(number)
  })
  default = null
}
