# terraform-netskope-publisher — AWS submodule

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/aws/

Provisions Netskope Private Access Publishers on AWS.

## Usage (default — pre-baked Netskope AMI)

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.3"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = "subnet-..."
  security_group_ids = ["sg-..."]
  key_name           = "my-key"
}
```

`bootstrap` defaults to `false`, so the module looks up the latest
`Netskope Private Access Publisher*` AMI (owner `679593333241`) and the
wizard registers from the image. No behavior change vs. v2.2.

## Bootstrap mode — stock Canonical Ubuntu 22.04 LTS Minimal (v2.3+)

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.3"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = "subnet-..."
  security_group_ids = ["sg-..."]
  key_name           = "my-key"

  bootstrap = true
}
```

With `bootstrap = true` and `ami_id = null`, the module skips the Netskope
AMI lookup entirely and auto-resolves the latest Canonical AMI:

| Filter | Value |
|---|---|
| owners | `099720109477` (Canonical) |
| name | `ubuntu-minimal/images/hvm-ssd*/ubuntu-jammy-22.04-amd64-minimal-*` |
| architecture | `x86_64` |
| virtualization-type | `hvm` |

Cloud-init then runs Netskope's `bootstrap.sh` and registers using the
token returned by the Netskope API. Callers do **not** need access to
the Netskope marketplace listing in bootstrap mode.

`ami_id` still wins when explicitly set, regardless of `bootstrap`.

## Customise the install user / SSH / network

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.3"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = "subnet-..."
  security_group_ids = ["sg-..."]

  bootstrap                        = true
  install_user                     = "npa"
  install_user_password            = var.npa_password # sensitive
  install_user_ssh_authorized_keys = [file("~/.ssh/id_ed25519.pub")]

  guest_network_interface = {
    name      = "ens5"
    dhcp4     = false
    addresses = ["10.0.0.5/24"]
    gateway4  = "10.0.0.1"
    mtu       = 9001
  }
}
```

When `install_user` differs from `ubuntu`, cloud-init removes the image's
default `ubuntu` account during first boot (override with
`delete_default_user = false`). `wizard_path` follows the install user's
home (`/home/<install_user>/npa_publisher_wizard` when null).

See the [common inputs](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/common-inputs/)
and the [AWS reference](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/aws/)
for the full input table and examples.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.7 |
| hashicorp/aws | ~> 5.0 |
| hashicorp/http | >= 3.4 |
| hashicorp/cloudinit | >= 2.3 |
