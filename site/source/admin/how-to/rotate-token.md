---
title: Rotate the registration token
date: 2026-05-18
---

## Problem

You want the publisher to re-register with a freshly minted registration
token (e.g., the original token leaked, or the publisher fell out of
sync).

## Solution

> ⚠️ Token rotation as a first-class flag (`force_token_rotation`) is a
> deferred feature. The workaround below works today.

Taint the registration data source so Terraform re-issues a token on the
next apply, then re-run cloud-init by replacing the VM:

```bash
terraform taint 'module.publisher.module.aws[0].module.registration.data.http.token["pub-eu-1"]'
terraform taint 'module.publisher.module.aws[0].aws_instance.publisher["pub-eu-1"]'
terraform apply
```

The instance is replaced; on first boot the new wizard run uses the
fresh token.

## Notes

- The publisher record in the tenant stays — only the VM and the local
  cached token are replaced.
- Replace the instance during a maintenance window — clients steered to
  this publisher disconnect briefly.
- Track first-class support in the
  [roadmap](/terraform-netskope-publisher/reference/roadmap/).
