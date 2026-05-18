---
title: 3. AWS account prep
date: 2026-05-18
---

> ⏱ ~10 min · Requires an AWS account with admin (or equivalent).

You need four things in AWS before Terraform can do its job:

1. A **region** to deploy in (e.g., `eu-west-1`).
2. A **VPC subnet** with internet egress (the publisher needs to reach
   Netskope's regional gateways outbound on 443).
3. A **security group** that allows TCP/443 outbound to the internet, and
   inbound SSH (TCP/22) from your IP only.
4. An **EC2 key pair** so you can SSH into the instance if needed.
5. An **IAM user with programmatic access** that Terraform will use, with
   permissions to create EC2 instances + describe AMIs.

## 3.1 Pick a region

Pick one close to where your private apps live. This guide uses
`eu-west-1` (Ireland) in examples; substitute as needed.

## 3.2 Get a subnet + security group

If you already have a VPC: note the subnet ID (`subnet-...`) and security
group ID (`sg-...`). The subnet must have a route to a NAT gateway or
internet gateway.

If you don't have one yet: use the AWS console's "VPC → Create VPC" with
the "VPC, subnets, etc." preset. One public subnet is fine for testing.

For the security group, the minimum is:

| Direction | Protocol | Port | Source / Dest         | Reason                           |
|-----------|----------|------|-----------------------|----------------------------------|
| Egress    | TCP      | 443  | `0.0.0.0/0`           | Netskope gateway connectivity    |
| Ingress   | TCP      | 22   | your office IP / VPN  | SSH troubleshooting (optional)   |

## 3.3 Create an EC2 key pair

EC2 console → Key Pairs → Create key pair. Name it something memorable
(e.g., `npa-publisher-key`). Download the `.pem` and store it safely.

## 3.4 Create an IAM user with access keys

1. IAM console → Users → Add users.
2. Name: `terraform-npa-publisher`.
3. Permissions: attach the AWS-managed policy `AmazonEC2FullAccess` for
   this walkthrough. (For production, scope this down — see the
   [Admin operations guide](/terraform-netskope-publisher/admin/operations/secret-handling/).)
4. After creation, open the user → Security credentials → Create access
   key → "Command Line Interface (CLI)". Save the access key ID and
   secret access key.

Next → [Netskope tenant prep](/terraform-netskope-publisher/starter/04-netskope-tenant-prep/)
