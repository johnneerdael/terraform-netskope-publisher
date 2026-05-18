---
title: Bring your own image
date: 2026-05-18
---

## Problem

You maintain a private/custom Netskope publisher image (e.g., for
compliance reasons) and want the module to use it instead of the
public/Marketplace one.

## Solution

Each platform exposes an image override input:

| Platform | Input | What to pass |
|---|---|---|
| AWS | `aws.ami_id` | `"ami-..."` |
| Azure | `azure.image_id` | Full image resource ID |
| GCP | `gcp.image` | Image self-link `projects/.../global/images/...` |
| vSphere | `vsphere.template_name` | Template VM name |

Example (AWS):

```hcl
aws = {
  subnet_id          = var.subnet_id
  security_group_ids = [var.security_group_id]
  key_name           = var.key_name
  ami_id             = "ami-0123456789abcdef0"
}
```

## Notes

- Your custom image must still ship `npa_publisher_wizard` at the
  configured `wizard_path` (default `/home/ubuntu/npa_publisher_wizard`)
  and a cloud-init that runs the `runcmd` from the rendered user-data.
- Override `wizard_path` at the root if your image puts the binary
  elsewhere.
