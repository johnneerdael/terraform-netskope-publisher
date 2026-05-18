# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

## [2.1.0] - 2026-05-18

### Added
- New `modules/hyperv` submodule provisioning publishers on Hyper-V via
  the `taliesins/hyperv` provider (only required when the submodule is
  sourced).
  - Master VHDX downloaded once per host from the Netskope public S3
    URL (`https://s3-us-west-2.amazonaws.com/publisher.netskope.com/latest/NetskopePrivateAccessPublisher.vhdx`),
    cached, and cloned per VM.
  - NoCloud seed ISO built on the host via an IMAPI2 PowerShell helper
    (no ADK / `oscdimg.exe` / external tools required).
  - Same DX as the other submodules: `name_prefix`/`replicas`/`names`,
    `tenant_url`/`api_token`, `publisher_names` output.
- New output `metadata_raw` on `modules/cloudinit` (consumed by
  `modules/hyperv` to embed meta-data in a PowerShell `EncodedCommand`).
- `examples/hyperv-single/` runnable example.
- Docs site: new Hyper-V platform page, connectivity section, provider
  matrix entry, architecture row, roadmap update.

### Notes
- Plan-time test omitted for Hyper-V because `mock_provider` cannot
  redirect to the `taliesins/hyperv` registry source. The submodule is
  covered by `terraform validate` + the example, matching how Azure /
  GCP / vSphere are handled.

## [2.0.0] - 2026-05-18

### Changed (BREAKING)
- The multi-platform **root module is removed**. Source one of the
  per-platform submodules instead:
  `github.com/johnneerdael/terraform-netskope-publisher//modules/<platform>?ref=v2.0.0`
  (`<platform>` is one of `aws`, `azure`, `gcp`, `vsphere`).
- Submodule input renames vs. the old root module:
  `netskope_tenant_url` → `tenant_url`, `netskope_api_token` → `api_token`.
  Platform-specific inputs (e.g. `subnet_id`) are now flat instead of
  nested under `aws = { ... }`.

### Added
- Each submodule now accepts `name_prefix`, `replicas`, and `names`
  inputs (parity with v1 root-module ergonomics).
- Each submodule emits a `publisher_names` output for callers that
  need the derived list.

### Why
v1's root module declared all four platform submodules. Terraform
configures every declared provider regardless of `count`, so v1 consumers
were forced to configure `azurerm`/`google`/`vsphere` even when only AWS
was in use. Removing the root module eliminates that requirement.

### Migration
See the README "Migration from v1.x" table.

## [1.1.1] - 2026-05-18

### Fixed
- `modules/registration` was sending `{"publisher_name": "..."}` to
  `POST /api/v2/infrastructure/publishers`, which the NPA API rejects
  with `{"message":"'name'","status":"error"}`. The correct field name
  is `name`. The create response uses `data.id`, not
  `data.publisher_id`. Both fixed.
- Starter Guide: sourced from `//modules/aws` directly to side-step the
  cross-provider configuration leak (the root module pulls in all four
  platform submodules, which forces `azurerm`/`google`/`vsphere`
  providers to be configured even when only AWS is in use).

## [1.1.0] - 2026-05-18

### Added
- Public docs site at https://johnneerdael.github.io/terraform-netskope-publisher/
  (Hexo + Cactus, dark colorscheme).
  - Starter Guide (9 pages, macOS + Windows) from zero Terraform to a
    first AWS publisher Online in the Netskope console.
  - Admin Guides: Concepts, Module reference (root + per-platform),
    How-to (HA, BYO image/networking, multi-region, rotate, delete),
    Operations (state, secrets, upgrades, troubleshooting).
  - Reference: provider compatibility matrix, changelog, roadmap.
- GitHub Actions workflow `.github/workflows/pages.yml` builds and
  deploys to `gh-pages` on every push touching `site/**`.
- README banner linking the docs site.

## [1.0.0] - 2026-05-18

### Changed
- First blessed release with AWS, Azure, GCP, and vSphere all green.
- README rewritten to cover full multi-platform surface.

## [0.4.0] - 2026-05-18

### Added
- vSphere submodule (`modules/vsphere`) cloning Netskope OVA template, cloud-init via `guestinfo`.
- `examples/vsphere-single`.

## [0.3.0] - 2026-05-18

### Added
- GCP submodule (`modules/gcp`) provisioning Compute Engine publishers via `metadata["user-data"]`.
- `examples/gcp-single`.

## [0.2.0] - 2026-05-18

### Added
- Azure submodule (`modules/azure`) provisioning `azurerm_linux_virtual_machine` with `custom_data` cloud-init.
- `examples/azure-ha-pair` showing two-VM deployment.

### Notes
- Plan-time unit tests are AWS-only. `azurerm`/`google`/`vsphere` providers require live credentials at configure time even for `command = plan`, so Azure/GCP/vSphere submodules are covered by `terraform validate` (per module + per example) plus manual integration via the example folders.

## [0.1.0] - 2026-05-18

### Added
- Initial release.
- AWS submodule (`modules/aws`) provisioning EC2 publishers with cloud-init registration.
- Shared `modules/registration` (Netskope API list/create/token) and `modules/cloudinit` (NoCloud user-data + meta-data).
- Root module routing on `var.platform` (only `aws` supported in this release).
- `terraform test` unit suite with mocked `http` and `aws` providers.
