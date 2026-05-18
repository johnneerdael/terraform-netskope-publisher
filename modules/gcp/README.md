# terraform-netskope-publisher — GCP submodule

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/gcp/

Provisions Netskope Private Access Publishers on GCP.

## Usage (v2.3+ default — stock Ubuntu via bootstrap)

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

  # Defaults baked in:
  #   image     = "projects/ubuntu-os-cloud/global/images/family/ubuntu-minimal-2204-lts"
  #   bootstrap = true   # cloud-init runs Netskope's bootstrap.sh on first boot
  #   nonat     = true   # ~ubuntu/resources/.nonat — recommended on GCP (1460 MTU)
}
```

## Pre-baked Netskope Publisher image (legacy)

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
  image      = "projects/my-gcp-project/global/images/netskope-publisher"

  bootstrap = false
  nonat     = false
}
```

## Customise the install user / SSH / network

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

  install_user                     = "npa"
  install_user_password            = var.npa_password # sensitive
  install_user_ssh_authorized_keys = [file("~/.ssh/id_ed25519.pub")]

  guest_network_interface = {
    name        = "ens4"
    dhcp4       = false
    addresses   = ["10.0.0.5/24"]
    gateway4    = "10.0.0.1"
    nameservers = ["8.8.8.8", "1.1.1.1"]
    mtu         = 1460
  }
}
```

When `install_user` differs from `ubuntu`, cloud-init removes the image's
default `ubuntu` account (`delete_default_user`, default `true`) so the
new user becomes the only login. The Publisher install paths
(`~/resources/.nonat`, `~/npa_publisher_wizard`) follow `install_user`'s
home — `wizard_path` is now nullable and derives from
`/home/<install_user>/npa_publisher_wizard`.

See the [common inputs](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/common-inputs/)
and the [GCP reference](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/gcp/)
for the full input table.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.7 |
| hashicorp/google | ~> 6.0 |
| hashicorp/http | >= 3.4 |
| hashicorp/cloudinit | >= 2.3 |
