---
title: Architecture overview
date: 2026-05-18
---

## The big picture

Each cloud platform is its own Terraform submodule
(`modules/aws`, `modules/azure`, `modules/gcp`, `modules/vsphere`).
You source the one you need:

```hcl
module "publisher" {
  source = "github.com/johnneerdael/terraform-netskope-publisher//modules/aws?ref=v2.0.0"
  # …
}
```

Each platform submodule calls two shared submodules:

- `modules/registration` — talks to the Netskope NPA API via the `http`
  provider (list → create-if-missing → token).
- `modules/cloudinit` — renders a cloud-init user-data document
  containing `/home/ubuntu/npa_publisher_wizard -token <token>`.

The platform submodule then provisions one VM per derived publisher name
with `for_each`, attaching the rendered user-data via the cloud-specific
mechanism (`user_data_base64` / `custom_data` / `metadata.user-data` /
`extra_config.guestinfo.userdata`).

## Provider isolation

Each platform submodule declares only its own provider in
`required_providers`. A consumer sourcing `//modules/aws` never
instantiates the `azurerm`, `google`, or `vsphere` providers — those
declarations live inside the unused submodules and only resolve when
you source them.

> v1 had a multi-platform root module that routed on `var.platform`,
> but Terraform requires every declared submodule's provider to be
> configurable, so v1 forced consumers to configure all four. v2 removes
> that root module.

## What lives where

| Submodule | Responsibility | Providers |
|---|---|---|
| `modules/registration` | Netskope API: list/create publisher, issue registration token | `hashicorp/http` |
| `modules/cloudinit` | Render user-data + NoCloud meta-data per publisher | `hashicorp/cloudinit` |
| `modules/aws` | EC2 instance, AMI lookup | `hashicorp/aws` |
| `modules/azure` | Linux VM, NIC, optional PIP, optional NSG attach, marketplace agreement | `hashicorp/azurerm` |
| `modules/gcp` | Compute Engine instance, metadata user-data | `hashicorp/google` |
| `modules/vsphere` | VM cloned from template, guestinfo cloud-init | `vmware/vsphere` |
| `modules/hyperv` | VM cloned from a master VHDX, NoCloud seed ISO built on the host via IMAPI2 | `taliesins/hyperv` |

See also: [Registration flow](/terraform-netskope-publisher/admin/concepts/registration-flow/).
