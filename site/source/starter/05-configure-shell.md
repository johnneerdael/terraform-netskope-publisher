---
title: 5. Configure your shell
date: 2026-05-18
---

> ⏱ ~5 min · Requires the keys you collected in steps 3 and 4.

Terraform needs to know how to talk to AWS and to Netskope. The cleanest
way is environment variables for the secrets and a `terraform.tfvars`
file for the non-secret bits.

## 5.1 Configure AWS

{% tabs configure-aws %}
{% tab macOS %}

```bash
aws configure
```

Answer the prompts with the access key ID and secret from step 3.4, and
region `eu-west-1` (or your choice).

Verify:

```bash
aws sts get-caller-identity
```

You should see your IAM user ARN.

{% endtab %}
{% tab Windows %}

```pwsh
aws configure
```

Same prompts. Verify:

```pwsh
aws sts get-caller-identity
```

{% endtab %}
{% endtabs %}

## 5.2 Export Netskope env vars

Terraform reads `TF_VAR_*` env vars into matching variables.

{% tabs export-netskope %}
{% tab macOS %}

```bash
export TF_VAR_netskope_tenant_url="https://yourcompany.goskope.com"
export TF_VAR_netskope_api_token="paste-your-token-here"
```

Add the same two lines to `~/.zshrc` if you want them persistent. **Do
not** commit them to a file in your repo.

{% endtab %}
{% tab Windows %}

```pwsh
$env:TF_VAR_netskope_tenant_url = "https://yourcompany.goskope.com"
$env:TF_VAR_netskope_api_token  = "paste-your-token-here"
```

To make these persist across sessions, use `setx`:

```pwsh
setx TF_VAR_netskope_tenant_url "https://yourcompany.goskope.com"
setx TF_VAR_netskope_api_token  "paste-your-token-here"
```

…then close and reopen your terminal.

{% endtab %}
{% endtabs %}

Next → [Your first publisher](/terraform-netskope-publisher/starter/06-first-publisher/)
