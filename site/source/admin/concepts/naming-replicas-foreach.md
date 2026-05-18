---
title: Naming, replicas, and for_each
date: 2026-05-18
---

## How names are derived

Each platform submodule contains:

```hcl
local.publisher_names = var.names != null
  ? var.names
  : [for i in range(var.replicas) : format("%s-%d", var.name_prefix, i + 1)]
```

- Set `var.names = ["pub-a", "pub-b"]` for explicit names; `replicas`
  is ignored.
- Otherwise the module derives `<name_prefix>-1`, `<name_prefix>-2`, …
  from `var.replicas`.

The derived list is exposed via the `publisher_names` output.

## Why `for_each`, not `count`

Every downstream resource iterates `for_each = toset(local.publisher_names)`.
Removing one name from the middle of the list does not churn the others
— Terraform identifies resources by name, not by index.

`count`-based iteration would re-create resources whose index shifts;
`for_each` avoids that.

## Naming a single publisher

```hcl
module "publisher" {
  source      = "github.com/johnneerdael/terraform-netskope-publisher//modules/aws?ref=v2.0.0"
  name_prefix = "main-publisher"
  # replicas defaults to 1 → one publisher named "main-publisher-1"
  # …
}
```

For exactly `main-publisher` (no `-1` suffix), use
`names = ["main-publisher"]`.
