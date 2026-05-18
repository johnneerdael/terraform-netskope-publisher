---
title: Registration flow
date: 2026-05-18
---

## End-to-end sequence

For each derived publisher name (see [Naming, replicas, and for_each](/terraform-netskope-publisher/admin/concepts/naming-replicas-foreach/)):

1. **List** — `GET {tenant_url}/api/v2/infrastructure/publishers` with
   header `Netskope-Api-Token: <api_token>`. The response is decoded and
   indexed by `publisher_name`.
2. **Create-if-missing** — for any name not present in the list response,
   `POST {tenant_url}/api/v2/infrastructure/publishers` with body
   `{"publisher_name": "<name>"}`. Captures the new `publisher_id`.
3. **Token** — `POST {tenant_url}/api/v2/infrastructure/publishers/{id}/registration_token`
   returns `data.token`. One call per publisher.
4. **User-data render** — the token is interpolated into a cloud-init
   document containing `runcmd: - [ /home/ubuntu/npa_publisher_wizard, -token, "<token>" ]`.
5. **VM provision** — the platform submodule attaches the rendered
   user-data to the VM. On first boot, cloud-init runs the wizard, which
   registers the publisher with the tenant.

## Idempotency

Existing publishers with the same name are reused, not duplicated. The
output map's `existed_before` flag tells you which were pre-existing.

## Why `data "http"` for POST

`hashicorp/http >= 3.4` supports `method = "POST"` on the `http` data
source. We use it because (a) it has no provisioner / `local-exec` /
shell dependency, and (b) it keeps the entire registration flow inside
Terraform's plan/apply graph.

## What's NOT in the registration flow

- Publisher software upgrades — driven from the Netskope console.
- Publisher deletion on `terraform destroy` — disabled by default;
  see [Delete a publisher cleanly](/terraform-netskope-publisher/admin/how-to/delete-publisher/).
- Token rotation — see [Rotate the registration token](/terraform-netskope-publisher/admin/how-to/rotate-token/).
