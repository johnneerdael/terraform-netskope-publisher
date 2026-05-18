---
title: 6. Your first publisher
date: 2026-05-18
---

> ⏱ ~10 min including instance boot time.

Create a fresh working directory anywhere on disk:

{% tabs make-dir %}
{% tab macOS %}

```bash
mkdir ~/npa-publisher-starter && cd ~/npa-publisher-starter
```

{% endtab %}
{% tab Windows %}

```pwsh
mkdir $HOME\npa-publisher-starter
cd $HOME\npa-publisher-starter
```

{% endtab %}
{% endtabs %}

Create `main.tf` with this content (replace the three `subnet_id`,
`security_group_ids`, and `key_name` values with the IDs you collected
in step 3):

```hcl
terraform {
  required_version = ">= 1.7"
  required_providers {
    aws       = { source = "hashicorp/aws",       version = "~> 5.0" }
    http      = { source = "hashicorp/http",      version = ">= 3.4" }
    cloudinit = { source = "hashicorp/cloudinit", version = ">= 2.3" }
  }
}

provider "aws" {
  region = "eu-west-1"
}

variable "netskope_tenant_url" {
  type = string
}

variable "netskope_api_token" {
  type      = string
  sensitive = true
}

module "publisher" {
  source   = "github.com/johnneerdael/terraform-netskope-publisher?ref=v1.0.0"
  platform = "aws"

  name_prefix = "my-first-publisher"
  replicas    = 1

  netskope_tenant_url = var.netskope_tenant_url
  netskope_api_token  = var.netskope_api_token

  aws = {
    subnet_id          = "subnet-REPLACE-ME"
    security_group_ids = ["sg-REPLACE-ME"]
    key_name           = "npa-publisher-key"
  }
}

output "publishers" {
  value     = module.publisher.publishers
  sensitive = true
}
```

Initialize Terraform (downloads the module and providers):

```bash
terraform init
```

Show what will happen:

```bash
terraform plan
```

You should see roughly +5 resources (one publisher record via the
Netskope API, one EC2 instance, plus internal data sources).

Apply:

```bash
terraform apply
```

Type `yes` when prompted. Wait ~2 minutes for the EC2 instance to boot
and for cloud-init to run the publisher registration wizard.

Next → [Verify it's online](/terraform-netskope-publisher/starter/07-verify-online/)
