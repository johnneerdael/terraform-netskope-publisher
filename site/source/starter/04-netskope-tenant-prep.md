---
title: 4. Netskope tenant prep
date: 2026-05-18
---

> ⏱ ~5 min · Requires admin access to your Netskope tenant.

You need two values from your Netskope tenant: the **tenant URL** and an
**API token** with permissions to manage publishers.

## 4.1 Find your tenant URL

Log in to your Netskope admin console. The URL in your browser is your
tenant URL — strip everything after the host. Examples:

- `https://yourcompany.goskope.com`
- `https://tenant-eu.goskope.com`

## 4.2 Mint an NPA API token

1. In the admin console: **Settings → Tools → REST API v2**.
2. Click **New Token**.
3. Token name: `terraform-publisher-starter`.
4. Privileges: enable read + write on
   `/api/v2/infrastructure/publishers` and
   `/api/v2/infrastructure/publishers/*/registration_token`.
5. Expiration: 90 days is a reasonable default for a walkthrough.
6. Click **Create**, copy the token immediately — you cannot view it
   again.

> ⚠️ Treat the token like a password. Don't paste it into chat, don't
> commit it to git, don't save it in plaintext anywhere shared.

Next → [Configure your shell](/terraform-netskope-publisher/starter/05-configure-shell/)
