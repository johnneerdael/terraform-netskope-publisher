# Terraform Registry Publication — Design

**Status:** Draft — pending implementation
**Date:** 2026-05-18
**Owner:** John Neerdael
**Repository:** https://github.com/johnneerdael/terraform-netskope-publisher
**Target release:** `v2.1.1`

## 1. Goal

Publish the existing `terraform-netskope-publisher` repository to the
[Terraform Registry](https://registry.terraform.io) so that users can
source the module via:

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.1"
  # ...
}
```

instead of (or alongside) the current GitHub URL form. Cover all five
platform submodules (AWS, Azure, GCP, vSphere, Hyper-V). Existing
GitHub-source consumers must keep working unchanged.

Also: record on the roadmap that a future Go-based
`terraform-provider-netskope` plugin is a possible v3 direction.

## 2. Non-goals (v1 of this work)

- Building the Go provider plugin (separate multi-week project).
- Publishing to OpenTofu's registry (add later if there's demand).
- Module signing (Registry supports it; not required for v1 publication).
- Splitting the repo into per-platform Registry modules (we chose the
  single-repo path during brainstorming).
- Creating or moving the repo to a GitHub organization.

## 3. Registry naming

Repo stays named `terraform-netskope-publisher`. This satisfies the
Registry's required pattern `terraform-<PROVIDER>-<NAME>`:

| Component | Value | Notes |
|---|---|---|
| Prefix | `terraform-` | Required. |
| `<PROVIDER>` | `netskope` | Matches the existing `netskope/netskope` provider on the Registry, even though we don't depend on it. Acceptable per Registry convention. |
| `<NAME>` | `publisher` | What the module produces. |

Registry path becomes
`johnneerdael/publisher/netskope` (namespace = GitHub user, name = the
`<NAME>` portion, provider = the `<PROVIDER>` portion).

## 4. Architecture: documentation-only root + functional submodules

v2 deliberately deleted the multi-platform root module because Terraform
required every declared submodule's provider to be configurable
(cross-provider leak). The Registry, however, expects something at the
root.

**Resolution:** restore the root as a *documentation-only* module —
files exist so the Registry sees a valid landing page, but the root
declares **no** `module "x"` calls and therefore can't reintroduce the
leak.

Root contents after this change:

- `versions.tf` — current content unchanged (already a stub with
  `required_version`).
- `main.tf` — comment-only file pointing readers at `modules/<platform>`.
- `variables.tf` — comment-only file with no `variable` blocks.
- `outputs.tf` — single `supported_platforms` output (purely
  informational, no behavior).
- `README.md` — gets a new "Install via the Terraform Registry" section
  alongside the existing GitHub source guidance.

The Registry's "Submodules" tab surfaces `aws`, `azure`, `gcp`,
`vsphere`, `hyperv` as the actually-usable units.

## 5. Per-submodule README files

The Registry renders each submodule's `README.md` on its page. Today
the submodules don't have one. Add five new files
(`modules/<platform>/README.md`) following this template:

```markdown
# terraform-netskope-publisher — <Platform> submodule

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/<platform>/

Provisions Netskope Private Access Publishers on <Platform>.

## Usage

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/<platform>"
  version = "~> 2.1"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  # <platform-specific inputs>
}
```

See the [common inputs](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/common-inputs/)
and the [<Platform> reference](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/<platform>/)
for the full input table and examples.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.7 |
| <provider> | <pin> |
| hashicorp/http | >= 3.4 |
| hashicorp/cloudinit | >= 2.3 |
```

Per-submodule substitutions:

| Submodule | `<Platform>` | `<platform>` | `<provider>` | `<pin>` |
|---|---|---|---|---|
| `modules/aws` | AWS | aws | `hashicorp/aws` | `~> 5.0` |
| `modules/azure` | Azure | azure | `hashicorp/azurerm` | `~> 4.0` |
| `modules/gcp` | GCP | gcp | `hashicorp/google` | `~> 6.0` |
| `modules/vsphere` | vSphere | vsphere | `vmware/vsphere` | `~> 2.10` |
| `modules/hyperv` | Hyper-V | hyperv | `taliesins/hyperv` | `~> 1.2` |

## 6. Top-level README addition

Insert a new "Install via the Terraform Registry" section immediately
after the existing "Quick start":

```markdown
## Install via the Terraform Registry

This module is published at
[registry.terraform.io/modules/johnneerdael/publisher/netskope](https://registry.terraform.io/modules/johnneerdael/publisher/netskope).

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.1"
  # ...
}
```

Substitute `//modules/aws` with `//modules/azure`, `//modules/gcp`,
`//modules/vsphere`, or `//modules/hyperv` for other platforms. The
GitHub source URL also keeps working.
```

Also add a Registry badge at the very top of the README:

```markdown
[![Terraform Registry](https://img.shields.io/badge/terraform-registry-blueviolet)](https://registry.terraform.io/modules/johnneerdael/publisher/netskope)
```

## 7. CHANGELOG entry

Insert at the top of `## [Unreleased]`:

```markdown
## [2.1.1] - 2026-05-18

### Added
- Module published to the Terraform Registry at
  `johnneerdael/publisher/netskope`. Existing GitHub source URLs
  continue to work.
- Per-submodule `README.md` files (AWS, Azure, GCP, vSphere, Hyper-V)
  that the Registry surfaces on each submodule page.
- Restored documentation-only root module (`main.tf`, `variables.tf`,
  `outputs.tf`) so the Registry has a valid landing page. The root
  declares NO `module "x"` calls — v2's cross-provider-leak fix is
  preserved.

### Notes
- Future Go-based `terraform-provider-netskope` plugin is on the
  roadmap (see Reference → Roadmap on the docs site).
```

## 8. Docs site additions

`site/source/reference/roadmap.md` — append a new section:

```markdown
## Future: Go-based Terraform Provider

A standalone Go provider (`terraform-provider-netskope`) exposing
resources like `netskope_publisher`,
`netskope_publisher_registration_token`, `netskope_private_app`,
`netskope_policy_rule`, etc. would replace the module's `http`-data-source
registration flow with first-class Terraform resources and let users
`terraform plan` diffs against Netskope tenant state. Multi-week
effort; no ETA. Tracking interest via GitHub Issues.
```

Footer `module_version` stays `v2.x` — this is a patch release.

## 9. One-time Registry publish flow (manual, in browser)

1. Sign in at https://registry.terraform.io using the `johnneerdael`
   GitHub OAuth account.
2. Modules → Publish → pick `johnneerdael/terraform-netskope-publisher`.
3. Registry validates: name pattern, public visibility, tag list,
   standard module structure.
4. Registry indexes the highest semver tag (`v2.1.1` after this
   release) as the "current" version and lists every prior `v*.*.*`
   tag in the version dropdown.
5. Registry installs a webhook on the repo so future `git push --tags`
   re-index automatically within minutes.

After publish, verify:

```bash
curl -sI https://registry.terraform.io/modules/johnneerdael/publisher/netskope
curl -sI https://registry.terraform.io/modules/johnneerdael/publisher/netskope/aws
```

Both should return `200`.

## 10. Risks and fallbacks

### Risk: Registry rejects the empty-root structure

If the Registry's validator requires at least one resource, data
source, or non-empty `variable` block at the root:

**Fallback A** — minimal stub: add one `variable "namespace"
{ type = optional(string) }` with no behavior, just so the root has a
documentable interface. The existing `output "supported_platforms"`
gives it an output. Very small change.

**Fallback B** — rename the repo to `terraform-aws-netskope-publisher`
and restore the AWS submodule's contents at the root (AWS is the
documented starter path). Azure/GCP/vSphere/Hyper-V are still
addressed via `//modules/<name>`. Asymmetric but Registry-idiomatic.
Larger change; documented here as the contingency only.

### Risk: Existing GitHub source URLs break

They won't. The Registry publish is purely additive — the GitHub repo
keeps working as a `git::` source, and existing `?ref=vX.Y.Z` consumers
are unaffected.

### Risk: Submodule docs go stale relative to the Hexo docs site

The submodule READMEs intentionally link to the Hexo site for full
guides rather than duplicate content. When a submodule's input shape
changes, we update its README's usage block (Registry surface) AND the
matching `site/source/admin/module/platforms/<platform>.md` page (deep
docs). `site/CONTRIBUTING.md` already documents the latter; add a line
about the former.

## 11. Out of scope (recap)

- Building the Go provider plugin.
- OpenTofu registry cross-publish.
- Module signing.
- Repo rename / split.
- Moving to a GitHub org.

## 12. Rollout summary

1. Land the file changes in §3–§8.
2. Commit, tag `v2.1.1`, push.
3. Manually publish via the Registry UI.
4. Verify the Registry URLs return 200.
5. Add a one-line "Now on the Terraform Registry" banner to the docs
   site home page (`site/source/index.md`).
