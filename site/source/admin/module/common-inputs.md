---
title: Common inputs
date: 2026-05-18
toc: true
---

Inputs accepted by every platform submodule. Platform-specific inputs
are documented on the per-platform pages
([AWS](/terraform-netskope-publisher/admin/module/platforms/aws/),
[Azure](/terraform-netskope-publisher/admin/module/platforms/azure/),
[GCP](/terraform-netskope-publisher/admin/module/platforms/gcp/),
[vSphere](/terraform-netskope-publisher/admin/module/platforms/vsphere/)).

## Required

| Name | Type | Description |
|---|---|---|
| `tenant_url` | string | Netskope tenant URL, e.g. `https://tenant.goskope.com`. Must start with `https://`. |
| `api_token` | string (sensitive) | NPA API token with publisher read/write scope. |

## Optional — identity / sizing

| Name | Type | Default | Description |
|---|---|---|---|
| `name_prefix` | string | `"npa-publisher"` | Used to derive names when `names` is null. |
| `names` | list(string) | `null` | Explicit publisher names. When set, overrides `name_prefix` + `replicas`. |
| `replicas` | number | `1` | Number of publishers to derive from `name_prefix`. |
| `tags` | map(string) | `{}` | Tags / labels applied per platform. |

## Optional — cloud-init / bootstrap (v2.3+)

Inputs accepted by `modules/aws`, `modules/azure`, and `modules/gcp`.
`modules/vsphere` and `modules/hyperv` still wire through `wizard_path`
but do not currently support the bootstrap-on-stock-image path
(track in [Roadmap](/terraform-netskope-publisher/reference/roadmap/)).
`modules/kubernetes` ignores these — the chart's container image already
has the wizard.

| Name | Type | Default | Description |
|---|---|---|---|
| `wizard_path` | string | `null` → `/home/<install_user>/npa_publisher_wizard` | Absolute path to the wizard binary on the VM. Leave null to derive from `install_user`. |
| `bootstrap` | bool | `true` on GCP, `false` on AWS/Azure | Run Netskope's generic `bootstrap.sh` during cloud-init on a stock Ubuntu image. Set false to use a pre-baked Netskope Publisher image. |
| `bootstrap_url` | string | `https://s3-us-west-2.amazonaws.com/publisher.netskope.com/latest/generic/bootstrap.sh` | Override for air-gapped or mirrored deployments. |
| `nonat` | bool | `true` on GCP, `false` on AWS/Azure | Create `~install_user/resources/.nonat` to enable Netskope's No-NAT mode. Recommended on GCP because of the 1460-byte MTU. |
| `install_user` | string | `"ubuntu"` | Linux user that owns the Publisher install (`~/resources`, `~/npa_publisher_wizard`). When different from `"ubuntu"`, **replaces** the image's default `ubuntu` user (see `delete_default_user`). |
| `install_user_password` | string (sensitive) | `null` | Optional password for `install_user`. Null = SSH-key-only login (`lock_passwd: true`). |
| `install_user_password_is_hash` | bool | `false` | Set true if `install_user_password` is already a `crypt(3)` hash (e.g. produced by `mkpasswd -m sha-512`). |
| `install_user_ssh_authorized_keys` | list(string) | `[]` | Public SSH keys installed in `~install_user/.ssh/authorized_keys`. On Azure these are **in addition to** `admin_ssh_public_key` (which Azure injects natively). |
| `delete_default_user` | bool | `true` | When `install_user != "ubuntu"`, cloud-init runs `userdel -r ubuntu` so the new user becomes the only login. Set false to keep both accounts. |
| `guest_network_interface` | object | `null` | Optional primary-interface override emitted as a netplan config at `/etc/netplan/60-cloudinit-override.yaml`. Fields: `name`, `dhcp4`, `addresses`, `gateway4`, `nameservers`, `mtu`. Null leaves the image's DHCP setup unchanged. See [BYO networking](/terraform-netskope-publisher/admin/how-to/byo-networking/) for details. |

### Bootstrap mode auto-resolves a stock image

When `bootstrap = true` and the platform-specific image input is null,
the module picks up a stock Canonical Ubuntu 22.04 LTS Minimal image:

| Platform | Image resolved |
|---|---|
| AWS | Latest Canonical AMI (owner `099720109477`, name `ubuntu-minimal/images/hvm-ssd*/ubuntu-jammy-22.04-amd64-minimal-*`). The Netskope Publisher AMI lookup is skipped. |
| Azure | Marketplace `Canonical / 0001-com-ubuntu-minimal-jammy / minimal-22_04-lts-gen2 / latest`. No `plan {}` block required. |
| GCP | `projects/ubuntu-os-cloud/global/images/family/ubuntu-minimal-2204-lts` (set explicitly on `examples/gcp-single`). |

Pass `aws.ami_id` / `azure.image_id` / `azure.marketplace` / `gcp.image`
to pin a specific image even when `bootstrap = true`.

## Naming derivation

```hcl
local.publisher_names = var.names != null
  ? var.names
  : [for i in range(var.replicas) : format("%s-%d", var.name_prefix, i + 1)]
```

If you set `names`, `name_prefix` and `replicas` are ignored.
