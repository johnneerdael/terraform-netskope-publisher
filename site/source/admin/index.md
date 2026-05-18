---
title: Admin Guides
date: 2026-05-18
---

Reference, how-tos, and operational guidance for Terraform-fluent operators
running `terraform-netskope-publisher` in production.

## Concepts
- [Architecture overview](/terraform-netskope-publisher/admin/concepts/architecture-overview/)
- [Registration flow](/terraform-netskope-publisher/admin/concepts/registration-flow/)
- [Naming, replicas, and for_each](/terraform-netskope-publisher/admin/concepts/naming-replicas-foreach/)

## Module reference
- [Root inputs](/terraform-netskope-publisher/admin/module/root-inputs/)
- [Root outputs](/terraform-netskope-publisher/admin/module/root-outputs/)
- Per-platform inputs:
  - [AWS](/terraform-netskope-publisher/admin/module/platforms/aws/)
  - [Azure](/terraform-netskope-publisher/admin/module/platforms/azure/)
  - [GCP](/terraform-netskope-publisher/admin/module/platforms/gcp/)
  - [vSphere](/terraform-netskope-publisher/admin/module/platforms/vsphere/)

## How-to
- [Provision an HA pair](/terraform-netskope-publisher/admin/how-to/ha-pair/)
- [Bring your own image](/terraform-netskope-publisher/admin/how-to/byo-image/)
- [Rotate the registration token](/terraform-netskope-publisher/admin/how-to/rotate-token/)
- [Delete a publisher cleanly](/terraform-netskope-publisher/admin/how-to/delete-publisher/)
- [Multi-region deployments](/terraform-netskope-publisher/admin/how-to/multi-region/)
- [Bring your own networking](/terraform-netskope-publisher/admin/how-to/byo-networking/)

## Operations
- [State management](/terraform-netskope-publisher/admin/operations/state-management/)
- [Secret handling](/terraform-netskope-publisher/admin/operations/secret-handling/)
- [Upgrading publisher software](/terraform-netskope-publisher/admin/operations/upgrading-software/)
- [Troubleshooting](/terraform-netskope-publisher/admin/operations/troubleshooting/)
