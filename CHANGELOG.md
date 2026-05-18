# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.3.0] - 2026-05-19

### Added
- **Script-based installation on stock Ubuntu 22.04 LTS Minimal.**
  `modules/cloudinit` can now download and run Netskope's generic
  `bootstrap.sh` during first boot instead of relying on a pre-baked
  Netskope Publisher image. New common inputs (forwarded by the
  AWS / Azure / GCP submodules):
  - `bootstrap` (bool) — toggle the script install
  - `bootstrap_url` (string) — overridable, defaults to
    `https://s3-us-west-2.amazonaws.com/publisher.netskope.com/latest/generic/bootstrap.sh`
  - `nonat` (bool) — drops `~install_user/resources/.nonat` to enable
    Netskope's No-NAT mode (recommended on GCP due to the 1460-byte MTU)
- **Customisable install user.** `install_user` (default `ubuntu`)
  *replaces* the image's default user when different —
  `system_info.default_user.name` is rewired and the original `ubuntu`
  account is removed by cloud-init (`delete_default_user`, default
  `true`). New flat inputs: `install_user_password` (sensitive,
  plaintext or `install_user_password_is_hash` for a `crypt(3)` hash),
  `install_user_ssh_authorized_keys`.
- **Per-VM netplan override.** New `guest_network_interface` input
  (object with `name`, `dhcp4`, `addresses`, `gateway4`, `nameservers`,
  `mtu`) renders `/etc/netplan/60-cloudinit-override.yaml` and runs
  `netplan apply` before the bootstrap step. Default is `null` —
  cloud-init leaves the image's DHCP setup alone.
- **GCP submodule** now defaults to `bootstrap = true` and
  `nonat = true`. `examples/gcp-single` defaults to the public
  `projects/ubuntu-os-cloud/global/images/family/ubuntu-minimal-2204-lts`
  family.
- **AWS submodule** auto-resolves Canonical's Ubuntu 22.04 LTS Minimal
  AMI (owner `099720109477`, name pattern
  `ubuntu-minimal/images/hvm-ssd*/ubuntu-jammy-22.04-amd64-minimal-*`)
  whenever `bootstrap = true` and `ami_id` is null. The Netskope
  Publisher AMI lookup is skipped in that mode (so callers no longer
  need access to the Netskope marketplace listing).
- **Azure submodule** auto-resolves the Canonical marketplace image
  (`Canonical / 0001-com-ubuntu-minimal-jammy / minimal-22_04-lts-gen2`,
  no `plan {}` block required) whenever `bootstrap = true` and neither
  `image_id` nor `marketplace` is set. `admin_username` now coalesces
  to `install_user` so the Azure admin and the cloud-init install user
  are the same account.

### Changed
- `wizard_path` is now nullable on `modules/{cloudinit,aws,azure,gcp}`.
  When null it derives from `install_user` as
  `/home/<install_user>/npa_publisher_wizard`. The previous static
  default (`/home/ubuntu/npa_publisher_wizard`) still resolves
  identically when `install_user` is left at its default.
- Cloud-init runcmd ordering is now explicit:
  `netplan apply` → optional `userdel -r ubuntu` →
  `chmod 1777 /tmp` → write `~/resources/.nonat` →
  `curl … bootstrap.sh | sudo bash` → `npa_publisher_wizard -token …`,
  with the bootstrap and registration commands both running as
  `install_user` via `su -`. Enrollment no longer hard-codes
  `/home/ubuntu`.
- `package_update: true` removed from the rendered user-data;
  `bootstrap.sh` owns all `apt` activity so cloud-init's apt module
  cannot race against `dpkg` locks.

### Notes
- AWS and Azure pre-baked-image users see **no behavior change**:
  `bootstrap` defaults to `false` on both submodules, and the Netskope
  AMI / marketplace lookup paths are preserved unchanged.
- GCP callers who were pinning a pre-baked Publisher image must now set
  `bootstrap = false` and `nonat = false` explicitly when sourcing the
  module to retain v2.2 behavior.
- Tests added: `aws_bootstrap_mode_uses_canonical_ubuntu_ami`,
  `renders_bootstrap_and_nonat`, `renders_custom_user_replaces_ubuntu`,
  `renders_static_network_override`. Total `terraform test` suite:
  8 runs, all green.

## [2.2.0] - 2026-05-19

### Added
- New `modules/kubernetes` submodule installs the
  [`kubernetes-netskope-publisher`](https://github.com/johnneerdael/kubernetes-netskope-publisher)
  Helm chart from `oci://ghcr.io/johnneerdael/charts` on any K8s
  cluster (EKS / AKS / GKE / OpenShift / vanilla / Kind).
- Two enrollment modes:
  - `token` (default): Terraform owns the publisher record via
    `npa_publisher` + `npa_publisher_token` from our provider, feeds the
    token to the chart through a per-publisher Kubernetes Secret.
  - `api`: chart's container self-registers via the Netskope API on Pod
    start. Suited to HPA / StatefulSet autoscaling.
- DX parity with the other submodules: `name_prefix`, `replicas`,
  `names`, `publisher_names` output.
- `examples/kubernetes-kind/` runnable example targeting a local Kind
  cluster.
- Docs site: new Kubernetes platform page, connectivity section,
  provider matrix entry, architecture row, roadmap update.

### Notes
- `wizard_path` common input is not consumed by `modules/kubernetes`
  (chart image carries the wizard).
- Plan-time test omitted (same `helm`/`kubernetes` provider eager-config
  trap as `azurerm`/`google`/`vsphere`/`hyperv`); covered by
  `terraform validate` + the runnable example.

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
