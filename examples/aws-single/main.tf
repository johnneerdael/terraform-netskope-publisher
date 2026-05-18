terraform {
  required_version = ">= 1.7"

  required_providers {
    aws       = { source = "hashicorp/aws", version = "~> 5.0" }
    http      = { source = "hashicorp/http", version = ">= 3.4" }
    cloudinit = { source = "hashicorp/cloudinit", version = ">= 2.3" }
  }
}

provider "aws" {
  region = var.aws_region
}

module "publisher" {
  source = "../../modules/aws"

  name_prefix = "demo-aws"
  replicas    = 1

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = var.subnet_id
  security_group_ids = [var.security_group_id]
  key_name           = var.key_name

  # Boot a stock Canonical Ubuntu 22.04 LTS Minimal AMI and run the Netskope
  # generic bootstrap.sh during cloud-init, then self-register with the token.
  # Set bootstrap = false (and provide ami_id) to use a pre-baked Netskope
  # Publisher AMI instead.
  bootstrap = true

  # Public subnet assumed. Drop this line if the subnet has NAT instead.
  associate_public_ip_address = true
}

output "publishers" {
  value     = module.publisher.publishers
  sensitive = true
}
