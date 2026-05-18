terraform {
  required_version = ">= 1.7"
  required_providers {
    helm       = { source = "hashicorp/helm", version = "~> 2.13" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
    http       = { source = "hashicorp/http", version = ">= 3.4" }
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context != "" ? var.kube_context : null
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context != "" ? var.kube_context : null
  }
}

module "publisher" {
  source = "../../modules/kubernetes"

  name_prefix = "demo-k8s"
  replicas    = 1

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  namespace = "netskope"
}

output "publishers" {
  value     = module.publisher.publishers
  sensitive = true
}
