variable "publishers" {
  description = "Map of publisher name => registration token."
  type        = map(string)
  sensitive   = true
}

variable "wizard_path" {
  description = "Absolute path to npa_publisher_wizard on the VM. When null, defaults to /home/<install_user>/npa_publisher_wizard."
  type        = string
  default     = null
}

variable "bootstrap" {
  description = "When true, cloud-init downloads and runs the Netskope generic bootstrap.sh before registering. Use on vanilla Ubuntu images; leave false when booting a pre-baked Netskope Publisher image."
  type        = bool
  default     = false
}

variable "bootstrap_url" {
  description = "URL to the Netskope generic bootstrap script."
  type        = string
  default     = "https://s3-us-west-2.amazonaws.com/publisher.netskope.com/latest/generic/bootstrap.sh"
}

variable "nonat" {
  description = "When true, cloud-init creates ~/resources/.nonat to enable Netskope's No-NAT mode. Recommended on GCP because of the 1460-byte MTU."
  type        = bool
  default     = false
}

variable "install_user" {
  description = "Linux user that owns the Publisher install (~/resources, ~/npa_publisher_wizard). Created by cloud-init; replaces the image's default 'ubuntu' user when different."
  type        = string
  default     = "ubuntu"
}

variable "install_user_password" {
  description = "Optional password for install_user. Null means key-only login (lock_passwd true)."
  type        = string
  sensitive   = true
  default     = null
}

variable "install_user_password_is_hash" {
  description = "Set true when install_user_password is already a crypt(3) hash; false means plain text."
  type        = bool
  default     = false
}

variable "install_user_ssh_authorized_keys" {
  description = "Public SSH keys installed in ~install_user/.ssh/authorized_keys."
  type        = list(string)
  default     = []
}

variable "delete_default_user" {
  description = "When true and install_user is not 'ubuntu', cloud-init deletes the image's default ubuntu user (userdel -r). Set false to keep it alongside the new user."
  type        = bool
  default     = true
}

variable "guest_network_interface" {
  description = "Optional guest-OS primary interface override applied via netplan during cloud-init. Null leaves the image default (DHCP) untouched."
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
