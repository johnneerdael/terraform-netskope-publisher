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

variable "project" {
  type = string
}

variable "zone" {
  type = string
}

variable "network" {
  type = string
}

variable "subnetwork" {
  type = string
}

variable "machine_type" {
  type    = string
  default = "e2-medium"
}

variable "image" {
  description = "Compute image self-link (e.g. projects/.../global/images/...)."
  type        = string
}

variable "assign_public_ip" {
  type    = bool
  default = false
}

variable "network_tags" {
  type    = list(string)
  default = []
}

variable "service_account" {
  type = object({
    email  = string
    scopes = optional(list(string), ["https://www.googleapis.com/auth/cloud-platform"])
  })
  default = null
}

variable "bootstrap" {
  description = "Run the Netskope generic bootstrap.sh during cloud-init. Default true because the public Ubuntu 22.04 GCP image does not ship the Publisher; set false when booting a pre-baked Netskope Publisher image."
  type        = bool
  default     = true
}

variable "bootstrap_url" {
  description = "URL to the Netskope generic bootstrap script."
  type        = string
  default     = "https://s3-us-west-2.amazonaws.com/publisher.netskope.com/latest/generic/bootstrap.sh"
}

variable "nonat" {
  description = "Enable Netskope No-NAT mode by creating ~/resources/.nonat. Recommended on GCP because of the 1460-byte MTU."
  type        = bool
  default     = true
}

variable "install_user" {
  description = "Linux user that owns the Publisher install. Replaces the image's default 'ubuntu' user when different (the new user becomes the default)."
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
  description = "Public SSH keys installed in ~install_user/.ssh/authorized_keys."
  type        = list(string)
  default     = []
}

variable "delete_default_user" {
  description = "When true and install_user is not 'ubuntu', cloud-init deletes the image's default ubuntu user. Set false to keep it alongside the new user."
  type        = bool
  default     = true
}

variable "guest_network_interface" {
  description = "Optional guest-OS primary interface override applied via netplan during cloud-init. Null leaves the image default (DHCP) untouched. Distinct from the GCE network/subnetwork inputs."
  type = object({
    name        = string
    dhcp4       = optional(bool, false)
    addresses   = optional(list(string), [])
    gateway4    = optional(string)
    nameservers = optional(list(string), [])
    mtu        = optional(number)
  })
  default = null
}
