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

SSH in and inspect cloud-init logs (find the public IP via
`terraform state show` or `aws ec2 describe-instances`):

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<public-ip>
sudo journalctl -u cloud-final --no-pager | tail -100
sudo cat /var/log/cloud-init-output.log | tail -50
```

Common causes:

| Symptom in logs | Likely cause |
|---|---|
| `Could not connect to gateway-...` | Egress to TCP/443 blocked. |
| `Authentication failed` from wizard | Token already consumed (re-applied without rotating). |
| `npa_publisher_wizard: command not found` | Wrong AMI or wrong `wizard_path`. |

## Reaching out

- File an issue on the [GitHub repo](https://github.com/johnneerdael/terraform-netskope-publisher/issues).
- Include: platform, module version, `terraform version`, the redacted error.
