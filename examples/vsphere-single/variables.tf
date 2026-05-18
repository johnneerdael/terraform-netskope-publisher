variable "netskope_tenant_url" {
  type = string
}

variable "netskope_api_token" {
  type      = string
  sensitive = true
}

variable "vsphere_user" {
  type = string
}

variable "vsphere_password" {
  type      = string
  sensitive = true
}

variable "vsphere_server" {
  type = string
}

variable "datacenter" {
  type = string
}

variable "cluster" {
  type = string
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
