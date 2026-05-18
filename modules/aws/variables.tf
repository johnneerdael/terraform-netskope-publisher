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

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "key_name" {
  type    = string
  default = null
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ami_id" {
  description = "Override the auto-discovered Netskope publisher AMI."
  type        = string
  default     = null
}

variable "associate_public_ip_address" {
  type    = bool
  default = false
}

variable "iam_instance_profile" {
  type    = string
  default = null
}

variable "ebs_optimized" {
  type    = bool
  default = true
}

variable "monitoring" {
  type    = bool
  default = true
}

variable "metadata_options" {
  type = object({
    http_endpoint = optional(string, "enabled")
    http_tokens   = optional(string, "required")
  })
  default = {}
}
