---
title: 1. What you'll build
date: 2026-05-18
---

> ⏱ ~5 min reading · No prerequisites yet.

By the end of this guide you'll have:

- A working **Terraform** install on your laptop (macOS or Windows).
- An **AWS account** configured for programmatic access.
- A **Netskope NPA API token** that lets Terraform talk to your tenant.
- One **EC2 publisher** running, registered to your tenant, and showing
  **Online** in the Netskope admin console.

The publisher is the thing that brokers your private applications to
remote Netskope clients. Once it's online, you can attach apps and policies
to it from the console — that's where this guide stops and the
[Admin guides](/terraform-netskope-publisher/admin/) take over.

## How long will this take?

About 30 to 45 minutes the first time, mostly waiting on AWS to start an
instance.

## What it costs

A `t3.medium` EC2 instance is roughly USD 0.04/hr in `eu-west-1` at the
time of writing. Tear it down at the end ([step 8](/terraform-netskope-publisher/starter/08-tear-down/))
and you're back to zero.

Ready? → [Install the tools](/terraform-netskope-publisher/starter/02-install-tools/)
