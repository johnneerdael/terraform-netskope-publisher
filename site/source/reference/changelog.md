---
title: Changelog
date: 2026-05-18
---

The authoritative changelog lives in the repo as
[CHANGELOG.md](https://github.com/johnneerdael/terraform-netskope-publisher/blob/main/CHANGELOG.md).

Latest releases are summarized below.

## [1.0.0] — 2026-05-18

First blessed release with AWS, Azure, GCP, and vSphere all green.
README rewritten to cover the full multi-platform surface.

## [0.4.0] — 2026-05-18

vSphere submodule cloning Netskope OVA template, cloud-init via
`guestinfo`. `examples/vsphere-single`.

## [0.3.0] — 2026-05-18

GCP submodule provisioning Compute Engine publishers via
`metadata["user-data"]`. `examples/gcp-single`.

## [0.2.0] — 2026-05-18

Azure submodule provisioning `azurerm_linux_virtual_machine` with
`custom_data` cloud-init. `examples/azure-ha-pair`. Note: plan-time
tests are AWS-only; Azure/GCP/vSphere covered by `terraform validate`
plus runnable examples.

## [0.1.0] — 2026-05-18

Initial release. AWS submodule, shared `registration` + `cloudinit`
submodules, root module routing on `var.platform`, `terraform test`
unit suite with mocked providers.
