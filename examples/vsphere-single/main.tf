terraform {
  required_version = ">= 1.7"

  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = "~> 2.10"
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

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

module "publisher" {
  source      = "../.."
  platform    = "vsphere"
  name_prefix = "demo-vc"
  replicas    = 1

  netskope_tenant_url = var.netskope_tenant_url
  netskope_api_token  = var.netskope_api_token

  vsphere = {
    datacenter    = var.datacenter
    cluster       = var.cluster
    datastore     = var.datastore
    network_name  = var.network_name
    template_name = var.template_name
  }
}

output "publishers" {
  value     = module.publisher.publishers
  sensitive = true
}
