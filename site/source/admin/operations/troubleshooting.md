---
title: Troubleshooting
date: 2026-05-18
toc: true
---

## Registration flow failures

### `Error: List publishers failed (status=401)`

The `netskope_api_token` is missing, expired, or lacks publisher
read scope. Mint a fresh token in the Netskope admin console (Settings
→ Tools → REST API v2) with read+write on `/infrastructure/publishers`.

### `Error: List publishers failed (status=404)`

`netskope_tenant_url` is wrong. Confirm by hitting the URL in a browser
— you should see the admin console login page.

### `Error: Create publisher ... failed (status=409)`

A publisher with that name already exists but the list endpoint didn't
return it. Usually means your token can read some publishers but not all.
Use a token with tenant-wide visibility.

## VM provisioning failures

### `Error: status 400 ... InvalidAMIID.NotFound`

The AMI lookup found nothing. Either the calling identity lacks
`ec2:DescribeImages`, or the Netskope AMI isn't available in your
region. Pass `ami_id` explicitly to override.

### Azure: `Error: building account: ... AADSTS700038`

Your `azurerm` provider config is using invalid Service Principal
credentials. Even `terraform plan` requires valid auth — see
[Secret handling](/terraform-netskope-publisher/admin/operations/secret-handling/).

## Cloud-init / wizard failures

### Publisher never goes Online

**Most common cause: no outbound 443.** The wizard runs at first boot
but can't reach Netskope's gateways. Check the VM's subnet has either:

- A `0.0.0.0/0 → igw-...` route AND the VM has a public IP
  (`associate_public_ip_address = true`), or
- A `0.0.0.0/0 → nat-...` route via a NAT gateway.

If neither is true, the publisher will never register no matter what
the wizard does. The full per-platform recipe (AWS, Azure, GCP,
vSphere) with HCL examples lives at
[Connectivity requirements](/terraform-netskope-publisher/admin/concepts/connectivity/).

SSH in and inspect cloud-init logs. Use the user you configured —
`<install_user>` (default `ubuntu`):

```bash
ssh -i ~/.ssh/your-key.pem <install_user>@<public-ip>
sudo journalctl -u cloud-final --no-pager | tail -100
sudo cat /var/log/cloud-init-output.log | tail -100
```

Common causes:

| Symptom in logs | Likely cause |
|---|---|
| `Could not connect to gateway-...` | Egress to TCP/443 blocked. |
| `Authentication failed` from wizard | Token already consumed (re-applied without rotating). |
| `npa_publisher_wizard: command not found` | Wrong image or wrong `wizard_path`. In bootstrap mode, `bootstrap.sh` failed before installing the wizard — read further up in `cloud-init-output.log`. |

### Bootstrap-mode failures (v2.3+)

When `bootstrap = true`, cloud-init runs Netskope's `bootstrap.sh` before
the registration step. Failures in the script abort the whole runcmd.
Where to look:

| Symptom | Where to check | Likely cause |
|---|---|---|
| Cloud-init exits with non-zero status | `sudo cloud-init status --long` and `/var/log/cloud-init-output.log` | `bootstrap.sh` failed; read the script's stderr in `cloud-init-output.log`. |
| `curl: (6) Could not resolve host: s3-us-west-2.amazonaws.com` | `cloud-init-output.log` | DNS or egress is broken before the script could download. Verify the VM has working DNS and egress to `*.amazonaws.com`. |
| `curl: (28) Operation timed out` | `cloud-init-output.log` | Egress to the bootstrap S3 bucket blocked. Override `bootstrap_url` to point at a private mirror, or open egress to `s3-us-west-2.amazonaws.com:443`. |
| `dpkg: error: dpkg status database is locked` | `cloud-init-output.log` | Another apt process is racing `bootstrap.sh`. v2.3 disables `package_update`; if you've re-added it (or have a snap-refresh timer firing), drop it. |
| `Permission denied` writing `/tmp` | `cloud-init-output.log` | `chmod 1777 /tmp` didn't run; check the cloud-init runcmd ordering wasn't customised. |

### `~/resources/.nonat` missing

If you set `nonat = true` but the Publisher still SNATs traffic, confirm
the marker file landed before the Publisher service started:

```bash
ls -la /home/<install_user>/resources/.nonat
sudo systemctl status npa_publisher_service
```

The cloud-init runcmd creates `.nonat` *before* the bootstrap step, so by
the time the Publisher service first runs, the marker is in place. If the
file is missing, check `/var/log/cloud-init-output.log` for the `install`
command that should have created it.

### "I deleted the ubuntu user and now I'm locked out"

When `install_user != "ubuntu"` and `delete_default_user = true` (the
default), cloud-init runs `userdel -r ubuntu` on first boot. Any SSH
session you opened as `ubuntu` before that is killed; subsequent logins
must use `install_user`. If you accidentally lost the install user's
private key, the only recovery is reprovisioning the VM (cloud images
typically don't ship serial-console password access).

### "I can't `sudo` as my new install_user"

The cloud-init template grants the install user `NOPASSWD: ALL` via the
`users:` directive, so `sudo` should always work. If it doesn't:

```bash
sudo grep -r '<install_user>' /etc/sudoers.d/ /etc/sudoers
```

If the entry is missing, cloud-init's `users` module didn't run —
inspect `cloud-init.log` and `cloud-init-output.log` for module errors
earlier in the boot.

## Reaching out

- File an issue on the [GitHub repo](https://github.com/johnneerdael/terraform-netskope-publisher/issues).
- Include: platform, module version, `terraform version`, the redacted error.
