# terraform-netskope-publisher — AWS submodule

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/aws/

Provisions Netskope Private Access Publishers on AWS.

## Usage

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.1"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = "subnet-..."
  security_group_ids = ["sg-..."]
  key_name           = "my-key"
}
```

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
