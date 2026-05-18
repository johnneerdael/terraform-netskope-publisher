---
title: Root outputs
date: 2026-05-18
toc: true
---

## `publishers`

```hcl
output "publishers" {
  # Map keyed by publisher name
  # sensitive = true (the map contains registration_token transitively)
}
```

Per publisher name, the value is:

| Field | Type | Description |
|---|---|---|
| `publisher_id` | number | Netskope publisher ID. |
| `vm_id` | string | Platform-native VM identifier (instance ID / VM resource ID / instance ID / VM UUID). |
| `private_ip` | string | Primary private IPv4 address. |
| `public_ip` | string \| null | Public IPv4 if requested; `null` on platforms where it wasn't (always `null` on vSphere). |
| `platform` | string | Echoes `var.platform`. |

## `registration_tokens`

```hcl
output "registration_tokens" {
  # Map: publisher_name => token (string, sensitive)
}
```

Useful if you need to re-run the publisher wizard manually. Treat the
token like a password.

## Sensitivity model

Both root outputs are marked `sensitive = true` because they embed
registration tokens (directly in `registration_tokens`, transitively in
`publishers.<name>.registration_token` returned by the underlying
submodule). To consume in your own outputs you must also mark them
sensitive, or use `nonsensitive()` after explicitly redacting tokens.

## Reaching platform-specific attributes

The matching submodule exposes additional attributes (e.g.,
`aws_instance_ids`, `vm_uuids`, `user_data_by_name`). Access them via
`module.publisher.aws[0].<output>` etc. Only the submodule matching
`var.platform` is populated.
