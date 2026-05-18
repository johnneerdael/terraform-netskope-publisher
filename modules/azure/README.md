# terraform-netskope-publisher — Azure submodule

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/azure/

Provisions Netskope Private Access Publishers on Azure.

## Usage

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/azure"
  version = "~> 2.1"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  resource_group_name  = "rg-npa"
  location             = "westeurope"
  subnet_id            = "/subscriptions/.../subnets/sn"
  admin_ssh_public_key = file("~/.ssh/id_rsa.pub")
  image_id             = "/subscriptions/.../Microsoft.Compute/images/netskope-publisher"
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
