---
title: Connectivity requirements
date: 2026-05-18
toc: true
---

The publisher VM **must** be able to make outbound TCP connections to
the Netskope regional gateway infrastructure (HTTPS / TCP 443). Without
that, the wizard runs at first boot but can't register, and the
publisher stays Offline forever — no matter how many `terraform apply`
runs you do.

This page collects the supported ways to give the VM that egress, per
platform, with the minimum HCL.

## Universal requirement

| Direction | Protocol | Destination | Purpose |
|---|---|---|---|
| Egress | TCP 443 | Netskope regional gateways (see your tenant for FQDNs / ranges) | Publisher ↔ Netskope control + data plane |
| Egress | TCP 443 | Netskope NPA API host (your tenant URL) | Wizard's initial enrollment call |

The source IP does **not** need to be static.

> The Terraform run also needs to reach `tenant_url` from wherever you
> run `terraform plan/apply` (CI runner, laptop). That's a separate
> network path — don't confuse it with the publisher's egress.

## AWS

`modules/aws` exposes one toggle: **`associate_public_ip_address`**.
Whether you set it depends on the subnet:

| Subnet type | `0.0.0.0/0` route | Set `associate_public_ip_address` to | Notes |
|---|---|---|---|
| **Public** | `igw-...` | `true` | Simplest. Publisher gets a free auto-assigned public IPv4. SSH access also becomes possible. |
| **Private with NAT** | `nat-...` | `false` (default) | NAT gateway is per-hour + per-GB billed (~$0.045/hr base in `us-east-1` as of writing). |
| **Private, transit-routed** | Custom (TGW / VPN / DX) | `false` | Egress goes through your hub. Make sure return traffic for 443 isn't dropped. |

Minimal example (public subnet path):

```hcl
module "publisher" {
  source = "github.com/johnneerdael/terraform-netskope-publisher//modules/aws?ref=v2.0.0"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = var.subnet_id
  security_group_ids = [var.security_group_id]
  key_name           = var.key_name

  associate_public_ip_address = true   # public subnet
}
```

Minimal example (private subnet with NAT — drop the line):

```hcl
module "publisher" {
  source = "github.com/johnneerdael/terraform-netskope-publisher//modules/aws?ref=v2.0.0"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = var.private_subnet_id     # subnet whose RT points at NAT
  security_group_ids = [var.security_group_id]
  key_name           = var.key_name
  # associate_public_ip_address omitted → defaults to false; egress via NAT
}
```

The module never creates the VPC, IGW, NAT gateway, or routes — those
are your responsibility. To verify: in the AWS console, open
*VPC → Subnets → your subnet → Route Table* and check the `0.0.0.0/0`
target.

### SSH access on private subnets

If you went with NAT (no public IP), the VM has no inbound path either.
Reach it via Session Manager (requires the `AmazonSSMManagedInstanceCore`
managed policy attached via `iam_instance_profile`), or via a bastion in
a public subnet.

## Azure

`modules/azure` exposes **`assign_public_ip`** (Standard PIP, attached
at the NIC).

| Subnet shape | Set `assign_public_ip` to | Notes |
|---|---|---|
| **Standard public IP per VM** | `true` | Simplest. Creates one `azurerm_public_ip` per replica. |
| **Subnet attached to a NAT gateway** | `false` (default) | Recommended at scale — NAT gateways are cheaper per flow than per-VM PIPs. Configure the NAT gateway separately and associate it with the subnet. |
| **Behind Azure Firewall / NVA** | `false` | Route table on the subnet points `0.0.0.0/0` at the firewall private IP. Make sure the firewall allows 443 outbound. |

Minimal example (public IP path):

```hcl
module "publisher" {
  source = "github.com/johnneerdael/terraform-netskope-publisher//modules/azure?ref=v2.0.0"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  resource_group_name  = var.resource_group_name
  location             = var.location
  subnet_id            = var.subnet_id
  admin_ssh_public_key = file("~/.ssh/id_rsa.pub")
  image_id             = var.image_id

  assign_public_ip = true
}
```

## GCP

`modules/gcp` exposes **`assign_public_ip`** which controls whether the
instance gets an `access_config {}` block (external IPv4).

| Connectivity shape | Set `assign_public_ip` to | Notes |
|---|---|---|
| **Ephemeral external IP** | `true` | Simplest. Free, but the IP changes on stop/start. |
| **Cloud NAT on the subnet's region+VPC** | `false` (default) | Recommended for fleets. Cloud NAT is regional and shared. |
| **Private connectivity (PSC / Interconnect)** | `false` | Whatever you have in place — Cloud NAT is the common case. |

Minimal example (Cloud NAT path):

```hcl
module "publisher" {
  source = "github.com/johnneerdael/terraform-netskope-publisher//modules/gcp?ref=v2.0.0"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  project    = var.project
  zone       = var.zone
  network    = var.network          # has a Cloud NAT attached to its region
  subnetwork = var.subnetwork
  image      = var.image
  # assign_public_ip omitted → defaults to false; egress via Cloud NAT
}
```

## vSphere

There's no module input for egress — the VM inherits its network's
routing, which is fully on you. Two practical checks:

1. **Layer-3 reachability**: from the VM (post-boot), `curl -v https://<tenant>.goskope.com/`
   should succeed. If your network does egress filtering, an explicit
   firewall rule allowing TCP/443 from the publisher subnet to the
   Netskope regional gateways is required.
2. **DNS**: the wizard resolves Netskope hostnames at boot. Make sure
   the VM's DNS (via DHCP or static config) can resolve public names —
   internal-only DNS won't cut it unless it forwards.

If your environment uses an explicit HTTP/HTTPS proxy, configure it via
cloud-init's `runcmd` or by baking proxy env vars into the template;
the module does not currently surface proxy settings as inputs (track
in [Roadmap](/terraform-netskope-publisher/reference/roadmap/)).

## Verifying

Once the VM is up, from inside it (or via Session Manager / bastion):

```bash
# Layer-3 reachability check
curl --max-time 10 -sS -o /dev/null -w "%{http_code}\n" https://<your-tenant>.goskope.com/
```

A `200`, `301`, or `403` from `goskope.com` means TCP/443 + DNS work.
A timeout or refusal means egress is blocked — fix that before
re-running the wizard.

See also: [Troubleshooting](/terraform-netskope-publisher/admin/operations/troubleshooting/).
