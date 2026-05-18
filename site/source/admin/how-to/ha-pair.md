---
title: Provision an HA pair
date: 2026-05-18
---

## Problem

You want two publishers behind the same set of Netskope private apps so
loss of one doesn't break tunnels.

## Solution

Set `replicas = 2` (or pass explicit `names`):

```hcl
module "publisher" {
  source = "github.com/johnneerdael/terraform-netskope-publisher//modules/aws?ref=v2.0.0"

  name_prefix = "pub-eu"
  replicas    = 2

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = var.subnet_id
  security_group_ids = [var.security_group_id]
  key_name           = var.key_name
}
```

The module creates `pub-eu-1` and `pub-eu-2`, each registered with its
own token and provisioned on its own VM.

## Notes

- Both VMs land in the **same subnet** with the current input shape.
  For multi-AZ HA, call the module twice — once per AZ-specific subnet
  — with different `name_prefix` values (e.g., `pub-eu1a`, `pub-eu1b`).
- Attach both publishers to the same Netskope private apps via the
  admin console — out of scope for this module.
