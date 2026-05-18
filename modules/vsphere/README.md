# terraform-netskope-publisher — vSphere submodule

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/vsphere/

Provisions Netskope Private Access Publishers on VMware vSphere.

## Usage

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/vsphere"
  version = "~> 2.1"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  datacenter    = "dc1"
  cluster       = "cluster1"
  datastore     = "ds1"
  network_name  = "vm-net"
  template_name = "netskope-publisher-template"
}
```

See the [common inputs](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/common-inputs/)
and the [vSphere reference](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/vsphere/)
for the full input table and examples.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.7 |
| vmware/vsphere | ~> 2.10 |
| hashicorp/http | >= 3.4 |
| hashicorp/cloudinit | >= 2.3 |
