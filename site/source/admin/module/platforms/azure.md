---
title: Azure platform inputs
date: 2026-05-18
toc: true
---

## Inputs

The `azure = { ... }` object accepts:

| Name | Type | Default | Description |
|---|---|---|---|
| `resource_group_name` | string | required | RG the VM and NIC live in. |
| `location` | string | required | Azure region. |
| `subnet_id` | string | required | Full subnet resource ID. |
| `admin_ssh_public_key` | string | required | SSH public key for the admin user. |
| `vm_size` | string | `"Standard_D2s_v5"` | VM SKU. |
| `admin_username` | string | `"ubuntu"` | Linux admin username (cloud-init wizard runs as this user). |
| `network_security_group_id` | string | `null` | NSG to attach at NIC level. |
| `assign_public_ip` | bool | `false` | Create + attach a Standard public IP. |
| `os_disk.type` | string | `"Premium_LRS"` | OS disk storage type. |
| `os_disk.size_gb` | number | `64` | OS disk size. |
| `image_id` | string | `null` | Resource ID of an existing image (mutually exclusive with `marketplace`). |
| `marketplace` | object | `null` | Marketplace image: `{ publisher, offer, sku, version }`. |
| `accept_marketplace_terms` | bool | `false` | When true and `marketplace` is set, creates `azurerm_marketplace_agreement`. |

Exactly one of `image_id` or `marketplace` must be non-null (enforced by
a VM-level precondition).

## Minimal example (custom image)

```hcl
azure = {
  resource_group_name  = "rg-npa"
  location             = "westeurope"
  subnet_id            = "/subscriptions/.../subnets/sn"
  admin_ssh_public_key = file("~/.ssh/id_rsa.pub")
  image_id             = "/subscriptions/.../Microsoft.Compute/images/netskope-publisher"
}
```

## Minimal example (Marketplace)

```hcl
azure = {
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
