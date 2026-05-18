---
title: vSphere platform inputs
date: 2026-05-18
toc: true
---

## Inputs

The `vsphere = { ... }` object accepts:

| Name | Type | Default | Description |
|---|---|---|---|
| `datacenter` | string | required | vSphere datacenter name. |
| `cluster` | string | `null` | Compute cluster name. One of `cluster` or `host` is required. |
| `host` | string | `null` | ESXi host name. One of `cluster` or `host` is required. |
| `datastore` | string | required | Target datastore name. |
| `network_name` | string | required | Port group / network name. |
| `template_name` | string | required | Source VM template (the Netskope OVA imported as a template). |
| `folder` | string | `null` | VM folder path. |
| `num_cpus` | number | `2` | vCPU count. |
| `memory` | number | `4096` | Memory in MB. |

## Minimal example

```hcl
vsphere = {
  datacenter    = "dc1"
  cluster       = "cluster1"
  datastore     = "ds1"
  network_name  = "vm-net"
  template_name = "netskope-publisher-template"
}
```

## Platform-specific outputs

| Output | Type | Description |
|---|---|---|
| `vm_uuids` | list(string) | vSphere VM UUIDs. |
| `guestinfo_by_name` | map(string) (sensitive) | Base64-encoded cloud-init user-data per VM. |

## How cloud-init is delivered

The module sets four `extra_config` keys on the VM, which the official
Netskope OVA's cloud-init reads via the VMware datasource:

| Key | Purpose |
|---|---|
| `guestinfo.userdata` | Base64 cloud-init user-data. |
| `guestinfo.userdata.encoding` | Always `base64`. |
| `guestinfo.metadata` | Base64 NoCloud meta-data (instance-id + local-hostname). |
| `guestinfo.metadata.encoding` | Always `base64`. |

No `customize {}` block is used; hostname + networking come from
cloud-init, not from the VMware customization engine.

## Caveats

- `var.tags` is **not** wired to `custom_attributes` — vSphere requires
  pre-created `vsphere_custom_attribute` resources keyed by numeric IDs,
  not strings. Wrap the module if you need them.
- The template must be powered off and contain a cloud-init that
  recognizes the VMware datasource (the Netskope OVA does).
