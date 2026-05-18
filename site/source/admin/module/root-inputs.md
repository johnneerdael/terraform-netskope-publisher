---
title: Root inputs
date: 2026-05-18
toc: true
---

All inputs accepted by the root module. Platform-specific inputs are
documented in [per-platform pages](/terraform-netskope-publisher/admin/module/platforms/aws/).

## Required

| Name | Type | Description |
|---|---|---|
| `platform` | string | One of `aws`, `azure`, `gcp`, `vsphere`. |
| `netskope_tenant_url` | string | e.g. `https://tenant.goskope.com`. Must start with `https://`. |
| `netskope_api_token` | string (sensitive) | NPA API token with publisher read/write scope. |

Additionally, the per-platform object matching `var.platform` (`var.aws`,
`var.azure`, `var.gcp`, `var.vsphere`) must be non-null.

## Optional — common

| Name | Type | Default | Description |
|---|---|---|---|
| `name_prefix` | string | `"npa-publisher"` | Used to derive names when `var.names` is null. |
| `names` | list(string) | `null` | Explicit publisher names. Overrides `name_prefix` + `replicas` when set. |
| `replicas` | number | `1` | Number of publishers to derive from `name_prefix`. |
| `tags` | map(string) | `{}` | Tags / labels applied per platform. |
| `wizard_path` | string | `"/home/ubuntu/npa_publisher_wizard"` | Absolute path to the wizard binary on the VM. |

## Per-platform input objects

Exactly one of these is required (must match `var.platform`):

| Name | Type | Documented at |
|---|---|---|
| `aws` | object | [AWS](/terraform-netskope-publisher/admin/module/platforms/aws/) |
| `azure` | object | [Azure](/terraform-netskope-publisher/admin/module/platforms/azure/) |
| `gcp` | object | [GCP](/terraform-netskope-publisher/admin/module/platforms/gcp/) |
| `vsphere` | object | [vSphere](/terraform-netskope-publisher/admin/module/platforms/vsphere/) |

## Validation rules

- `var.platform` must be one of the four supported platforms.
- `var.replicas` must be `>= 1`.
- The matching `var.<platform>` object must be non-null (enforced by a
  root precondition on `terraform_data.platform_input_check`).
