---
title: Common outputs
date: 2026-05-18
toc: true
---

Outputs emitted by every platform submodule.

## `publishers`

```hcl
output "publishers" {
  # Map keyed by publisher name
  # sensitive = true (contains registration_token transitively)
}
```

Per publisher name:

| Field | Type | Description |
|---|---|---|
| `publisher_id` | number | Netskope publisher ID. |
| `vm_id` | string | Platform-native VM identifier. |
| `private_ip` | string | Primary private IPv4 address. |
| `public_ip` | string \| null | Public IPv4 if requested; `null` on platforms where it wasn't (always `null` on vSphere). |
| `registration_token` | string (sensitive) | The token cloud-init consumed. |

## `publisher_names`

```hcl
output "publisher_names" {
  # list(string) of the derived names
}
```

Handy when you used `name_prefix` + `replicas` and want to know what the
module actually created.

## Platform-specific outputs

Each submodule emits a few additional outputs useful for tests or
integration. See the per-platform pages.

## Sensitivity model

`publishers` is sensitive because the per-name struct embeds
`registration_token`. To re-emit at your caller, also mark your output
sensitive — or destructure and `nonsensitive()` the non-token fields
explicitly.
