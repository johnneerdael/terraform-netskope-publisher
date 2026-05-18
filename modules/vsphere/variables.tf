variable "publisher_names" {
  type = list(string)
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
