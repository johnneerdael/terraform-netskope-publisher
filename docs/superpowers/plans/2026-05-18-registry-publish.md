# Terraform Registry Publication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `terraform-netskope-publisher` consumable from the Terraform Registry at `johnneerdael/publisher/netskope` while preserving v2's per-platform-submodule architecture and the existing GitHub source URLs.

**Architecture:** Restore a documentation-only root (`main.tf`, `variables.tf`, `outputs.tf` with no `module "x"` calls) so the Registry has a valid landing page without re-introducing the v1 cross-provider-leak. Add per-submodule `README.md` files so the Registry surfaces each submodule cleanly. Tag `v2.1.1` and click "Publish" on the Registry UI.

**Tech Stack:** No new dependencies. Terraform 1.7+ (unchanged). Hexo docs site (unchanged) gets one new roadmap section + home-page banner.

**Spec:** `docs/superpowers/specs/2026-05-18-registry-publish-design.md`

**Working directory:** `/Users/jneerdael/Scripts/terraform-netskope-publisher`. Currently on `main` at `v2.1.0`. Direct-to-main per established pattern.

---

## Task 1: Restore documentation-only root

Bring back the three root `.tf` files we deleted in v2.0.0, but with **no** `module "x"` calls — the Registry needs a root to publish but our architecture forbids the root from referencing submodules.

**Files:**
- Modify: `main.tf` (create)
- Modify: `variables.tf` (create)
- Modify: `outputs.tf` (create)

(All three were deleted in v2.0.0 commit `ec98a8a`. We're not reverting that commit — we're adding new, intentionally-empty files.)

- [ ] **Step 1: Create `main.tf`**

```hcl
# This module is a namespace. The usable code lives under modules/<platform>.
# Source the per-platform submodule that matches your target:
#
#   module "publisher" {
#     source  = "johnneerdael/publisher/netskope//modules/aws"  # or azure | gcp | vsphere | hyperv
#     version = "~> 2.1"
#     # ...
#   }
#
# Full guides: https://johnneerdael.github.io/terraform-netskope-publisher/
```

- [ ] **Step 2: Create `variables.tf`**

```hcl
# Intentionally empty. This module's root is a namespace; all configurable
# inputs live on the per-platform submodules under modules/<platform>.
```

- [ ] **Step 3: Create `outputs.tf`**

```hcl
output "supported_platforms" {
  description = "Platforms this module ships submodules for. Informational only."
  value       = ["aws", "azure", "gcp", "vsphere", "hyperv"]
}
```

- [ ] **Step 4: Validate the root still inits and validates**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher
rm -rf .terraform .terraform.lock.hcl
terraform init -backend=false 2>&1 | tail -3
terraform validate 2>&1 | tail -3
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 5: Run the test suite (sanity check — no test references root)**

```bash
terraform test 2>&1 | tail -5
```

Expected: `Success! 4 passed, 0 failed.`

- [ ] **Step 6: Commit**

```bash
terraform fmt -recursive
git add main.tf variables.tf outputs.tf
git commit -m "feat: restore documentation-only root for Terraform Registry publishing"
git push
```

---

## Task 2: Per-submodule README files

The Registry renders each submodule's `README.md` on its page. Five files, one per platform, all from the same template.

**Files:**
- Create: `modules/aws/README.md`
- Create: `modules/azure/README.md`
- Create: `modules/gcp/README.md`
- Create: `modules/vsphere/README.md`
- Create: `modules/hyperv/README.md`

- [ ] **Step 1: Create `modules/aws/README.md`**

````markdown
# terraform-netskope-publisher — AWS submodule

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/aws/

Provisions Netskope Private Access Publishers on AWS.

## Usage

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/aws"
  version = "~> 2.1"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = "subnet-..."
  security_group_ids = ["sg-..."]
  key_name           = "my-key"
}
```

See the [common inputs](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/common-inputs/)
and the [AWS reference](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/aws/)
for the full input table and examples.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.7 |
| hashicorp/aws | ~> 5.0 |
| hashicorp/http | >= 3.4 |
| hashicorp/cloudinit | >= 2.3 |
````

- [ ] **Step 2: Create `modules/azure/README.md`**

````markdown
# terraform-netskope-publisher — Azure submodule

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/azure/

Provisions Netskope Private Access Publishers on Azure.

## Usage

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/azure"
  version = "~> 2.1"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  resource_group_name  = "rg-npa"
  location             = "westeurope"
  subnet_id            = "/subscriptions/.../subnets/sn"
  admin_ssh_public_key = file("~/.ssh/id_rsa.pub")
  image_id             = "/subscriptions/.../Microsoft.Compute/images/netskope-publisher"
}
```

See the [common inputs](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/common-inputs/)
and the [Azure reference](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/azure/)
for the full input table and examples.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.7 |
| hashicorp/azurerm | ~> 4.0 |
| hashicorp/http | >= 3.4 |
| hashicorp/cloudinit | >= 2.3 |
````

- [ ] **Step 3: Create `modules/gcp/README.md`**

````markdown
# terraform-netskope-publisher — GCP submodule

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/gcp/

Provisions Netskope Private Access Publishers on GCP.

## Usage

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/gcp"
  version = "~> 2.1"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  project    = "my-gcp-project"
  zone       = "europe-west4-a"
  network    = "default"
  subnetwork = "default"
  image      = "projects/my-gcp-project/global/images/netskope-publisher"
}
```

See the [common inputs](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/common-inputs/)
and the [GCP reference](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/gcp/)
for the full input table and examples.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.7 |
| hashicorp/google | ~> 6.0 |
| hashicorp/http | >= 3.4 |
| hashicorp/cloudinit | >= 2.3 |
````

- [ ] **Step 4: Create `modules/vsphere/README.md`**

````markdown
# terraform-netskope-publisher — vSphere submodule

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/vsphere/

Provisions Netskope Private Access Publishers on VMware vSphere.

## Usage

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/vsphere"
  version = "~> 2.1"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  datacenter    = "dc1"
  cluster       = "cluster1"
  datastore     = "ds1"
  network_name  = "vm-net"
  template_name = "netskope-publisher-template"
}
```

See the [common inputs](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/common-inputs/)
and the [vSphere reference](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/vsphere/)
for the full input table and examples.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.7 |
| vmware/vsphere | ~> 2.10 |
| hashicorp/http | >= 3.4 |
| hashicorp/cloudinit | >= 2.3 |
````

- [ ] **Step 5: Create `modules/hyperv/README.md`**

````markdown
# terraform-netskope-publisher — Hyper-V submodule

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/hyperv/

Provisions Netskope Private Access Publishers on Microsoft Hyper-V.

## Usage

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/hyperv"
  version = "~> 2.1"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  vswitch_name = "External vSwitch"

  hyperv_winrm_config = {
    host     = "hyperv01.lab.local"
    user     = "Administrator"
    password = var.hyperv_password
  }
}
```

See the [common inputs](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/common-inputs/)
and the [Hyper-V reference](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/hyperv/)
for the full input table and examples.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.7 |
| taliesins/hyperv | ~> 1.2 |
| hashicorp/http | >= 3.4 |
| hashicorp/cloudinit | >= 2.3 |
````

- [ ] **Step 6: Commit**

```bash
git add modules/aws/README.md modules/azure/README.md modules/gcp/README.md modules/vsphere/README.md modules/hyperv/README.md
git commit -m "docs(modules): add per-submodule READMEs for Terraform Registry"
git push
```

---

## Task 3: Top-level README + roadmap addition

**Files:**
- Modify: `README.md`
- Modify: `site/source/reference/roadmap.md`

- [ ] **Step 1: Add Registry badge to the very top of `README.md`**

Insert this as the first line of `README.md` (above the existing `# terraform-netskope-publisher` heading):

```markdown
[![Terraform Registry](https://img.shields.io/badge/terraform-registry-blueviolet)](https://registry.terraform.io/modules/johnneerdael/publisher/netskope)

```

(blank line after the badge, before the heading)

- [ ] **Step 2: Insert "Install via the Terraform Registry" section in `README.md`**

Find the existing `## Quick start` section (the one with the GitHub-source HCL example). Immediately AFTER the closing of its ```` ``` ```` block AND its follow-on paragraph (`"For other platforms, source the matching submodule..."`), insert this new section:

````markdown
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
````

- [ ] **Step 3: Append the provider roadmap section to `site/source/reference/roadmap.md`**

Append at the bottom of the file (after the "Site" section):

```markdown

## Future: Go-based Terraform Provider

A standalone Go provider (`terraform-provider-netskope`) exposing
resources like `netskope_publisher`,
`netskope_publisher_registration_token`, `netskope_private_app`,
`netskope_policy_rule`, etc. would replace the module's
`http`-data-source registration flow with first-class Terraform
resources and let users `terraform plan` diffs against Netskope tenant
state. Multi-week effort; no ETA. Tracking interest via GitHub Issues.
```

- [ ] **Step 4: Rebuild the docs site locally to verify roadmap renders**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher/site
./node_modules/.bin/hexo generate 2>&1 | tail -3
grep -c "Future: Go-based Terraform Provider" public/reference/roadmap/index.html
cd ..
```

Expected: `INFO  N files generated`, and the `grep -c` returns `1`.

- [ ] **Step 5: Commit**

```bash
git add README.md site/source/reference/roadmap.md
git commit -m "docs: README Registry banner + Go provider on the roadmap"
git push
```

---

## Task 4: CHANGELOG entry + `v2.1.1` tag

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add `v2.1.1` to `CHANGELOG.md`**

In `CHANGELOG.md`, insert immediately under `## [Unreleased]`:

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

- [ ] **Step 2: Commit and tag**

```bash
git add CHANGELOG.md
git commit -m "docs: CHANGELOG entry for v2.1.1; release v2.1.1"
git tag -a v2.1.1 -m "v2.1.1 — Terraform Registry publication"
git push && git push --tags
```

---

## Task 5: Manual Registry publish (browser)

This task isn't scripted — it's a one-time UI click-through. Document the exact steps so anyone repeating this for a fork can follow.

**Files:** none.

- [ ] **Step 1: Open the Registry in a browser**

Go to https://registry.terraform.io.

- [ ] **Step 2: Sign in**

Click "Sign in" → "GitHub". Authorize the Terraform Registry app for the `johnneerdael` account.

- [ ] **Step 3: Publish the module**

1. Click your avatar → **Publish** → **Module**.
2. The Registry lists your accessible GitHub repos that match
   `terraform-<provider>-<name>`. Pick `terraform-netskope-publisher`.
3. Tick the agreement checkbox.
4. Click **Publish module**.

- [ ] **Step 4: Wait for indexing (~1–2 min)**

The Registry will:
- Validate repo name + tags + structure.
- Index all `v*.*.*` tags (currently `v0.1.0` through `v2.1.1`).
- Walk `modules/*/` and surface AWS / Azure / GCP / vSphere / Hyper-V as submodules.
- Render the root `README.md` as the landing page.
- Install a GitHub webhook for future tag re-indexing.

- [ ] **Step 5: Verify the URLs from a terminal**

```bash
curl -sI https://registry.terraform.io/modules/johnneerdael/publisher/netskope
curl -sI https://registry.terraform.io/modules/johnneerdael/publisher/netskope/aws
```

Expected: both return `200`.

If validation rejects the empty root with an error like "root module has no inputs or outputs", fall back to **Spec §10 Fallback A** — add a single `variable "namespace" { type = optional(string, "") }` to the root `variables.tf`, commit, push, re-tag `v2.1.2`, and retry the Publish step.

If validation rejects the repo name itself, fall back to **Spec §10 Fallback B** — much larger change; stop and re-brainstorm.

---

## Task 6: Post-publish docs banner

Once the Registry URLs return 200, advertise the Registry on the docs-site home page.

**Files:**
- Modify: `site/source/index.md`

- [ ] **Step 1: Add a Registry badge to `site/source/index.md`**

Insert as the second line (immediately under the frontmatter `---`):

```markdown
> 📦 **Now on the Terraform Registry:** [`johnneerdael/publisher/netskope`](https://registry.terraform.io/modules/johnneerdael/publisher/netskope)

```

(blank line after, before the existing intro paragraph)

- [ ] **Step 2: Rebuild the docs site locally**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher/site
./node_modules/.bin/hexo clean 2>&1 | tail -1
./node_modules/.bin/hexo generate 2>&1 | tail -3
grep -c "Now on the Terraform Registry" public/index.html
cd ..
```

Expected: build succeeds, `grep -c` returns `1`.

- [ ] **Step 3: Commit and push**

```bash
git add site/source/index.md
git commit -m "docs(site): home-page banner for Terraform Registry"
git push
```

The GitHub Actions Pages workflow will deploy the updated home page automatically.

---

## Self-review notes

**Spec coverage:**
- §3 Registry naming → Task 1 + 4 (no rename needed).
- §4 Documentation-only root → Task 1.
- §5 Per-submodule READMEs → Task 2.
- §6 Top-level README banner + badge → Task 3.
- §7 CHANGELOG entry → Task 4.
- §8 Docs site roadmap + version footer → Task 3 (roadmap), version footer stays `v2.x` (no change needed).
- §9 Registry publish flow → Task 5.
- §10 Fallbacks → Task 5 Step 5 documents the trigger and the response.
- §12 Rollout summary → Tasks 1 → 6 in stated order.

**Intentional omissions:**
- No code change to the submodules themselves. Existing tests cover them.
- Docs site `module_version` not bumped — this is a patch release, footer wording stays accurate.
- The Registry publish (Task 5) is human-in-the-loop because the Registry has no public CLI for first-time module registration; the rest of the plan is fully scriptable.
