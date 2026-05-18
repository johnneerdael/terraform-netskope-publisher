variable "netskope_tenant_url" {
  type = string
}

variable "netskope_api_token" {
  type      = string
  sensitive = true
}

variable "project" {
  type = string
}

variable "zone" {
  type    = string
  default = "europe-west4-a"
}

variable "network" {
  type    = string
  default = "default"
}

variable "subnetwork" {
  type    = string
  default = "default"
}

variable "image" {
  description = "Compute image self-link or family. Defaults to the public Ubuntu 22.04 LTS image; cloud-init runs the Netskope bootstrap script on first boot."
  type        = string
  default     = "projects/ubuntu-os-cloud/global/images/family/ubuntu-minimal-2204-lts"
}
