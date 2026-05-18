---
title: 9. Next steps
date: 2026-05-18
---

> 🎉 You have a working publisher. Where to go next?

## Run a redundant pair

Change `replicas = 1` to `replicas = 2` and `terraform apply` again. The
module creates `my-first-publisher-1` and `my-first-publisher-2`, each
registered with its own token and provisioned on its own EC2 instance.

See [How-to: Provision an HA pair](/terraform-netskope-publisher/admin/how-to/ha-pair/).

## Use a different cloud

The same project ships submodules for Azure, GCP, and vSphere. Source
`//modules/azure`, `//modules/gcp`, or `//modules/vsphere` instead of
`//modules/aws`, and pass that platform's inputs. See the
[per-platform reference pages](/terraform-netskope-publisher/admin/module/platforms/aws/).

## Production hardening

- Move state to a remote backend ([State management](/terraform-netskope-publisher/admin/operations/state-management/)).
- Replace the long-lived API token ([Secret handling](/terraform-netskope-publisher/admin/operations/secret-handling/)).
- Scope IAM down ([Bring your own networking](/terraform-netskope-publisher/admin/how-to/byo-networking/)).

## Deeper module reference

The [Admin guides](/terraform-netskope-publisher/admin/) cover every input, every output, and the
internals of the registration flow.
