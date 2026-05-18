# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
