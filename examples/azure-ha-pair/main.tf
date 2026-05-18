terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm   = { source = "hashicorp/azurerm", version = "~> 4.0" }
    http      = { source = "hashicorp/http", version = ">= 3.4" }
    cloudinit = { source = "hashicorp/cloudinit", version = ">= 2.3" }
  }
}

provider "azurerm" {
  features {}
}

module "publisher" {
  source = "../../modules/azure"

  name_prefix = "demo-az"
  replicas    = 2

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  resource_group_name  = var.resource_group_name
  location             = var.location
  subnet_id            = var.subnet_id
  admin_ssh_public_key = var.admin_ssh_public_key

  # Boot the Canonical Ubuntu 22.04 LTS Minimal marketplace image and run the
  # Netskope generic bootstrap.sh during cloud-init, then self-register with
  # the token. To use a pre-baked Netskope Publisher image, set bootstrap = false
  # and pass image_id or marketplace explicitly.
  bootstrap = true
  image_id  = var.azure_image_id
}

output "publishers" {
  value     = module.publisher.publishers
  sensitive = true
}
