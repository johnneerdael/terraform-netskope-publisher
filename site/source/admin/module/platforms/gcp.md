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

## Inputs

The `gcp = { ... }` object accepts:

| Name | Type | Default | Description |
|---|---|---|---|
| `project` | string | required | GCP project ID. |
| `zone` | string | required | Compute Engine zone. |
| `network` | string | `"default"` | VPC network. |
| `subnetwork` | string | `"default"` | Subnetwork in the VPC. |
| `machine_type` | string | `"e2-medium"` | Machine type. |
| `image` | string | required | Image self-link, e.g. `projects/PROJECT/global/images/IMAGE`. |
| `assign_public_ip` | bool | `false` | Add an `access_config {}` for external IPv4. |
| `network_tags` | list(string) | `[]` | GCP network tags (firewall targeting). |
| `service_account.email` | string | required if `service_account` set | Service account email. |
| `service_account.scopes` | list(string) | `["https://www.googleapis.com/auth/cloud-platform"]` | OAuth scopes. |

## Minimal example

```hcl
module "publisher" {
  source = "github.com/johnneerdael/terraform-netskope-publisher//modules/gcp?ref=v2.0.0"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  project    = "my-gcp-project"
  zone       = "europe-west4-a"
  network    = "default"
  subnetwork = "default"
  image      = "projects/my-gcp-project/global/images/netskope-publisher"
}
```

## Full example

```hcl
module "publisher" {
  source = "github.com/johnneerdael/terraform-netskope-publisher//modules/gcp?ref=v2.0.0"

  name_prefix = "pub-gcp"
  replicas    = 2

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  project          = "my-gcp-project"
  zone             = "europe-west4-a"
  network          = "vpc-prod"
  subnetwork       = "vpc-prod-eu"
  machine_type     = "e2-standard-2"
  image            = "projects/my-gcp-project/global/images/netskope-publisher-2026"
  assign_public_ip = false
  network_tags     = ["npa-publisher"]
  service_account = {
    email  = "npa-publisher@my-gcp-project.iam.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}
```

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
