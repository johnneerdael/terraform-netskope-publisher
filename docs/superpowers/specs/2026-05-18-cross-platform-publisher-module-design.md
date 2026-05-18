# Cross-Platform Netskope Publisher Terraform Module — Design

**Status:** Draft — pending implementation
**Date:** 2026-05-18
**Owner:** John Neerdael
**Repository:** https://github.com/johnneerdael/terraform-netskope-publisher

## 1. Background

The existing `terraform-netskope-publisher-aws` module provisions a single AWS EC2
Netskope Publisher, creates the publisher record via the `netskope/netskope`
Terraform provider, and injects the resulting registration token either through
EC2 `user_data` or via an SSM document.

We want a single Terraform module that can provision Netskope Private Access
Publishers on multiple platforms with a consistent input/output surface, without
depending on the Netskope Terraform provider. Registration must follow the
API-driven pattern proven in `kubernetes-publisher` (`templates/configmap.yaml`):
list publishers → create if missing → generate registration token → run the
publisher wizard with that token. On a VM (vs. the container path) the wizard
binary lives at `/home/ubuntu/npa_publisher_wizard`.

## 2. Goals / non-goals

### Goals
- One module, four platforms in v1: **AWS, Azure, GCP, vSphere**.
- API-driven publisher creation and token generation via the Netskope NPA API,
  not the Netskope Terraform provider.
- Token delivered to the VM via cloud-init (`runcmd`) on every platform.
- Identical user-facing input/output shape across platforms (caller does not
  branch on `var.platform` to consume outputs).
- Multiple publishers per module call via a single `replicas` / `names` input.
- Pluggable: adding Hyper-V / Nutanix / KVM / OpenShift later is a new
  `modules/<platform>` plus an enum value, no breaking change.

### Non-goals (v1)
- Hyper-V, Nutanix, KVM (libvirt), OpenShift (KubeVirt) — deferred to v2.
- Publisher upgrade orchestration (upgrade profiles, scheduled patching).
- Multi-region / multi-tenant convenience wrappers.
- Migration tooling from the old `terraform-netskope-publisher-aws` module —
  documented manual cutover only.

## 3. Architecture

### 3.1 Repository layout

```
terraform-netskope-publisher/
├── README.md
├── LICENSE
├── versions.tf
├── variables.tf
├── main.tf
├── outputs.tf
├── modules/
│   ├── registration/         # Netskope-API → publisher_id + token (http provider)
│   ├── cloudinit/            # builds the user-data YAML per replica
│   ├── aws/                  # provider: hashicorp/aws
│   ├── azure/                # provider: hashicorp/azurerm
│   ├── gcp/                  # provider: hashicorp/google
│   └── vsphere/              # provider: vmware/vsphere
├── examples/
│   ├── aws-single/
│   ├── azure-ha-pair/
│   ├── gcp-single/
│   └── vsphere-single/
└── tests/                    # terraform test (.tftest.hcl) — mocked providers
```

### 3.2 Module shape

The root module exposes a `platform` enum and per-platform object inputs. It
calls exactly one of `modules/<platform>`, which in turn calls
`modules/registration` and `modules/cloudinit`. A consumer that only uses AWS
never instantiates `azurerm`, `google`, or `vsphere` providers because those
`required_providers` blocks live inside their respective submodules.

```hcl
module "publisher" {
  source       = "github.com/johnneerdael/terraform-netskope-publisher?ref=v0.1.0"
  platform     = "aws"
  name_prefix  = "pub-eu"
  replicas     = 2

  netskope_tenant_url = "https://tenant.goskope.com"
  netskope_api_token  = var.netskope_api_token  # sensitive

  aws = {
    subnet_id          = "subnet-…"
    security_group_ids = ["sg-…"]
    key_name           = "my-key"
    instance_type      = "t3.medium"
  }
}
```

### 3.3 Provider requirements

Declared in the root `versions.tf`:

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    http      = { source = "hashicorp/http",      version = ">= 3.4" }
    cloudinit = { source = "hashicorp/cloudinit", version = ">= 2.3" }
  }
}
```

Each platform submodule additionally declares:

| Submodule | Provider | Version |
|---|---|---|
| `modules/aws` | `hashicorp/aws` | `~> 5.0` |
| `modules/azure` | `hashicorp/azurerm` | `~> 4.0` |
| `modules/gcp` | `hashicorp/google` | `~> 6.0` |
| `modules/vsphere` | `vmware/vsphere` | `~> 2.10` |

Provider configuration is the caller's responsibility (standard Terraform
practice for child modules).

## 4. Registration flow (`modules/registration`)

Pure data-source / `http`-provider implementation. No `local-exec`, no
external scripts.

Inputs:
- `tenant_url` — string (e.g., `https://tenant.goskope.com`).
- `api_token` — string, `sensitive = true`.
- `publisher_names` — list of strings, one entry per replica.

Resource flow:

1. **List (once)** — single `data "http" "list"` →
   `GET {tenant_url}/api/v2/infrastructure/publishers` with header
   `Netskope-Api-Token: <api_token>`. `jsondecode(response_body)` and build
   `local.existing_by_name = { for p in data.list.data.publishers : p.publisher_name => p.publisher_id }`.
2. **Create-if-missing** — `data "http" "create"` with
   `for_each = { for n in var.publisher_names : n => n if !contains(keys(local.existing_by_name), n) }`,
   `method = "POST"`, `url = .../publishers`,
   `request_body = jsonencode({ publisher_name = each.key })`. Builds
   `local.created_by_name = { for n, d in data.create : n => jsondecode(d.response_body).data.publisher_id }`.
3. **Resolve** — `local.publisher_ids = { for n in var.publisher_names : n => coalesce(lookup(local.existing_by_name, n, null), lookup(local.created_by_name, n, null)) }`.
4. **Token** — `data "http" "token"` with `for_each = local.publisher_ids`,
   `method = "POST"`,
   `url = .../publishers/${each.value}/registration_token`. Token =
   `jsondecode(d.response_body).data.token`.

Outputs (map keyed by name):
```
{
  publisher_id        = string
  registration_token  = string  (sensitive)
  existed_before      = bool
}
```

Preconditions:
- `data.http.list` requires `status_code == 200` — fails fast with a clear
  message pointing at `var.netskope_api_token` / `var.netskope_tenant_url`.

Destroy behavior:
- By default the module **does not** delete the publisher record from the
  tenant on destroy (avoids cross-environment collisions, supports re-onboarding).
- Opt-in via `delete_publisher_on_destroy = true` adds a `terraform_data`
  resource with a `provisioner "local-exec" { when = destroy }` that calls
  `DELETE .../publishers/{id}`. This is the one accepted provisioner exception;
  it is documented in the README with its trade-offs.

## 5. Cloud-init (`modules/cloudinit`)

Builds one user-data document per replica using `cloudinit_config`.

Template:
```yaml
#cloud-config
hostname: ${publisher_name}
runcmd:
  - [ /home/ubuntu/npa_publisher_wizard, -token, "${registration_token}" ]
```

Outputs per name:
- `userdata_raw` — rendered string (used by GCP, which wants raw).
- `userdata_b64` — base64-encoded string (used by AWS, Azure, vSphere).
- `metadata_b64` — base64-encoded NoCloud `meta-data` containing
  `instance-id` and `local-hostname` (used by vSphere `guestinfo.metadata`).

All cloud-init outputs are marked `sensitive = true` because they embed the
registration token.

## 6. Platform submodules

Each submodule consumes the registration + cloudinit outputs and exposes a
**normalized** per-replica output. Every resource uses
`for_each = toset(local.publisher_names)` (not `count`) so adding/removing one
replica does not churn the others.

### 6.1 `modules/aws`

- **Image:** `data "aws_ami"` with `most_recent = true`, `owners = ["679593333241"]`,
  `name = "Netskope Private Access Publisher*"`. Override: `ami_id`.
- **VM:** `aws_instance` per replica, `user_data_base64 = each.value.userdata_b64`.
- **Inputs:** `subnet_id`, `security_group_ids`, `instance_type`
  (default `t3.medium`), `key_name`, `associate_public_ip_address`,
  `iam_instance_profile`, `ebs_optimized`, `monitoring`, `metadata_options`
  (default `http_tokens = "required"` — IMDSv2 enforced; no longer need the
  SSM workaround).
- The legacy `use_ssm` path is **dropped** in v1 — cloud-init handles
  registration on every platform.
- **Outputs:** map per name → `{ vm_id, private_ip, public_ip }`.

### 6.2 `modules/azure`

- **Image:** `data "azurerm_platform_image"` for the Netskope publisher
  Marketplace plan (publisher / offer / sku — exact values verified during
  implementation against the live Marketplace listing). Surfaced as
  `marketplace = { publisher, offer, sku, version }` with sensible defaults;
  override with `image_id` for custom images.
- **VM:** `azurerm_linux_virtual_machine` per replica,
  `custom_data = each.value.userdata_b64`. Includes the required `plan {}`
  block for Marketplace images.
- **Inputs:** `resource_group_name`, `location`, `subnet_id`,
  `network_security_group_id` (optional, attached at NIC level), `vm_size`
  (default `Standard_D2s_v5`), `admin_username` (default `ubuntu`),
  `admin_ssh_public_key`, `accept_marketplace_terms` (bool, drives optional
  `azurerm_marketplace_agreement`), `os_disk = { type, size_gb }`,
  `assign_public_ip`.
- **Outputs:** map per name → `{ vm_id, private_ip, public_ip }`.

### 6.3 `modules/gcp`

- **Image:** `data "google_compute_image"` against the Netskope public image
  project, selecting by `family` or most-recent. Override: `image`.
- **VM:** `google_compute_instance` per replica,
  `metadata = { "user-data" = each.value.userdata_raw }` (GCP wants raw, not
  base64). `metadata_startup_script` is explicitly **not** set so cloud-init
  drives bootstrap.
- **Inputs:** `project`, `zone`, `network`, `subnetwork`, `machine_type`
  (default `e2-medium`), `service_account = { email, scopes }`, `tags`,
  `assign_public_ip` (bool → controls `access_config {}`).
- **Outputs:** map per name → `{ vm_id, private_ip, public_ip }`.

### 6.4 `modules/vsphere`

- **Image:** template lookup via either `data "vsphere_virtual_machine"` by
  `template_name`, or `data "vsphere_content_library_item"` when the OVA lives
  in a content library. The presence of `content_library_id` switches the
  path.
- **VM:** `vsphere_virtual_machine` per replica with:
  ```hcl
  extra_config = {
    "guestinfo.userdata"          = each.value.userdata_b64
    "guestinfo.userdata.encoding" = "base64"
    "guestinfo.metadata"          = each.value.metadata_b64
    "guestinfo.metadata.encoding" = "base64"
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    # NOTE: no `customize {}` block — guestinfo cloud-init handles
    # hostname / networking instead of the open-vm-tools customize path.
  }
  ```
- **Inputs:** `datacenter`, `cluster` or `host`, `datastore` (or
  `datastore_cluster_id`), `network_id`, `template_name` **or**
  `content_library_id` + `content_library_item_name`, `num_cpus`, `memory`,
  `folder` (optional).
- **Outputs:** map per name → `{ vm_id, private_ip, public_ip }` (mapped from
  `default_ip_address` and `guest_ip_addresses[0]` respectively; `public_ip`
  is `null` on vSphere).

### 6.5 Cross-platform conventions

- **Naming:** `var.names != null ? var.names : [for i in range(var.replicas) : format("%s-%d", var.name_prefix, i + 1)]`.
- **Tags / labels:** single `tags = map(string)` input translated per platform
  (AWS tags, Azure tags, GCP labels, vSphere `custom_attributes`).
- **Default ubuntu user:** assumed (`admin_username = "ubuntu"` on Azure; the
  wizard path `/home/ubuntu/npa_publisher_wizard` reflects this).

## 7. Inputs (root)

```hcl
variable "platform"            { type = string }   # aws | azure | gcp | vsphere
variable "name_prefix"         { type = string, default = "npa-publisher" }
variable "names"               { type = list(string), default = null }
variable "replicas"            { type = number, default = 1 }
variable "tags"                { type = map(string), default = {} }

variable "netskope_tenant_url" { type = string }
variable "netskope_api_token"  { type = string, sensitive = true }
variable "delete_publisher_on_destroy" { type = bool, default = false }
variable "force_token_rotation"        { type = bool, default = false }

variable "aws"      { type = any, default = null }
variable "azure"    { type = any, default = null }
variable "gcp"      { type = any, default = null }
variable "vsphere"  { type = any, default = null }
```

Root-level validation:
- `var.platform` must be one of `aws|azure|gcp|vsphere`.
- The matching per-platform object must be non-null.
- Exactly one of `var.names` or `var.replicas >= 1`.

## 8. Outputs (root)

```hcl
output "publishers" {
  description = "Map keyed by publisher name."
  value = {
    for name, p in local.publishers : name => {
      publisher_id = p.publisher_id
      vm_id        = p.vm_id
      private_ip   = p.private_ip
      public_ip    = p.public_ip       # null when not assigned
      platform     = var.platform
    }
  }
}

output "registration_tokens" {
  description = "Map of publisher_name => registration_token."
  value       = { for n, p in local.publishers : n => p.registration_token }
  sensitive   = true
}
```

Per-submodule outputs flow up unchanged so advanced consumers can still reach
platform-specific attributes (e.g., `module.publisher.aws_instances`); only the
submodule matching `var.platform` is populated.

## 9. Error handling & idempotency

| Scenario | Behavior |
|---|---|
| Invalid / missing API token | `precondition` on `data.http.list` requires `status_code == 200`. Plan-time failure with a message pointing at `netskope_api_token`. |
| Publisher with same name already exists | List → create-if-missing pattern reuses the existing publisher; `existed_before` output is `true`. |
| Token regeneration | Token is only re-fetched when `publisher_id` changes. `force_token_rotation = true` adds a timestamp trigger to force a new token on apply. |
| Tenant API hiccup during plan | No automatic retry. User re-runs `terraform plan`. Documented limitation. |
| vSphere clone churn from stale template | `lifecycle { ignore_changes = [ovf_deploy] }` plus a `precondition` requiring the template to be powered off. |
| Azure Marketplace terms not accepted | `accept_marketplace_terms = true` creates `azurerm_marketplace_agreement`; otherwise a `precondition` errors with a remediation message. |
| State hygiene | All outputs that embed the token (`registration_tokens`, per-submodule `userdata`) are marked `sensitive = true`. |

## 10. Testing strategy

### Static
- `terraform fmt -check -recursive` and `terraform validate` per submodule in CI.
- `tflint` with AWS / Azure / GCP / vSphere rulesets per submodule.

### Unit (`.tftest.hcl`, runs in CI without cloud credentials)
- `tests/cloudinit.tftest.hcl` — render `modules/cloudinit` with a fake token;
  assert rendered user-data contains
  `/home/ubuntu/npa_publisher_wizard -token <fake>` and parses as valid YAML.
- `tests/registration.tftest.hcl` — `mock_provider "http"` returning canned
  JSON for list / create / token endpoints; assert outputs for both
  "publisher exists" and "publisher missing" code paths.
- `tests/aws_plan.tftest.hcl`, `tests/azure_plan.tftest.hcl`,
  `tests/gcp_plan.tftest.hcl`, `tests/vsphere_plan.tftest.hcl` — per platform,
  `mock_provider` for the cloud provider, `command = plan`, assert resource
  counts and that the key user-data attribute
  (`user_data_base64` / `custom_data` / `metadata["user-data"]` /
  `extra_config["guestinfo.userdata"]`) is non-empty and base64-decodes (where
  applicable) to a string containing the wizard command line.

### Integration (manual, not in CI)
- Each `examples/*` directory is a runnable example with a
  `terraform.tfvars.example`. README documents how to run against a real
  tenant + cloud account.

## 11. Versioning, release, deprecation

- **Semver.** Initial release `v0.1.0` (pre-1.0 — variable shape may shift).
  First "blessed" release with all four platforms green = `v1.0.0`.
- **Tags drive Registry publishing.** Each tagged release ships a
  `CHANGELOG.md` entry.
- **Old repo deprecation.** `terraform-netskope-publisher-aws` receives one
  final commit replacing its README with a deprecation notice that points at
  the new repo and shows a `platform = "aws"` snippet. No code archival in v1.

## 12. Rollout plan (high level)

1. Bootstrap repo (done — empty `README.md` + `main` branch already pushed).
2. Add `versions.tf`, `variables.tf`, root `main.tf` skeleton, `LICENSE`.
3. Build `modules/registration` + `tests/registration.tftest.hcl`.
4. Build `modules/cloudinit` + `tests/cloudinit.tftest.hcl`.
5. Build `modules/aws` + example + plan test. Cut `v0.1.0`.
6. Build `modules/azure` + example + plan test. Cut `v0.2.0`.
7. Build `modules/gcp` + example + plan test. Cut `v0.3.0`.
8. Build `modules/vsphere` + example + plan test. Cut `v0.4.0`.
9. README polish, full examples sweep, all integration tests green → `v1.0.0`.
10. Deprecation commit on `terraform-netskope-publisher-aws`.
