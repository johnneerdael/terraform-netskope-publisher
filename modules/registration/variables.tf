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

variable "publisher_names" {
  description = "Publisher names to ensure exist in the tenant."
  type        = list(string)

  validation {
    condition     = length(var.publisher_names) > 0
    error_message = "publisher_names must contain at least one name."
  }
}
