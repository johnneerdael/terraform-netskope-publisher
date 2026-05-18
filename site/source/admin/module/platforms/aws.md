---
title: AWS platform inputs
date: 2026-05-18
toc: true
---

## Inputs

The `aws = { ... }` object accepts:

| Name | Type | Default | Description |
|---|---|---|---|
| `subnet_id` | string | required | Subnet to launch the EC2 instance in. |
| `security_group_ids` | list(string) | required | Security groups for the instance. |
| `key_name` | string | `null` | EC2 key pair name for SSH. |
| `instance_type` | string | `"t3.medium"` | EC2 instance type. |
| `ami_id` | string | `null` | Override the auto-discovered Netskope publisher AMI. |
| `associate_public_ip_address` | bool | `false` | Whether to attach a public IPv4. |
| `iam_instance_profile` | string | `null` | IAM instance profile to attach. |
| `ebs_optimized` | bool | `true` | EBS-optimized instance. |
| `monitoring` | bool | `true` | Detailed CloudWatch monitoring. |
| `metadata_options.http_endpoint` | string | `"enabled"` | IMDS endpoint state. |
| `metadata_options.http_tokens` | string | `"required"` | IMDSv2 enforcement. |

## AMI discovery

By default the module finds the most recent AMI matching
`name = "Netskope Private Access Publisher*"` owned by account
`679593333241`. Override with `ami_id` if you maintain a private AMI.

## Minimal example

```hcl
module "publisher" {
  source = "github.com/johnneerdael/terraform-netskope-publisher//modules/aws?ref=v2.0.0"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = "subnet-..."
  security_group_ids = ["sg-..."]
  key_name           = "my-key"
}
```

## Full example

```hcl
module "publisher" {
  source = "github.com/johnneerdael/terraform-netskope-publisher//modules/aws?ref=v2.0.0"

  name_prefix = "pub-eu"
  replicas    = 2
  tags        = { Owner = "platform-team", Env = "prod" }

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id                   = "subnet-..."
  security_group_ids          = ["sg-..."]
  key_name                    = "my-key"
  instance_type               = "t3.large"
  associate_public_ip_address = false
  iam_instance_profile        = "ssm-managed"
  ebs_optimized               = true
  monitoring                  = true
  metadata_options = {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
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
