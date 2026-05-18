# terraform-netskope-publisher — Azure submodule

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/azure/

Provisions Netskope Private Access Publishers on Azure.

## Usage (default — pre-baked image)

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
  image_id             = "/subscriptions/.../Microsoft.Compute/images/netskope-publisher"
}
```

`bootstrap` defaults to `false`, so you provide a pre-baked image (via
`image_id` or `marketplace`) and the wizard registers from the image
itself. No behavior change vs. v2.2.

## Bootstrap mode — Canonical Ubuntu 22.04 LTS Minimal marketplace image (v2.3+)

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

With `bootstrap = true` and neither `image_id` nor `marketplace` set, the
module defaults the marketplace reference to:

| Field | Value |
|---|---|
| publisher | `Canonical` |
| offer | `0001-com-ubuntu-minimal-jammy` |
| sku | `minimal-22_04-lts-gen2` |
| version | `latest` |

No `plan {}` block is emitted — Canonical's Ubuntu images don't require
marketplace-terms acceptance. Cloud-init then runs Netskope's
`bootstrap.sh` and registers via the API token.

## Install user / Azure admin alignment

In v2.3 `admin_username` defaults to `null` and **coalesces to
`install_user`**, so the Azure admin user and the cloud-init install user
are always the same account. The `admin_ssh_key` block targets the same
user. Override `admin_username` only if you want them to differ
deliberately.

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/azure"
  version = "~> 2.3"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  resource_group_name  = "rg-npa"
  location             = "westeurope"
  subnet_id            = "/subscriptions/.../subnets/sn"
  admin_ssh_public_key = file("~/.ssh/id_ed25519.pub")

  bootstrap                        = true
  install_user                     = "npa"
  install_user_password            = var.npa_password # sensitive
  install_user_ssh_authorized_keys = [file("~/.ssh/team_ed25519.pub")]
}
```

See the [common inputs](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/common-inputs/)
and the [Azure reference](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/azure/)
for the full input table and examples.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.7 |
| hashicorp/azurerm | ~> 4.0 |
| hashicorp/http | >= 3.4 |
| hashicorp/cloudinit | >= 2.3 |
