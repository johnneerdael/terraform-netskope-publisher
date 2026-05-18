terraform {
  required_version = ">= 1.7"

  required_providers {
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
