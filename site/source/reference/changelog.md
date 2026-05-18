---
title: Changelog
date: 2026-05-18
---

The authoritative changelog lives in the repo as
[CHANGELOG.md](https://github.com/johnneerdael/terraform-netskope-publisher/blob/main/CHANGELOG.md).

Latest releases are summarized below.

## [2.0.0] — 2026-05-18

**Breaking.** The multi-platform root module is removed. Source
per-platform submodules instead:
`github.com/johnneerdael/terraform-netskope-publisher//modules/<platform>?ref=v2.0.0`.
Each submodule gains `name_prefix`/`replicas`/`names` inputs (parity
with v1 root ergonomics) and a `publisher_names` output. Input renames:
`netskope_tenant_url` → `tenant_url`; `netskope_api_token` → `api_token`;
nested `aws = { … }` flattens to top-level `subnet_id` etc.

## [1.1.1] — 2026-05-18

Fixed `modules/registration` POST body field name (`publisher_name` →
`name`) and create response parser (`data.publisher_id` → `data.id`).
The NPA API rejected the old field name with
`{"message":"'name'","status":"error"}`. Starter Guide pointed at
`//modules/aws` directly so the cross-provider config leak no longer
trips first-time users.

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
