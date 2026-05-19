---
title: AWS platform inputs
date: 2026-05-19
toc: true
---

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `subnet_id` | string | required | Subnet to launch the EC2 instance in. |
| `security_group_ids` | list(string) | required | Security groups for the instance. |
| `key_name` | string | `null` | EC2 key pair name for SSH. |
| `instance_type` | string | `"t3.medium"` | EC2 instance type. |
| `ami_id` | string | `null` | Override AMI selection. When null, the module auto-resolves Canonical Ubuntu Minimal under `bootstrap = true`, or the Netskope Publisher AMI otherwise. |
| `associate_public_ip_address` | bool | `false` | Whether to attach a public IPv4. |
| `iam_instance_profile` | string | `null` | IAM instance profile to attach. |
| `ebs_optimized` | bool | `true` | EBS-optimized instance. |
| `monitoring` | bool | `true` | Detailed CloudWatch monitoring. |
| `metadata_options.http_endpoint` | string | `"enabled"` | IMDS endpoint state. |
| `metadata_options.http_tokens` | string | `"required"` | IMDSv2 enforcement. |

See [Common inputs](/terraform-netskope-publisher/admin/module/common-inputs/)
for `bootstrap`, `bootstrap_url`, `nonat`, `install_user`,
`install_user_password`, `install_user_ssh_authorized_keys`,
`delete_default_user`, `guest_network_interface`, and `wizard_path`
(all v2.3+).

## AMI discovery (v2.3+)

The module declares two `data "aws_ami"` lookups that are toggled by
`bootstrap`:

| Mode | Data source | Filter |
|---|---|---|
| Default (`bootstrap = false`) | `data.aws_ami.publisher[0]` | Owner `679593333241`, name `Netskope Private Access Publisher*` |
| Bootstrap (`bootstrap = true`) | `data.aws_ami.ubuntu_minimal[0]` | Owner `099720109477` (Canonical), name `ubuntu-minimal/images/hvm-ssd*/ubuntu-jammy-22.04-amd64-minimal-*`, x86_64, hvm |

Whichever path is inactive uses `count = 0` so no API call is wasted,
and bootstrap-mode callers don't need access to Netskope's marketplace
AMI listing. `ami_id` wins over both when explicitly set.

## Minimal example — pre-baked Netskope AMI (default)

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.3"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = "subnet-..."
  security_group_ids = ["sg-..."]
  key_name           = "my-key"
}
```

## Bootstrap example — Canonical Ubuntu Minimal

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.3"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = "subnet-..."
  security_group_ids = ["sg-..."]
  key_name           = "my-key"

  bootstrap = true
}
```

## Full main.tf example — bootstrap, custom user, SSH key, and password

```hcl
terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "netskope_tenant_url" {
  type = string
}

variable "netskope_api_token" {
  type      = string
  sensitive = true
}

variable "npa_password" {
  type      = string
  sensitive = true
}

resource "tls_private_key" "publisher_ssh" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "publisher" {
  key_name   = "npa-publisher-admin"
  public_key = tls_private_key.publisher_ssh.public_key_openssh
}

module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.3"

  name_prefix = "pub-eu"
  replicas    = 2
  tags        = { Owner = "platform-team", Env = "prod" }

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = "subnet-..."
  security_group_ids = ["sg-..."]
  key_name           = aws_key_pair.publisher.key_name
  instance_type      = "t3.large"
  # false assumes the subnet has NAT (or another egress path). Flip to true
  # for a public subnet. See:
  # /terraform-netskope-publisher/admin/concepts/connectivity/
  associate_public_ip_address = false
  iam_instance_profile        = "ssm-managed"
  ebs_optimized               = true
  monitoring                  = true
  metadata_options = {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  bootstrap             = true
  install_user          = "npa"
  install_user_password = var.npa_password # sensitive
  install_user_ssh_authorized_keys = [
    tls_private_key.publisher_ssh.public_key_openssh,
    file(pathexpand("~/.ssh/team_ed25519.pub")),
  ]

  guest_network_interface = {
    name        = "ens5"
    dhcp4       = true
    nameservers = ["8.8.8.8", "1.1.1.1"]
    mtu         = 9001
  }
}

output "publisher_names" {
  value = module.publisher.publisher_names
}

output "publisher_private_ips" {
  value = {
    for name, publisher in module.publisher.publishers : name => publisher.private_ip
  }
  sensitive = true
}

output "publisher_private_key_pem" {
  value     = tls_private_key.publisher_ssh.private_key_pem
  sensitive = true
}
```

## Platform-specific outputs

| Output | Type | Description |
|---|---|---|
| `aws_instance_ids` | list(string) | EC2 instance IDs in publisher-name order. |
| `userdata_b64_by_name` | map(string) (sensitive) | Base64-encoded cloud-init per publisher. |

## Caveats

- AMI lookup requires the calling identity to have `ec2:DescribeImages`.
  If you scope IAM down, allow that action.
- The legacy SSM-based registration path is removed in v1; all
  registration is cloud-init only.
