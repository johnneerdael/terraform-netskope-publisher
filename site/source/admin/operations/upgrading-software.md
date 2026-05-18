---
title: Upgrading publisher software
date: 2026-05-18
---

## Publisher software lifecycle

Publisher software upgrades are driven by **Netskope**, not by this
module. Once a publisher is registered, the wizard pulls the current
software version from your tenant and self-updates per the upgrade
profile assigned to it in the Netskope admin console.

## Where to manage upgrades

In the admin console: **Settings → Security Cloud Platform → Netskope
Private Access → Publishers → Upgrade Profiles**.

Upgrade profiles control:

- Maintenance windows
- Target release channel (stable / beta)
- Auto-upgrade vs manual approval

## What this module DOES NOT do

- Trigger upgrades
- Assign upgrade profiles
- Roll back failed upgrades
- Replace the VM when the publisher software updates

If you want infrastructure-as-code over upgrade profiles, look at the
[Netskope NPA MCP `upgrade-orchestration` skill](https://github.com/netskopeoss/netskope-npa-mcp)
or the Netskope NPA Terraform provider's upgrade profile resources
(separate module).

## When to replace the VM

Replace the VM (`terraform taint` + `apply`) only if:

- The publisher software is so old the wizard can no longer self-update.
- The base image needs to change (new AMI / image version).
- You're rotating the registration token (see the how-to).
