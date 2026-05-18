---
title: Common inputs
date: 2026-05-18
toc: true
---

Inputs accepted by every platform submodule. Platform-specific inputs
are documented on the per-platform pages
([AWS](/terraform-netskope-publisher/admin/module/platforms/aws/),
[Azure](/terraform-netskope-publisher/admin/module/platforms/azure/),
[GCP](/terraform-netskope-publisher/admin/module/platforms/gcp/),
[vSphere](/terraform-netskope-publisher/admin/module/platforms/vsphere/)).

## Required

| Name | Type | Description |
|---|---|---|
| `tenant_url` | string | Netskope tenant URL, e.g. `https://tenant.goskope.com`. Must start with `https://`. |
| `api_token` | string (sensitive) | NPA API token with publisher read/write scope. |

## Optional

| Name | Type | Default | Description |
|---|---|---|---|
| `name_prefix` | string | `"npa-publisher"` | Used to derive names when `names` is null. |
| `names` | list(string) | `null` | Explicit publisher names. When set, overrides `name_prefix` + `replicas`. |
| `replicas` | number | `1` | Number of publishers to derive from `name_prefix`. |
| `tags` | map(string) | `{}` | Tags / labels applied per platform. |
| `wizard_path` | string | `"/home/ubuntu/npa_publisher_wizard"` | Absolute path to the wizard binary on the VM. Not used by `modules/kubernetes` (the chart's container image already has the wizard at its canonical location). |

## Naming derivation

```hcl
local.publisher_names = var.names != null
  ? var.names
  : [for i in range(var.replicas) : format("%s-%d", var.name_prefix, i + 1)]
```

If you set `names`, `name_prefix` and `replicas` are ignored.
