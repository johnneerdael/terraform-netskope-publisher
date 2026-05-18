---
title: 7. Verify it's online
date: 2026-05-18
---

> ⏱ ~2 min · Open the Netskope admin console.

In the admin console: **Settings → Security Cloud Platform → Netskope
Private Access → Publishers**.

You should see your publisher (named `my-first-publisher-1`) with a green
**Online** indicator within 1–2 minutes of `terraform apply` finishing.

If it's not online after 5 minutes:

- SSH in (`ssh -i ~/Downloads/npa-publisher-key.pem ubuntu@<public-ip>`)
  and check cloud-init logs: `sudo journalctl -u cloud-final --no-pager`
- Re-read the [Troubleshooting guide](/terraform-netskope-publisher/admin/operations/troubleshooting/).

Next → [Tear it down](/terraform-netskope-publisher/starter/08-tear-down/)
