---
title: Bring your own image
date: 2026-05-18
toc: true
---

## Two install modes (v2.3+)

`modules/aws`, `modules/azure`, and `modules/gcp` each support two ways
of getting the Publisher onto the VM:

| Mode | Toggle | Image | Wizard install |
|---|---|---|---|
| **Bootstrap** | `bootstrap = true` | Stock Canonical Ubuntu 22.04 LTS Minimal — auto-resolved per platform | Cloud-init `curl … bootstrap.sh \| sudo bash` |
| **Pre-baked** | `bootstrap = false` | Netskope Publisher AMI / marketplace image / GCE image, or your own custom image | Already on disk |

`bootstrap` defaults to:

- `true` on `modules/gcp` (with `nonat = true` for the 1460-byte MTU)
- `false` on `modules/aws` and `modules/azure` (backward-compatible)

`vsphere` and `hyperv` always use a pre-supplied image / template (no
bootstrap path today). `kubernetes` ships the wizard in the Helm chart's
container image.

## Bootstrap mode (stock Canonical Ubuntu)

Use this when you don't want to subscribe to Netskope's marketplace
image, or when you want to customise the install user, password, SSH
keys, or netplan from Terraform.

### Auto-resolved images per platform

| Platform | Image resolved when `bootstrap = true` |
|---|---|
| AWS | Most-recent AMI matching owner `099720109477` (Canonical), name `ubuntu-minimal/images/hvm-ssd*/ubuntu-jammy-22.04-amd64-minimal-*`, x86_64, hvm |
| Azure | Marketplace reference `Canonical / 0001-com-ubuntu-minimal-jammy / minimal-22_04-lts-gen2 / latest` (no `plan {}` required) |
| GCP | `projects/ubuntu-os-cloud/global/images/family/ubuntu-minimal-2204-lts` (set explicitly on `examples/gcp-single`) |

### AWS bootstrap example

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.3"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = var.subnet_id
  security_group_ids = [var.security_group_id]
  key_name           = var.key_name

  bootstrap = true
}
```

`ami_id` is still respected when explicitly set — passing both
`bootstrap = true` and `ami_id = "ami-..."` boots your AMI and still runs
the bootstrap script. Use that to lock to a specific Ubuntu AMI version
rather than `most_recent`.

### Azure bootstrap example

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/azure"
  version = "~> 2.3"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  resource_group_name  = "rg-npa"
  location             = "westeurope"
  subnet_id            = "/subscriptions/.../subnets/sn"
  admin_ssh_public_key = file("~/.ssh/id_rsa.pub")

  bootstrap = true
}
```

`admin_username` defaults to `null` in v2.3 and coalesces to
`install_user`, so the Azure admin account and the cloud-init install
user are always the same. The `admin_ssh_key` block on the VM resource
targets the same username.

### GCP bootstrap example (default)

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
  # bootstrap / nonat / Ubuntu Minimal family — all defaults
}
```

### Air-gapped or mirrored bootstrap

Override `bootstrap_url` if the VM can't reach Netskope's public S3
bucket directly:

```hcl
bootstrap_url = "https://artifacts.internal.example.com/netskope/publisher/bootstrap.sh"
```

The script must produce a working `npa_publisher_wizard` at
`/home/<install_user>/npa_publisher_wizard` (or whatever you set
`wizard_path` to).

## Pre-baked image mode (legacy / custom)

This is the v2.2 behaviour and remains the default on AWS and Azure.
Pass an image identifier and leave `bootstrap = false`:

| Platform | Input | What to pass |
|---|---|---|
| AWS | `aws.ami_id` | `"ami-..."` (Netskope's AMI or your own) |
| Azure | `azure.image_id` or `azure.marketplace` | Full image resource ID, or marketplace publisher/offer/sku |
| GCP | `gcp.image` | `projects/.../global/images/...` |
| vSphere | `vsphere.template_name` | Template VM name |
| Hyper-V | `hyperv.master_vhdx_*` | URL/path to the master VHDX |

Example (AWS, custom AMI):

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.3"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = var.subnet_id
  security_group_ids = [var.security_group_id]
  key_name           = var.key_name

  bootstrap = false
  ami_id    = "ami-0123456789abcdef0"
}
```

### Requirements for a pre-baked image

- Ships `npa_publisher_wizard` at `wizard_path` (default
  `/home/<install_user>/npa_publisher_wizard`, which is
  `/home/ubuntu/npa_publisher_wizard` when `install_user` is left at its
  default).
- Has a cloud-init that runs `runcmd` from the rendered user-data.
- The user named by `install_user` already exists (or `delete_default_user`
  must be `false` if you want to keep the image's default user).

## Choosing between the two

- **Pick bootstrap mode** if you want to avoid marketplace subscriptions,
  customise the install user / password / SSH keys / netplan from
  Terraform, or pin to a specific Ubuntu version.
- **Pick pre-baked mode** if you want the fastest first boot (no apt
  install during cloud-init), or if a custom-baked image is already part
  of your golden-image pipeline.
