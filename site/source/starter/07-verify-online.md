---
title: 7. Verify it's online
date: 2026-05-18
---

> ⏱ ~2 min · Open the Netskope admin console.

In the admin console: **Settings → Security Cloud Platform → Netskope
Private Access → Publishers**.

You should see your publisher (named `my-first-publisher-1`) with a green
**Online** indicator within 1–2 minutes of `terraform apply` finishing.

## Finding the publisher's public IP

The `publishers` output is `sensitive`, so `terraform output publishers`
redacts it. Two ways to retrieve the IP:

```bash
# From Terraform state
terraform state show 'module.publisher.aws_instance.publisher["my-first-publisher-1"]' \
  | grep public_ip
```

```bash
# Or via AWS CLI
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=my-first-publisher-1" \
  --query 'Reservations[].Instances[].PublicIpAddress' --output text
```

## If it's not Online after 5 minutes

The single most common cause is **no outbound Internet** from the VM —
i.e., the subnet isn't actually a public subnet (no IGW route) or
doesn't have a NAT gateway. Revisit
[step 3](/terraform-netskope-publisher/starter/03-aws-account-prep/).

To inspect the wizard directly, grab the public IP (above), then:

```bash
ssh -i ~/Downloads/npa-publisher-key.pem ubuntu@<public-ip>
sudo journalctl -u cloud-final --no-pager | tail -100
sudo cat /var/log/cloud-init-output.log | tail -50
```

A `Connection refused` / `Connection timed out` from the wizard means
outbound is blocked. See the
[Troubleshooting guide](/terraform-netskope-publisher/admin/operations/troubleshooting/)
for other failure modes.

Next → [Tear it down](/terraform-netskope-publisher/starter/08-tear-down/)
