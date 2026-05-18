---
title: Naming, replicas, and for_each
date: 2026-05-18
---

## How names are derived

```hcl
local.publisher_names = var.names != null
  ? var.names
  : [for i in range(var.replicas) : format("%s-%d", var.name_prefix, i + 1)]
```

- If you set `var.names = ["pub-a", "pub-b"]`, the module uses those
  names literally and ignores `replicas`.
- Otherwise it derives `<name_prefix>-1`, `<name_prefix>-2`, … from
  `replicas`.

## Why `for_each`, not `count`

Every downstream resource iterates `for_each = toset(local.publisher_names)`.
Removing one name from the middle of the list does not churn the others
— Terraform identifies resources by name, not by index.

If you used `count`, removing the second entry from a list of three
would re-create the third (because its index shifts from 2 to 1).
`for_each` avoids that.

## Naming a single publisher

For one-off setups, the default works:

```hcl
module "publisher" {
  source      = "github.com/johnneerdael/terraform-netskope-publisher?ref=v1.0.0"
  platform    = "aws"
  name_prefix = "main-publisher"
  # replicas defaults to 1 → one publisher named "main-publisher-1"
}
```

If you want exactly `main-publisher` (no `-1` suffix), use
`names = ["main-publisher"]`.
