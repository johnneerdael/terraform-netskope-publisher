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
