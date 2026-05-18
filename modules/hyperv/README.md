# terraform-netskope-publisher — Hyper-V submodule

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/hyperv/

Provisions Netskope Private Access Publishers on Microsoft Hyper-V.

## Usage

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/hyperv"
  version = "~> 2.1"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  vswitch_name = "External vSwitch"

  hyperv_winrm_config = {
    host     = "hyperv01.lab.local"
    user     = "Administrator"
    password = var.hyperv_password
  }
}
```

See the [common inputs](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/common-inputs/)
and the [Hyper-V reference](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/hyperv/)
for the full input table and examples.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.7 |
| taliesins/hyperv | ~> 1.2 |
| hashicorp/http | >= 3.4 |
| hashicorp/cloudinit | >= 2.3 |
