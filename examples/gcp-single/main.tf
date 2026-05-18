terraform {
  required_version = ">= 1.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.3"
    }
  }
}

provider "google" {
  project = var.project
  zone    = var.zone
}

module "publisher" {
  source      = "../.."
  platform    = "gcp"
  name_prefix = "demo-gcp"
  replicas    = 1

  netskope_tenant_url = var.netskope_tenant_url
  netskope_api_token  = var.netskope_api_token

  gcp = {
    project    = var.project
    zone       = var.zone
    network    = var.network
    subnetwork = var.subnetwork
    image      = var.image
  }
}

output "publishers" {
  value     = module.publisher.publishers
  sensitive = true
}
