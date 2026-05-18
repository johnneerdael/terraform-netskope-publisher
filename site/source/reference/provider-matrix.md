---
title: Provider compatibility matrix
date: 2026-05-18
---

## Terraform

| Component | Version |
|---|---|
| `terraform` | `>= 1.7` |

`1.7` is required for the `mock_provider` block used by the test suite.
Older Terraform will still run the module itself.

## Always required

| Provider | Source | Version |
|---|---|---|
| http | `hashicorp/http` | `>= 3.4` |
| cloudinit | `hashicorp/cloudinit` | `>= 2.3` |

`http >= 3.4` is needed for `method = "POST"` on the `http` data source.

## Required per platform

| Submodule | Provider | Source | Version |
|---|---|---|---|
| `modules/aws` | `aws` | `hashicorp/aws` | `~> 5.0` |
| `modules/azure` | `azurerm` | `hashicorp/azurerm` | `~> 4.0` |
| `modules/gcp` | `google` | `hashicorp/google` | `~> 6.0` |
| `modules/vsphere` | `vsphere` | `vmware/vsphere` | `~> 2.10` |
| `modules/hyperv` | `hyperv` | `taliesins/hyperv` | `~> 1.2` |
| `modules/kubernetes` | `helm`, `kubernetes` | `hashicorp/helm`, `hashicorp/kubernetes` | `~> 2.13`, `~> 2.30` |

Only the provider for the submodule you source is loaded — the others
are never instantiated.

## Bootstrap-mode base images (v2.3+)

When `bootstrap = true` and no platform-specific image is set, the
module auto-resolves a stock Canonical Ubuntu 22.04 LTS Minimal image:

| Submodule | Image source | Reference |
|---|---|---|
| `modules/aws` | AMI lookup | Owner `099720109477` (Canonical); name pattern `ubuntu-minimal/images/hvm-ssd*/ubuntu-jammy-22.04-amd64-minimal-*`; x86_64; hvm |
| `modules/azure` | Marketplace reference | `Canonical / 0001-com-ubuntu-minimal-jammy / minimal-22_04-lts-gen2 / latest` (no `plan {}` required) |
| `modules/gcp` | Image family | `projects/ubuntu-os-cloud/global/images/family/ubuntu-minimal-2204-lts` |

`bootstrap.sh` is downloaded from
`https://s3-us-west-2.amazonaws.com/publisher.netskope.com/latest/generic/bootstrap.sh`
by default; override with the `bootstrap_url` input.
