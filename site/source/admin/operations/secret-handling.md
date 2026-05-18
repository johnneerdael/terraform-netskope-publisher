---
title: Secret handling
date: 2026-05-18
---

## What's secret

| Value | Type |
|---|---|
| `var.netskope_api_token` | NPA API token, long-lived |
| Each registration token (one per publisher) | Short-lived; one-use during cloud-init |

The API token has broader privilege than the registration tokens — it
can list, create, and delete publishers tenant-wide.

## Where to put the API token

In order of preference:

1. **Terraform Cloud / Enterprise variable**, marked sensitive.
2. **Vault** + `vault_generic_secret` data source.
3. **CI secret store** (GitHub Actions secret, GitLab masked variable) +
   `TF_VAR_netskope_api_token` env var.
4. **Local shell env var** (development only).

Avoid:

- Plain `terraform.tfvars` files in git.
- Hard-coded literals in `.tf` files.

## Rotating the API token

When you rotate the upstream token:

1. Mint the new one in the Netskope console.
2. Update your secret store with the new value.
3. Re-run `terraform plan` — there should be no diff (the token affects
   the registration flow, not stored resources).

The publishers themselves don't care about the API token after
registration — they only use the per-publisher registration token at
first boot.

## Registration tokens

You don't need to handle these directly. They flow:
NPA API → Terraform state → cloud-init → wizard → discarded.

If you need to re-issue one, see
[Rotate the registration token](/terraform-netskope-publisher/admin/how-to/rotate-token/).
