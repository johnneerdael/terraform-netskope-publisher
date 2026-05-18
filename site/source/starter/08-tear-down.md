---
title: 8. Tear it down
date: 2026-05-18
---

> ⏱ ~2 min · Stops your AWS bill.

In your `~/npa-publisher-starter` (or `$HOME\npa-publisher-starter`)
directory:

```bash
terraform destroy
```

Type `yes` when prompted. Terraform tears down the EC2 instance and the
ephemeral data sources.

## What's NOT destroyed (intentionally)

- The **publisher record in your Netskope tenant** stays. The module
  defaults to *not* deleting publisher records on destroy so a re-apply
  reuses the same publisher ID. Delete it manually from the admin
  console if you want a clean slate: **Publishers → select → Delete**.
- Your **VPC, subnet, security group, key pair, and IAM user**. They
  predate Terraform.

## Optional: revoke the API token

If this was a one-off, revoke the token you minted in step 4:
**Settings → Tools → REST API v2 → your token → Revoke**.

Next → [Next steps](/terraform-netskope-publisher/starter/09-next-steps/)
