---
title: GCP platform inputs
date: 2026-05-18
toc: true
---

> ⚠️ The publisher VM needs outbound TCP/443. See
> [Connectivity requirements → GCP](/terraform-netskope-publisher/admin/concepts/connectivity/)
> for the supported shapes (`assign_public_ip = true`, or a Cloud NAT
> on the subnet's region+VPC). Misconfiguring this is the single most
> common cause of "publisher never goes Online".

## v2.3 defaults

`modules/gcp` defaults to **bootstrap mode** on a stock Canonical Ubuntu
22.04 LTS Minimal image, with No-NAT mode enabled (1460-byte MTU):

| Input | Default | Effect |
|---|---|---|
| `bootstrap` | `true` | Cloud-init downloads and runs Netskope's `bootstrap.sh`, then registers. |
| `nonat` | `true` | Cloud-init drops `~install_user/resources/.nonat` so the Publisher starts in No-NAT mode. |
| `image` (in `examples/gcp-single`) | `projects/ubuntu-os-cloud/global/images/family/ubuntu-minimal-2204-lts` | Public Canonical image family. |

To boot a pre-baked Netskope Publisher image instead, set `bootstrap = false`
and `nonat = false`, and pass `image` pointing at the Netskope image.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project` | string | required | GCP project ID. |
| `zone` | string | required | Compute Engine zone. |
| `network` | string | `"default"` | VPC network. |
| `subnetwork` | string | `"default"` | Subnetwork in the VPC. |
| `machine_type` | string | `"e2-medium"` | Machine type. |
| `image` | string | required | Image self-link, e.g. `projects/PROJECT/global/images/IMAGE` or a `.../family/ubuntu-minimal-2204-lts` family. |
| `assign_public_ip` | bool | `false` | Add an `access_config {}` for external IPv4. |
| `network_tags` | list(string) | `[]` | GCP network tags (firewall targeting). |
| `service_account.email` | string | required if `service_account` set | Service account email. |
| `service_account.scopes` | list(string) | `["https://www.googleapis.com/auth/cloud-platform"]` | OAuth scopes. |

See [Common inputs](/terraform-netskope-publisher/admin/module/common-inputs/)
for `bootstrap`, `nonat`, `install_user`, `install_user_password`,
`install_user_ssh_authorized_keys`, `delete_default_user`,
`guest_network_interface`, and `wizard_path` (all v2.3+).

## Minimal example (bootstrap default)

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/gcp"
  version = "~> 2.3"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  project    = "my-gcp-project"
  zone       = "europe-west4-a"
  network    = "default"
  subnetwork = "default"
  image      = "projects/ubuntu-os-cloud/global/images/family/ubuntu-minimal-2204-lts"
}
```

## Pre-baked Netskope image example

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/gcp"
  version = "~> 2.3"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  project    = "my-gcp-project"
  zone       = "europe-west4-a"
  network    = "default"
  subnetwork = "default"
  image      = "projects/my-gcp-project/global/images/netskope-publisher"

  bootstrap = false
  nonat     = false
}
```

## Custom install user + static IP example

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/gcp"
  version = "~> 2.3"

  name_prefix = "pub-gcp"
  replicas    = 2

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  project    = "my-gcp-project"
  zone       = "europe-west4-a"
  network    = "vpc-prod"
  subnetwork = "vpc-prod-eu"

  install_user                     = "npa"
  install_user_password            = var.npa_password # sensitive
  install_user_ssh_authorized_keys = [file("~/.ssh/team_ed25519.pub")]

  guest_network_interface = {
    name        = "ens4"
    dhcp4       = false
    addresses   = ["10.0.0.5/24"]
    gateway4    = "10.0.0.1"
    nameservers = ["8.8.8.8", "1.1.1.1"]
    mtu         = 1460
  }
}
```

When `install_user` differs from `ubuntu`, cloud-init removes the
image's default `ubuntu` account during first boot (override with
`delete_default_user = false`).

## Platform-specific outputs

| Output | Type | Description |
|---|---|---|
| `instance_ids` | list(string) | Compute instance IDs. |
| `user_data_by_name` | map(string) (sensitive) | Raw cloud-init per VM. |

## Caveats

- `google` provider authenticates at configure time. Use ADC, a service
  account key file, or `GOOGLE_APPLICATION_CREDENTIALS`.
- `metadata_startup_script` is intentionally NOT set — the module uses
  cloud-init via `metadata["user-data"]` for bootstrap consistency
  across clouds.
- `bootstrap.sh` requires outbound TCP/443 to
  `s3-us-west-2.amazonaws.com` *during cloud-init* (in addition to the
  Netskope tenant URL). Override `bootstrap_url` to point at a private
  mirror for air-gapped projects.
