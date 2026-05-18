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
  containing `sudo <wizard_path> -token <token>` (run as `install_user`)
  and, in bootstrap mode, the `curl … bootstrap.sh | sudo bash` step that
  installs the wizard onto a stock Ubuntu image first.

The platform submodule then provisions one VM per derived publisher name
with `for_each`, attaching the rendered user-data via the cloud-specific
mechanism (`user_data_base64` / `custom_data` / `metadata.user-data` /
`extra_config.guestinfo.userdata`).

## Two install paths (v2.3+)

| Path | Image | Cloud-init runcmd |
|---|---|---|
| **Bootstrap** (`bootstrap = true`) | Stock Canonical Ubuntu 22.04 LTS Minimal — auto-resolved per platform | `chmod 1777 /tmp` → write `~/resources/.nonat` (when `nonat=true`) → `curl … bootstrap.sh \| sudo bash` → `npa_publisher_wizard -token …` |
| **Pre-baked** (`bootstrap = false`) | Netskope Publisher AMI / marketplace image / GCE image / OVA / VHDX | `npa_publisher_wizard -token …` |

GCP defaults to bootstrap mode (`bootstrap = true`, `nonat = true`) so
the public Ubuntu Minimal family works out of the box and Netskope's
No-NAT mode is applied for the 1460-byte MTU. AWS and Azure default to
the pre-baked path for backward compatibility; flipping `bootstrap = true`
on either causes the module to auto-resolve a stock Canonical AMI /
marketplace image instead.

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
| `modules/kubernetes` | Helm chart install + per-mode Kubernetes Secrets (token / api) | `hashicorp/helm`, `hashicorp/kubernetes` |

See also: [Registration flow](/terraform-netskope-publisher/admin/concepts/registration-flow/).
