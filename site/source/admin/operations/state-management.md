---
title: State management
date: 2026-05-18
---

## What ends up in state

Terraform state for this module includes:

- The Netskope registration tokens (one per publisher) — **sensitive**.
- The base64-encoded cloud-init user-data containing those tokens.
- All per-platform resource attributes (VM IDs, IPs, etc.).

Tokens in state are unavoidable for the registration flow to work.

## Backend recommendation

Use a remote backend with at-rest encryption and tight access control:

| Cloud | Suggested backend |
|---|---|
| AWS | S3 + DynamoDB locking, SSE-KMS |
| Azure | `azurerm` backend on a storage account with CMK |
| GCP | `gcs` backend on a bucket with CMEK |
| Multi-cloud | Terraform Cloud / Enterprise |

Never check the state file into git, even encrypted.

## Workspace isolation

If you run multiple environments (dev / staging / prod) from the same
configuration, use Terraform workspaces or separate root modules per
environment. The tenant-side publisher records are shared across all
environments — namespace them via `name_prefix` (e.g., `pub-prod-`).

## What's safe to share

Module outputs marked `sensitive = true` are redacted from console
output but **not** from state. Sharing state files broadly is equivalent
to sharing your registration tokens.
