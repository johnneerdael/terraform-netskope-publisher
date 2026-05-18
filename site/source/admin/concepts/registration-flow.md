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
   document. The runcmd shape depends on `bootstrap` (see below).
5. **VM provision** — the platform submodule attaches the rendered
   user-data to the VM. On first boot, cloud-init runs the rendered
   `runcmd`, which (in bootstrap mode) installs the wizard via
   `bootstrap.sh` and then registers the publisher with the tenant.

## Cloud-init runcmd (pre-baked image — `bootstrap = false`)

```yaml
runcmd:
  - su - ubuntu -c 'sudo /home/ubuntu/npa_publisher_wizard -token "<TOKEN>"'
```

The wizard binary is already on disk (baked into the Netskope Publisher
image), so cloud-init just calls it with the per-publisher token.

## Cloud-init runcmd (bootstrap mode — `bootstrap = true`, v2.3+)

```yaml
runcmd:
  - chmod 0600 /etc/netplan/60-cloudinit-override.yaml  # only if guest_network_interface set
  - netplan apply                                        # only if guest_network_interface set
  - pkill -KILL -u ubuntu || true                        # only if install_user != "ubuntu"
  - userdel -r ubuntu 2>/dev/null || true                # only if install_user != "ubuntu"
  - chmod 1777 /tmp
  - install -d -o <user> -g <user> -m 0755 /home/<user>/resources   # only if nonat
  - install -o <user> -g <user> -m 0644 /dev/null /home/<user>/resources/.nonat  # only if nonat
  - su - <user> -c 'curl -fsSL https://s3-us-west-2.amazonaws.com/publisher.netskope.com/latest/generic/bootstrap.sh | sudo bash'
  - su - <user> -c 'sudo /home/<user>/npa_publisher_wizard -token "<TOKEN>"'
```

Where `<user>` is `install_user` (default `ubuntu`). The bootstrap step
installs the wizard onto a stock Ubuntu image; the registration step then
runs from the install user's home, not a hard-coded `/home/ubuntu`.

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
