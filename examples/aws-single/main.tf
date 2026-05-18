terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

provider "aws" {
  region = var.aws_region
}

module "publisher" {
  source      = "../.."
  platform    = "aws"
  name_prefix = "demo-aws"
  replicas    = 1

  netskope_tenant_url = var.netskope_tenant_url
  netskope_api_token  = var.netskope_api_token

  aws = {
    subnet_id          = var.subnet_id
    security_group_ids = [var.security_group_id]
    key_name           = var.key_name
  }
}

output "publishers" {
  value     = module.publisher.publishers
  sensitive = true
}

output "registration_tokens" {
  value     = module.publisher.registration_tokens
  sensitive = true
}
