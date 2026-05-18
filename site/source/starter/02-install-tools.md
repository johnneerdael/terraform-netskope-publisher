---
title: 2. Install the tools
date: 2026-05-18
---

> ⏱ ~10 min · Requires admin rights on your laptop.

You need three CLI tools: **terraform**, **awscli**, and **git**.

{% tabs install-tools %}
{% tab macOS %}

Install Homebrew if you don't have it:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Install the three tools:

```bash
brew install terraform awscli git
```

Verify:

```bash
terraform version    # >= 1.7
aws --version        # >= 2.x
git --version
```

{% endtab %}
{% tab Windows %}

> Requires PowerShell 7 or Windows Terminal. The default `cmd.exe` works
> too but copy-paste of multi-line blocks is friendlier in PowerShell.

Install via `winget` (Windows Package Manager, pre-installed on Windows 11):

```pwsh
winget install --id Hashicorp.Terraform -e
winget install --id Amazon.AWSCLI -e
winget install --id Git.Git -e
```

Close and reopen your terminal so the new PATH entries pick up. Verify:

```pwsh
terraform version    # >= 1.7
aws --version        # >= 2.x
git --version
```

{% endtab %}
{% endtabs %}

If any command says "not found", close and reopen your terminal. Still
broken? See the [troubleshooting guide](/terraform-netskope-publisher/admin/operations/troubleshooting/).

Next → [AWS account prep](/terraform-netskope-publisher/starter/03-aws-account-prep/)
