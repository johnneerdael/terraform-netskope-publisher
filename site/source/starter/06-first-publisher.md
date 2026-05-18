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
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.3"

  name_prefix = "my-first-publisher"
  replicas    = 1

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = "subnet-REPLACE-ME"
  security_group_ids = ["sg-REPLACE-ME"]
  key_name           = "npa-publisher-key"

  # v2.3: boot a stock Canonical Ubuntu 22.04 LTS Minimal AMI and install
  # the Publisher via Netskope's bootstrap.sh during cloud-init. No
  # marketplace subscription needed. Set bootstrap = false (and pass
  # ami_id) to use a pre-baked Netskope Publisher AMI instead.
  bootstrap = true

  # The starter assumes a public subnet. If your subnet has NAT instead,
  # drop this line.
  associate_public_ip_address = true
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

Type `yes` when prompted. The EC2 instance boots in about 2 minutes, but
because `bootstrap = true` makes cloud-init download and install the
Publisher software on first boot, **registration takes ~5–10 minutes
total**. The Netskope console will show the publisher Offline at first,
then Online once `bootstrap.sh` finishes and the wizard runs.

If you'd rather skip the bootstrap step, set `bootstrap = false` and
provide `ami_id = "ami-..."` pointing at a pre-baked Netskope Publisher
AMI — registration then completes within ~2 minutes of `apply`.

Next → [Verify it's online](/terraform-netskope-publisher/starter/07-verify-online/)
