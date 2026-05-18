---
title: Multi-region deployments
date: 2026-05-18
---

## Problem

You want publishers in multiple AWS regions (or Azure / GCP locations)
from one Terraform configuration.

## Solution

Define aliased providers per region and call the module once per alias:

```hcl
provider "aws" {
  alias  = "eu"
  region = "eu-west-1"
}

provider "aws" {
  alias  = "us"
  region = "us-east-1"
}

module "publisher_eu" {
  source   = "github.com/johnneerdael/terraform-netskope-publisher?ref=v1.0.0"
  platform = "aws"
  providers = { aws = aws.eu }

  name_prefix         = "pub-eu"
  replicas            = 2
  netskope_tenant_url = var.netskope_tenant_url
  netskope_api_token  = var.netskope_api_token

  aws = {
    subnet_id          = var.eu_subnet_id
    security_group_ids = [var.eu_sg_id]
    key_name           = var.eu_key_name
  }
}

module "publisher_us" {
  source   = "github.com/johnneerdael/terraform-netskope-publisher?ref=v1.0.0"
  platform = "aws"
  providers = { aws = aws.us }

  name_prefix         = "pub-us"
  replicas            = 2
  netskope_tenant_url = var.netskope_tenant_url
  netskope_api_token  = var.netskope_api_token

  aws = {
    subnet_id          = var.us_subnet_id
    security_group_ids = [var.us_sg_id]
    key_name           = var.us_key_name
  }
}
```

## Notes

- Each `module` call hits the Netskope API independently. Use distinct
  `name_prefix` values so publisher names don't collide.
- For cross-platform mixed deployments (AWS in one region, Azure in
  another), repeat the pattern with a `provider "azurerm"` alias.
