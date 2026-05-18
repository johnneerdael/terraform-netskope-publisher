[![Terraform Registry](https://img.shields.io/badge/terraform-registry-blueviolet)](https://registry.terraform.io/modules/johnneerdael/publisher/netskope)

# terraform-netskope-publisher

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/
> — starter walkthrough for first-time Terraform users + complete admin
> reference for AWS / Azure / GCP / vSphere.

Provision Netskope Private Access Publishers on **AWS**, **Azure**, **GCP**,
**vSphere**, **Hyper-V**, or **Kubernetes** via the Netskope NPA API,
cloud-init (VM platforms), or Helm (Kubernetes).

## Quick start

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.3"

  name_prefix = "pub-eu"
  replicas    = 2

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = "subnet-…"
  security_group_ids = ["sg-…"]
  key_name           = "my-key"

  # v2.3: boot a stock Canonical Ubuntu 22.04 LTS Minimal AMI and install
  # the Publisher via Netskope's bootstrap.sh during cloud-init. Drop this
  # line (or set bootstrap = false) to keep using a pre-baked Netskope AMI.
  bootstrap = true
}
```

For other platforms, source the matching submodule:
`//modules/azure`, `//modules/gcp`, `//modules/vsphere`, `//modules/hyperv`,
`//modules/kubernetes`.

## Two install paths (v2.3+)

Each VM submodule (`aws`, `azure`, `gcp`) supports two ways of getting the
Publisher onto the box:

| Mode | Image | When to pick it |
|---|---|---|
| **Bootstrap** (`bootstrap = true`) | Stock Canonical Ubuntu 22.04 LTS Minimal — auto-resolved per platform | No marketplace subscription needed; lets you customise the install user, password, SSH keys, and netplan interface in cloud-init |
| **Pre-baked image** (`bootstrap = false`, default on AWS/Azure) | Netskope Publisher AMI / marketplace image / GCP image | Fastest first boot; image is already validated and signed by Netskope |

GCP defaults to `bootstrap = true` and `nonat = true` (the 1460-byte MTU
makes No-NAT mode the recommended setup). AWS and Azure default to
`bootstrap = false` so existing deployments keep working unchanged.

## Install via the Terraform Registry

This module is published at
[registry.terraform.io/modules/johnneerdael/publisher/netskope](https://registry.terraform.io/modules/johnneerdael/publisher/netskope).

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.3"
  # ...
}
```

Substitute `//modules/aws` with `//modules/azure`, `//modules/gcp`,
`//modules/vsphere`, or `//modules/hyperv` for other platforms. The
GitHub source URL also keeps working.

## Why per-platform submodules

Each submodule declares only the providers it needs. Sourcing
`//modules/aws` pulls in `aws`, `http`, `cloudinit` — nothing else. The
v1 root module that routed on a `platform` variable forced consumers to
configure all four cloud providers, which was a usability bug. v2
removes it.

## Inputs (common to every VM submodule)

### Identity / sizing

| Name | Type | Default | Description |
|---|---|---|---|
| `name_prefix` | string | `"npa-publisher"` | Used to derive names when `names` is null |
| `names` | list(string) | `null` | Explicit publisher names; overrides `name_prefix` + `replicas` |
| `replicas` | number | `1` | Number of publishers to derive |
| `tags` | map(string) | `{}` | Tags / labels per platform |
| `tenant_url` | string | — | e.g. `https://tenant.goskope.com` |
| `api_token` | string (sensitive) | — | NPA API token |

### Cloud-init / bootstrap (v2.3+)

| Name | Type | Default | Description |
|---|---|---|---|
| `bootstrap` | bool | `true` on GCP, `false` on AWS/Azure | Run Netskope's generic `bootstrap.sh` during cloud-init on a stock Ubuntu image. Set to `false` to use a pre-baked Netskope Publisher image. |
| `bootstrap_url` | string | Netskope public S3 URL | Override the bootstrap script URL (private mirror, air-gap, etc.). |
| `nonat` | bool | `true` on GCP, `false` on AWS/Azure | Create `~install_user/resources/.nonat` to enable Netskope's No-NAT mode (recommended on GCP because of the 1460-byte MTU). |
| `wizard_path` | string | `null` → `/home/<install_user>/npa_publisher_wizard` | Absolute path to `npa_publisher_wizard` on the VM. Leave null to derive from `install_user`. |
| `install_user` | string | `"ubuntu"` | Linux user that owns the Publisher install. When different from `"ubuntu"`, **replaces** the image's default `ubuntu` user (it is removed by cloud-init when `delete_default_user = true`). |
| `install_user_password` | string (sensitive) | `null` | Optional password for `install_user`. Null = SSH-key-only login. |
| `install_user_password_is_hash` | bool | `false` | `true` if `install_user_password` is already a `crypt(3)` hash. |
| `install_user_ssh_authorized_keys` | list(string) | `[]` | Public keys installed in `~install_user/.ssh/authorized_keys`. |
| `delete_default_user` | bool | `true` | When `install_user != "ubuntu"`, cloud-init removes the original `ubuntu` account (`userdel -r ubuntu`). Set false to keep both. |
| `guest_network_interface` | object | `null` | Optional netplan override for the primary OS interface. Fields: `name`, `dhcp4`, `addresses`, `gateway4`, `nameservers`, `mtu`. Null leaves the image's DHCP setup alone. |

Platform-specific inputs (subnets, image refs, instance sizes, etc.) are
documented in each submodule's `variables.tf` and on the docs site.

## Outputs

```hcl
output "publishers" {
  # Map: name => { publisher_id, vm_id, private_ip, public_ip, registration_token }
  # sensitive (registration_token is inside)
}
output "publisher_names" {
  # The derived list of names (useful when you used name_prefix+replicas)
}
```

## Migration from v1.x

| v1.x (root module) | v2.0.0 (submodule) |
|---|---|
| `source = "...?ref=v1.x"` + `platform = "aws"` | `source = "...//modules/aws?ref=v2.0.0"` |
| `netskope_tenant_url = ...` | `tenant_url = ...` |
| `netskope_api_token = ...` | `api_token = ...` |
| `aws = { subnet_id = …, security_group_ids = … }` | `subnet_id = …`, `security_group_ids = …` (flat) |

## Requirements

- Terraform >= 1.7
- `hashicorp/http >= 3.4` (POST support)
- `hashicorp/cloudinit >= 2.3`
- Per-platform: `aws ~> 5.0`, `azurerm ~> 4.0`, `google ~> 6.0`, `vsphere ~> 2.10`

## Testing

```bash
terraform init -backend=false
terraform test
```

## License

Apache-2.0. See [LICENSE](LICENSE).
