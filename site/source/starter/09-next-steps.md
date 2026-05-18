---
title: 9. Next steps
date: 2026-05-18
---

> 🎉 You have a working publisher. Where to go next?

## Run a redundant pair

Change `replicas = 1` to `replicas = 2` and `terraform apply` again. The
module creates two publishers with distinct registration tokens, both
sharing the rest of your config.

See [How-to: Provision an HA pair](/terraform-netskope-publisher/admin/how-to/ha-pair/).

## Use a different cloud

The same module deploys to Azure, GCP, or vSphere — just change
`platform = "azure"` and supply the platform input object. See the
[per-platform reference pages](/terraform-netskope-publisher/admin/module/platforms/aws/).

## Production hardening

- Move state to a remote backend ([State management](/terraform-netskope-publisher/admin/operations/state-management/)).
- Replace the long-lived API token ([Secret handling](/terraform-netskope-publisher/admin/operations/secret-handling/)).
- Scope IAM down ([Bring your own networking](/terraform-netskope-publisher/admin/how-to/byo-networking/)).

## Deeper module reference

The [Admin guides](/terraform-netskope-publisher/admin/) cover every input, every output, and the
internals of the registration flow.
