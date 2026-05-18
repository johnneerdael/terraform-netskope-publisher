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
  description = "Number of publishers. In token mode this is one Helm release per name. In api mode this is one Helm release whose pod replicas register themselves."
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
  description = "Netskope NPA API token. Used by modules/registration (token mode) or written to the chart's API secret (api mode)."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Map of labels applied to all chart resources via commonLabels."
  type        = map(string)
  default     = {}
}

variable "namespace" {
  description = "Namespace to install the chart into. Created if it does not exist."
  type        = string
  default     = "netskope"
}

variable "enrollment_mode" {
  description = "token: Terraform owns the publisher record via our provider and feeds the chart a registration token. api: chart self-registers via the Netskope API on pod start."
  type        = string
  default     = "token"

  validation {
    condition     = contains(["token", "api"], var.enrollment_mode)
    error_message = "enrollment_mode must be \"token\" or \"api\"."
  }
}

variable "chart_version" {
  description = "Helm chart version constraint."
  type        = string
  default     = "~> 1.4"
}

variable "chart_repository" {
  description = "Helm chart repository (OCI URL or HTTPS repo URL)."
  type        = string
  default     = "oci://ghcr.io/johnneerdael/charts"
}

variable "chart_values" {
  description = "Free-form object merged into the Helm values last. Escape hatch for anything not surfaced as a typed input."
  type        = any
  default     = {}
}

variable "workload_type" {
  description = "daemonset or statefulset. Pass-through to chart values.workload.type. statefulset is required for HPA."
  type        = string
  default     = "daemonset"

  validation {
    condition     = contains(["daemonset", "statefulset"], var.workload_type)
    error_message = "workload_type must be \"daemonset\" or \"statefulset\"."
  }
}

variable "hpa_enabled" {
  description = "Enable HorizontalPodAutoscaler. Only meaningful with workload_type = \"statefulset\"."
  type        = bool
  default     = false
}

variable "hpa_min_replicas" {
  type    = number
  default = 2
}

variable "hpa_max_replicas" {
  type    = number
  default = 6
}

variable "image_repository" {
  description = "Override the publisher container image repository (e.g. a private mirror). null = use chart default."
  type        = string
  default     = null
}

variable "image_tag" {
  description = "Override the publisher container image tag. null = use chart default."
  type        = string
  default     = null
}
