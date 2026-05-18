# terraform-netskope-publisher — GCP submodule

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/gcp/

Provisions Netskope Private Access Publishers on GCP.

## Usage

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/gcp"
  version = "~> 2.1"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  project    = "my-gcp-project"
  zone       = "europe-west4-a"
  network    = "default"
  subnetwork = "default"
  image      = "projects/my-gcp-project/global/images/netskope-publisher"
}
```

See the [common inputs](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/common-inputs/)
and the [GCP reference](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/gcp/)
for the full input table and examples.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.7 |
| hashicorp/google | ~> 6.0 |
| hashicorp/http | >= 3.4 |
| hashicorp/cloudinit | >= 2.3 |
