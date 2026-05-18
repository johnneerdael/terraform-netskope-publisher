---
title: Azure platform inputs
date: 2026-05-18
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
