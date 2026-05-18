---
title: Architecture overview
date: 2026-05-18
---

## The big picture

One root module routes on `var.platform` to one of four platform
submodules (`modules/aws`, `modules/azure`, `modules/gcp`,
`modules/vsphere`). Each platform submodule calls two shared submodules:

- `modules/registration` — talks to the Netskope NPA API via the `http`
  provider (list → create-if-missing → token).
- `modules/cloudinit` — renders a cloud-init user-data document
  containing `/home/ubuntu/npa_publisher_wizard -token <token>`.

The platform submodule then provisions one VM per publisher name with
`for_each`, attaching the rendered user-data via the cloud-specific
mechanism (`user_data_base64` / `custom_data` / `metadata.user-data` /
`extra_config.guestinfo.userdata`).

## Provider isolation

Each platform submodule declares only its own provider in
`required_providers`. A consumer using `platform = "aws"` never
instantiates the `azurerm`, `google`, or `vsphere` providers because
those declarations live inside the unused submodules.

## What lives where

| Submodule | Responsibility | Providers |
|---|---|---|
| `modules/registration` | Netskope API: list/create publisher, issue registration token | `hashicorp/http` |
| `modules/cloudinit` | Render user-data + NoCloud meta-data per publisher | `hashicorp/cloudinit` |
| `modules/aws` | EC2 instance, AMI lookup | `hashicorp/aws` |
| `modules/azure` | Linux VM, NIC, optional PIP, optional NSG attach, marketplace agreement | `hashicorp/azurerm` |
| `modules/gcp` | Compute Engine instance, metadata user-data | `hashicorp/google` |
| `modules/vsphere` | VM cloned from template, guestinfo cloud-init | `vmware/vsphere` |

See also: [Registration flow](/terraform-netskope-publisher/admin/concepts/registration-flow/).
