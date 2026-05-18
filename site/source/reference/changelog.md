---
title: Changelog
date: 2026-05-18
---

The authoritative changelog lives in the repo as
[CHANGELOG.md](https://github.com/johnneerdael/terraform-netskope-publisher/blob/main/CHANGELOG.md).

Latest releases are summarized below.

## [2.3.0] — 2026-05-19

**Script-based installation on stock Ubuntu 22.04 LTS Minimal.**
`modules/cloudinit` can now run Netskope's `bootstrap.sh` during first
boot, so the AWS / Azure / GCP submodules no longer require a pre-baked
Netskope Publisher image. New common inputs forwarded by all three
VM submodules: `bootstrap`, `bootstrap_url`, `nonat`, `install_user`,
`install_user_password` (+ `_is_hash`), `install_user_ssh_authorized_keys`,
`delete_default_user`, `guest_network_interface`. `wizard_path` is now
nullable and derives from `/home/<install_user>/npa_publisher_wizard`.

Per-platform changes:

- **GCP** defaults flipped to `bootstrap = true` and `nonat = true`
  (No-NAT mode for the 1460-byte MTU). `examples/gcp-single` defaults to
  the public Canonical Ubuntu 22.04 LTS Minimal image family.
- **AWS** auto-resolves Canonical's Ubuntu Minimal AMI (owner
  `099720109477`) under `bootstrap = true`; the Netskope AMI lookup is
  skipped in that mode so callers no longer need marketplace access.
- **Azure** defaults the marketplace reference to Canonical
  `0001-com-ubuntu-minimal-jammy / minimal-22_04-lts-gen2` under
  `bootstrap = true` (no `plan {}` block required). `admin_username`
  coalesces to `install_user` so the Azure admin and the cloud-init
  install user are always the same account.

Pre-baked-image users on AWS and Azure see no behavior change
(`bootstrap` defaults to `false` there). GCP users pinning a Netskope
image must explicitly set `bootstrap = false` and `nonat = false`.

## [2.2.0] — 2026-05-19

Kubernetes submodule (`modules/kubernetes`) installing the
[`kubernetes-netskope-publisher`](https://github.com/johnneerdael/kubernetes-netskope-publisher)
Helm chart on any K8s cluster. Two enrollment modes: `token` (Terraform
owns the publisher record, feeds it via a per-publisher Kubernetes
Secret) and `api` (chart container self-registers via the Netskope API
on Pod start). DX parity with the other submodules (`name_prefix`,
`replicas`, `names`, `publisher_names`). `examples/kubernetes-kind/`
runnable example targeting a local Kind cluster.

## [2.1.0] — 2026-05-18

Hyper-V submodule (`modules/hyperv`) cloning publishers from a
host-cached master VHDX, NoCloud seed ISO built on the host via IMAPI2
PowerShell. New `metadata_raw` output on `modules/cloudinit`.
`examples/hyperv-single/` runnable example.

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
