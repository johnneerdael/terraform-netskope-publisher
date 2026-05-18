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

## Notes

- The module does not validate that egress is reachable. If
  registration hangs, that's usually the first thing to check.
