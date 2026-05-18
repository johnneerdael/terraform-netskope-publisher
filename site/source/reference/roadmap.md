---
title: Roadmap
date: 2026-05-18
---

Items deliberately deferred from v1.0.0. None of these block production
use today.

## Module features

- **`force_token_rotation` input** on each submodule — first-class flag
  for replacing registration tokens. Today: use the
  [taint-based workaround](/terraform-netskope-publisher/admin/how-to/rotate-token/).
- **`delete_publisher_on_destroy` input** on each submodule — opt-in
  deletion of the tenant publisher record when `terraform destroy`
  runs. Today: [delete manually or via API](/terraform-netskope-publisher/admin/how-to/delete-publisher/).
- **`terraform-docs` auto-generation** of per-platform input tables.
  Today: hand-maintained Markdown in `site/source/admin/module/`.

## Additional platforms

> Hyper-V shipped in v2.1.0 — see
> [Hyper-V platform inputs](/terraform-netskope-publisher/admin/module/platforms/hyperv/).

- **Nutanix AHV** via `nutanix/nutanix` (native `guest_customization.cloud_init`).
- **KVM** via `dmacvicar/libvirt` (cloud-init via NoCloud ISO).
- **OpenShift Virtualization (KubeVirt)** via the `kubernetes`
  provider's `kubevirt.io_v1_VirtualMachine` CRD.

## Site

- **In-site search** (e.g., `hexo-generator-search` + a lightweight UI).
- **Dead-link checker** in the Pages workflow (e.g., `linkinator`).
- **Versioned docs** if/when a breaking v2 of the module ships.

## Future: Go-based Terraform Provider

A standalone Go provider (`terraform-provider-netskope`) exposing
resources like `netskope_publisher`,
`netskope_publisher_registration_token`, `netskope_private_app`,
`netskope_policy_rule`, etc. would replace the module's
`http`-data-source registration flow with first-class Terraform
resources and let users `terraform plan` diffs against Netskope tenant
state. Multi-week effort; no ETA. Tracking interest via GitHub Issues.
