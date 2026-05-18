---
title: Delete a publisher cleanly
date: 2026-05-18
---

## Problem

You want `terraform destroy` to also remove the publisher record from
your Netskope tenant, not just the VM.

## Solution

> ⚠️ `delete_publisher_on_destroy = true` is a deferred feature. Today,
> deletion is manual.

After `terraform destroy` finishes:

1. Open the Netskope admin console → **Settings → Security Cloud
   Platform → Netskope Private Access → Publishers**.
2. Select the publisher (e.g., `pub-eu-1`).
3. Click **Delete**.

Or via API:

```bash
curl -X DELETE \
  -H "Netskope-Api-Token: $NETSKOPE_API_TOKEN" \
  "$NETSKOPE_TENANT_URL/api/v2/infrastructure/publishers/<publisher_id>"
```

The `publisher_id` is in the Terraform output (`publishers.<name>.publisher_id`)
before you destroy.

## Notes

- The module deliberately preserves the publisher record on destroy so
  re-applies reuse the same publisher ID. This matters for tenant
  policies that target a specific publisher.
- Track first-class support in the [roadmap](/terraform-netskope-publisher/reference/roadmap/).
