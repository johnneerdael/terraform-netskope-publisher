# Docs Site (Hexo + Cactus, Dark) — Design

**Status:** Draft — pending implementation
**Date:** 2026-05-18
**Owner:** John Neerdael
**Repository:** https://github.com/johnneerdael/terraform-netskope-publisher (existing)
**Public URL:** https://johnneerdael.github.io/terraform-netskope-publisher/

## 1. Goal

Ship a public docs site for `terraform-netskope-publisher` that serves two
distinct audiences:

1. **Starter Guide** — a brand-new user (zero Terraform experience) on macOS or
   Windows can follow it linearly and end up with their first AWS publisher
   showing **Online** in the Netskope admin console.
2. **Admin Guides** — a Terraform-fluent operator gets full reference and
   how-to coverage for all four supported platforms (AWS, Azure, GCP, vSphere).

Site uses **Hexo** with the **Cactus** theme, **dark colorscheme by default**.

## 2. Non-goals (v1)

- Versioned docs (v1.0 vs v1.1 switcher). Site reflects the latest release; one
  set of pages, with an "applies to v1.x" footnote driven by config.
- Search, i18n, PDF export, comments, analytics.
- Generated-from-source input tables (e.g., `terraform-docs`). Reference
  tables are hand-written in v1.
- Starter content for Azure / GCP / vSphere. Starter is AWS-only; Admin
  covers all four.

## 3. Hosting and pipeline

### 3.1 Repo layout (additions)

```
terraform-netskope-publisher/
├── (existing module files unchanged)
├── site/                          # Hexo source (NOT generated output)
│   ├── _config.yml
│   ├── _config.cactus.yml         # theme overrides (dark, colors, nav)
│   ├── package.json
│   ├── package-lock.json
│   ├── source/
│   │   ├── _posts/                # unused
│   │   ├── starter/               # Starter guide pages (Section 5)
│   │   ├── admin/                 # Admin guides — concepts/module/how-to/operations (Section 6)
│   │   ├── reference/             # Project-wide reference — matrix/changelog/roadmap (Section 6)
│   │   ├── _data/                 # nav data files
│   │   └── images/
│   ├── scaffolds/
│   ├── CONTRIBUTING.md
│   ├── README.md                  # local dev quickstart
│   └── .gitignore                 # node_modules/, public/, db.json, .deploy_git/
└── .github/workflows/pages.yml    # build + deploy
```

### 3.2 Deployment

GitHub Actions workflow `.github/workflows/pages.yml`:

- **Trigger:** `push` to `main` filtered to paths `site/**` and
  `.github/workflows/pages.yml`. Also `workflow_dispatch`.
- **Permissions:** `contents: write` on `GITHUB_TOKEN` (required by
  `peaceiris/actions-gh-pages`).
- **Steps:**
  1. `actions/checkout@v4`
  2. `actions/setup-node@v4` (Node 20, `cache: 'npm'`, `cache-dependency-path: site/package-lock.json`)
  3. `npm ci` in `site/`
  4. `npx hexo generate` in `site/`
  5. `peaceiris/actions-gh-pages@v3` with `publish_dir: site/public` and
     `publish_branch: gh-pages`, `force_orphan: true`.

After the first successful run, **manual one-time GitHub Pages config**:
- Settings → Pages → Source = "Deploy from a branch", Branch = `gh-pages`,
  Folder = `/ (root)`.

### 3.3 Public URL

`https://johnneerdael.github.io/terraform-netskope-publisher/`

Hexo `_config.yml` must set:
```yaml
url:  https://johnneerdael.github.io/terraform-netskope-publisher
root: /terraform-netskope-publisher/
```

## 4. Hexo configuration

### 4.1 `site/_config.yml`

```yaml
title:       terraform-netskope-publisher
subtitle:    Provision Netskope Publishers on AWS, Azure, GCP, vSphere
description: One Terraform module, four clouds, API-driven registration.
author:      John Neerdael
url:         https://johnneerdael.github.io/terraform-netskope-publisher
root:        /terraform-netskope-publisher/
permalink:   :title/
new_post_name: :title.md
default_layout: page    # docs site, not blog
theme: cactus
```

### 4.2 `site/_config.cactus.yml`

```yaml
colorscheme: dark
nav:
  home:    /
  starter: /starter/
  admin:   /admin/
  reference: /reference/
  github:  https://github.com/johnneerdael/terraform-netskope-publisher
social_links:
  github: johnneerdael
projects:
  enabled: false
posts_overview:
  show_all_posts: false
copyright:
  start_year: 2026
  end_year:   2026
```

### 4.3 `site/package.json`

```json
{
  "name": "terraform-netskope-publisher-site",
  "private": true,
  "scripts": {
    "build": "hexo generate",
    "serve": "hexo server",
    "clean": "hexo clean"
  },
  "dependencies": {
    "hexo":                  "^7.3.0",
    "hexo-theme-cactus":     "^1.0.0",
    "hexo-renderer-marked":  "^6.3.0",
    "hexo-tag-tabs":         "^1.0.0",
    "hexo-toc":              "^1.0.0"
  }
}
```

`hexo-tag-tabs` provides the `{% tabs %}` shortcode used for macOS/Windows
code-block switching. `hexo-toc` renders in-page tables of contents for long
reference pages.

### 4.4 Navigation strategy

Cactus has no built-in docs sidebar. Top nav holds five entries: Home,
Starter, Admin, Reference, GitHub. Each section's `index.md` landing page
renders an explicit hand-maintained list of its child pages. Acceptable for
~30 pages; we revisit if scope grows.

## 5. Content — Starter Guide

Single linear track ending at "publisher Online in Netskope console". One page
per step (deep-linkable, easy to edit).

```
source/starter/
├── index.md
├── 01-what-youll-build.md       overview + screenshot of end state
├── 02-install-tools.md          macOS (Homebrew) + Windows (winget); tabs
├── 03-aws-account-prep.md       VPC/subnet/SG checklist, key pair, IAM user
├── 04-netskope-tenant-prep.md   tenant URL, NPA API token scopes
├── 05-configure-shell.md        aws configure; NETSKOPE_* env vars / tfvars
├── 06-first-publisher.md        minimal main.tf consuming the registry module
├── 07-verify-online.md          Netskope console walk-through with screenshot
├── 08-tear-down.md              terraform destroy + what NOT to delete
└── 09-next-steps.md             link into Admin; HA pair; other clouds
```

Conventions per page:
- A boxed callout at the top with prerequisites + estimated time.
- Every command block is explicit about shell (`bash` / `pwsh` / `cmd`).
- Every external UI action has a one-line "what to expect" and a screenshot
  (under `source/images/starter/`).

## 6. Content — Admin Guides

Organized by what users look up, not by file structure.

Admin guides live under `source/admin/`. A separate top-level
`source/reference/` holds project-wide reference material (provider matrix,
changelog, roadmap) so the top-nav entry `Reference` resolves cleanly.

```
source/admin/
├── index.md
│
├── concepts/
│   ├── architecture-overview.md
│   ├── registration-flow.md
│   └── naming-replicas-foreach.md
│
├── module/                        # module input/output reference
│   ├── root-inputs.md
│   ├── root-outputs.md
│   └── platforms/
│       ├── aws.md
│       ├── azure.md
│       ├── gcp.md
│       └── vsphere.md
│
├── how-to/
│   ├── ha-pair.md
│   ├── byo-image.md
│   ├── rotate-token.md            # documents the deferred feature + workaround
│   ├── delete-publisher.md        # documents the deferred feature + workaround
│   ├── multi-region.md
│   └── byo-networking.md
│
└── operations/
    ├── state-management.md
    ├── secret-handling.md
    ├── upgrading-software.md
    └── troubleshooting.md

source/reference/                  # project-wide reference (top-nav target)
├── index.md
├── provider-matrix.md
├── changelog.md                   # includes the repo CHANGELOG.md via hexo
└── roadmap.md                     # deferred items
```

Per-platform input pages are intentionally separate files so individual
platform updates don't churn a monolithic page.

## 7. Cross-linking and content provenance

- **Module README** gets one new line near the top:
  *"📖 Full guides: https://johnneerdael.github.io/terraform-netskope-publisher/"*
- **Site footer** links to the GitHub repo and to the Terraform Registry page
  for the module.
- **Changelog page** renders the repo's `CHANGELOG.md` via Hexo's
  `include_code` (or a tiny generator script if `include_code` doesn't render
  Markdown cleanly — picked during implementation).
- **Provider matrix** values are hand-copied from `versions.tf` and each
  submodule's `versions.tf`. When provider pins change in code, the matrix
  page is updated in the same PR; `site/CONTRIBUTING.md` documents this.

## 8. Versioning model

The site shows **only the latest module release**. A single `module_version:
v1.x` key in `_config.yml` is interpolated into a page footer ("Applies to
v1.x").

Historical or per-version doc browsing is not built in v1. If a breaking v2
ships, the decision is revisited (likely with a switcher built on git tags
+ Hexo's `path` config, or a move to a docs framework that supports
versioning natively).

## 9. Out-of-scope (v1)

- Search (could add `hexo-generator-search` + a small JS UI later)
- i18n / multi-language
- PDF export
- Disqus / comments
- Plausible / GA analytics
- Dead-link checker in CI (defer to follow-up — add `linkinator` step)
- Generated reference tables from `.tf` source

## 10. Rollout plan

1. **Scaffold:** add `site/` with Hexo + Cactus, single placeholder page;
   wire up `.github/workflows/pages.yml`; verify first green deploy and that
   `https://johnneerdael.github.io/terraform-netskope-publisher/` resolves.
2. **Starter guide:** author the nine pages; re-deploy.
3. **Admin guides:** author bucket by bucket — Concepts → Module reference →
   Per-platform reference → How-tos → Operations → Reference. Re-deploy at
   the end of each bucket so progress is visible publicly.
4. **Cross-link & release:** add the README banner line and tag the module
   **v1.1.0** when the site is fully populated. CHANGELOG entry calls out
   the new docs site.
