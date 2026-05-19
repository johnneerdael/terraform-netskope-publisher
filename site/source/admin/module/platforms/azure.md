---
title: Azure platform inputs
date: 2026-05-19
toc: true
---

> ⚠️ The publisher VM needs outbound TCP/443. See
> [Connectivity requirements → Azure](/terraform-netskope-publisher/admin/concepts/connectivity/)
> for the supported shapes (`assign_public_ip = true`, NAT Gateway on
> the subnet, or Azure Firewall / NVA). Misconfiguring this is the
> single most common cause of "publisher never goes Online".

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `resource_group_name` | string | required | RG the VM and NIC live in. |
| `location` | string | required | Azure region. |
| `subnet_id` | string | required | Full subnet resource ID. |
| `admin_ssh_public_key` | string | required | SSH public key for the admin user. |
| `vm_size` | string | `"Standard_D2s_v5"` | VM SKU. |
| `admin_username` | string | `null` → coalesces to `install_user` | Azure VM admin user. v2.3 coalesces to `install_user` so the Azure admin and the cloud-init install user are always the same account. |
| `network_security_group_id` | string | `null` | NSG to attach at NIC level. |
| `assign_public_ip` | bool | `false` | Create + attach a Standard public IP. |
| `os_disk.type` | string | `"Premium_LRS"` | OS disk storage type. |
| `os_disk.size_gb` | number | `64` | OS disk size. |
| `image_id` | string | `null` | Resource ID of an existing image (mutually exclusive with `marketplace`). |
| `marketplace` | object | `null` | Marketplace image: `{ publisher, offer, sku, version }`. |
| `accept_marketplace_terms` | bool | `false` | When true and `marketplace` is set, creates `azurerm_marketplace_agreement`. |

See [Common inputs](/terraform-netskope-publisher/admin/module/common-inputs/)
for `bootstrap`, `bootstrap_url`, `nonat`, `install_user`,
`install_user_password`, `install_user_ssh_authorized_keys`,
`delete_default_user`, `guest_network_interface`, and `wizard_path`
(all v2.3+).

Exactly one of `image_id`, `marketplace`, **or** `bootstrap = true` must
be set (enforced by a VM-level precondition). When `bootstrap = true`
and neither `image_id` nor `marketplace` is set, the module defaults the
marketplace reference to Canonical's Ubuntu 22.04 LTS Minimal (see
below).

## Bootstrap mode — Canonical default (v2.3+)

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

The module emits a `source_image_reference` for the Canonical image:

| Field | Value |
|---|---|
| publisher | `Canonical` |
| offer | `0001-com-ubuntu-minimal-jammy` |
| sku | `minimal-22_04-lts-gen2` |
| version | `latest` |

No `plan {}` block is emitted (Canonical images don't require marketplace
terms acceptance), and `accept_marketplace_terms` is irrelevant in this
mode. Cloud-init runs `bootstrap.sh` then registers via the API token.

## Minimal example (custom image)

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

## Minimal example (Netskope Marketplace)

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

  marketplace = {
    publisher = "netskopeinc"
    offer     = "netskope_npa_publisher"
    sku       = "netskope_npa_publisher"
    version   = "latest"
  }
  accept_marketplace_terms = true
}
```

> Verify the exact `publisher` / `offer` / `sku` values against the live
> Marketplace listing before applying — they can change.

## Full main.tf example — bootstrap, custom user, SSH key, and password

```hcl
terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "netskope_tenant_url" {
  type = string
}

variable "netskope_api_token" {
  type      = string
  sensitive = true
}

variable "npa_password" {
  type      = string
  sensitive = true
}

resource "tls_private_key" "publisher_ssh" {
  algorithm = "ED25519"
}

module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/azure"
  version = "~> 2.3"

  name_prefix = "pub-az"
  replicas    = 2
  tags        = { Owner = "platform-team", Env = "prod" }

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  resource_group_name       = "rg-npa-prod"
  location                  = "westeurope"
  subnet_id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-prod/subnets/snet-publisher"
  network_security_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/networkSecurityGroups/nsg-publisher"
  assign_public_ip          = false
  vm_size                   = "Standard_D4s_v5"
  admin_username            = "npa"
  admin_ssh_public_key      = tls_private_key.publisher_ssh.public_key_openssh

  os_disk = {
    type    = "Premium_LRS"
    size_gb = 128
  }

  bootstrap             = true
  install_user          = "npa"
  install_user_password = var.npa_password # sensitive
  install_user_ssh_authorized_keys = [
    file(pathexpand("~/.ssh/team_ed25519.pub")),
  ]

  guest_network_interface = {
    name        = "eth0"
    dhcp4       = true
    nameservers = ["168.63.129.16"]
    mtu         = 1500
  }
}

output "publisher_names" {
  value = module.publisher.publisher_names
}

output "publisher_private_ips" {
  value = {
    for name, publisher in module.publisher.publishers : name => publisher.private_ip
  }
  sensitive = true
}

output "publisher_private_key_pem" {
  value     = tls_private_key.publisher_ssh.private_key_pem
  sensitive = true
}
```

## Platform-specific outputs

| Output | Type | Description |
|---|---|---|
| `vm_ids` | list(string) | `azurerm_linux_virtual_machine` IDs. |
| `custom_data_by_name` | map(string) (sensitive) | Base64-encoded cloud-init per VM. |

## Caveats

- `azurerm` authenticates at provider-configure time. Even
  `terraform plan` requires valid credentials. Use SP / OIDC / Azure CLI
  auth at the caller level.
- `accept_marketplace_terms = true` creates a tenant-wide
  `azurerm_marketplace_agreement`. Once accepted you can drop the flag.
