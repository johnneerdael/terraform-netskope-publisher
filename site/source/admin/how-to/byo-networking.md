---
title: Bring your own networking
date: 2026-05-18
---

## Problem

You have existing VPCs / VNets / VPC networks and don't want this module
to create or assume any networking primitives.

## Solution

The module never creates VPCs, subnets, security groups, or routing
constructs. You pass references to existing ones via the per-platform
input object:

| Platform | Networking inputs |
|---|---|
| AWS | `aws.subnet_id`, `aws.security_group_ids[]`, `aws.associate_public_ip_address` |
| Azure | `azure.subnet_id`, `azure.network_security_group_id`, `azure.assign_public_ip` |
| GCP | `gcp.network`, `gcp.subnetwork`, `gcp.assign_public_ip`, `gcp.network_tags[]` |
| vSphere | `vsphere.network_name` |

## Required egress

The publisher needs outbound TCP/443 to the Netskope regional gateway
infrastructure. The exact destination set depends on your tenant;
consult Netskope documentation for current FQDNs / IP ranges.

For per-platform recipes (public IP vs NAT gateway vs Cloud NAT vs
on-prem firewall) with working HCL, see
[Connectivity requirements](/terraform-netskope-publisher/admin/concepts/connectivity/).

## Optional ingress

SSH (TCP/22) from your operator subnet is useful for troubleshooting.
Not strictly required — the publisher does not accept inbound user
traffic on any port.

## Guest-OS interface override (`guest_network_interface`, v2.3+)

Separate from the cloud-side networking inputs above, you can override
the guest OS's primary interface from cloud-init. This is useful for
static IP assignments inside vSphere / Hyper-V templates, jumbo-frame
MTUs on AWS / Azure, or pinning the MTU to 1460 on GCP without relying
on the image default.

`guest_network_interface` is a nullable object on `modules/aws`,
`modules/azure`, and `modules/gcp`. When set, cloud-init drops
`/etc/netplan/60-cloudinit-override.yaml` and runs `netplan apply` before
the Publisher install steps.

| Field | Type | Default | Description |
|---|---|---|---|
| `name` | string | — | Interface name as the guest sees it (e.g. `ens4` on GCP Ubuntu, `ens5` on AWS nitro, `eth0` on older kernels). |
| `dhcp4` | bool | `false` | Whether netplan should also try DHCP4 on the interface. |
| `addresses` | list(string) | `[]` | Static IPv4 (and/or IPv6) addresses in CIDR form, e.g. `["10.0.0.5/24"]`. |
| `gateway4` | string | `null` | Default IPv4 gateway. |
| `nameservers` | list(string) | `[]` | DNS resolver IPs. |
| `mtu` | number | `null` | MTU override (e.g. `1460` on GCP, `9001` for jumbo frames on AWS). |

### Example (static IP on AWS)

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.3"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = var.subnet_id
  security_group_ids = [var.security_group_id]
  bootstrap          = true

  guest_network_interface = {
    name        = "ens5"
    dhcp4       = false
    addresses   = ["10.0.0.5/24"]
    gateway4    = "10.0.0.1"
    nameservers = ["8.8.8.8", "1.1.1.1"]
    mtu         = 9001
  }
}
```

> Static IPs on AWS / Azure / GCP still need to fall **inside** the
> subnet's CIDR and not collide with reservations or DHCP pools — the
> module does not coordinate with the cloud's IPAM.

Leave `guest_network_interface = null` (the default) to let the image's
own DHCP setup handle the interface unchanged.

## Notes

- The module does not validate that egress is reachable. If
  registration hangs, that's usually the first thing to check.
