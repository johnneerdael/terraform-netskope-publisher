# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-18

### Added
- Initial release.
- AWS submodule (`modules/aws`) provisioning EC2 publishers with cloud-init registration.
- Shared `modules/registration` (Netskope API list/create/token) and `modules/cloudinit` (NoCloud user-data + meta-data).
- Root module routing on `var.platform` (only `aws` supported in this release).
- `terraform test` unit suite with mocked `http` and `aws` providers.
