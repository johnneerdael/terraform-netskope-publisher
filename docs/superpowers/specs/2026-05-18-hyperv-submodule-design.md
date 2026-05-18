# Hyper-V Submodule (`modules/hyperv`) — Design

**Status:** Draft — pending implementation
**Date:** 2026-05-18
**Owner:** John Neerdael
**Repository:** https://github.com/johnneerdael/terraform-netskope-publisher
**Target release:** `v2.1.0`

## 1. Goal

Provision Netskope Private Access Publishers on **Hyper-V** with the same
interface as the four existing platform submodules (`modules/aws`,
`modules/azure`, `modules/gcp`, `modules/vsphere`). Add Hyper-V to the
list of supported platforms in docs, examples, and the roadmap.

## 2. Non-goals (v1 of this submodule)

- HA-pair example (Hyper-V multi-host topology is caller-specific).
- VM upgrade orchestration beyond a documented `force_redownload` + `taint` procedure.
- HTTP/HTTPS proxy support for the host's outbound S3 fetch.
- Live migration / failover cluster placement.
- Dynamic IP discovery guaranteed on first apply (KVP-based, best effort — same caveat as vSphere).

## 3. Provider

`taliesins/hyperv` (the only actively maintained Hyper-V provider on the
Terraform Registry). Pinned `~> 1.2`. Talks to the Hyper-V host via
WinRM.

## 4. Architecture

`modules/hyperv` follows the v2 per-platform-submodule pattern:

- Calls `modules/registration` to get one publisher record + token per
  derived publisher name (same `name_prefix`/`replicas`/`names` logic as
  the other submodules).
- Calls `modules/cloudinit` to render per-publisher user-data and
  NoCloud meta-data.
- For each publisher, materializes three host-side artifacts and one
  VM:
  1. **Master VHDX** (cached on the host, one copy shared across all replicas).
  2. **Per-VM cloned VHD** (`hyperv_vhd`, `source = master`).
  3. **Per-VM NoCloud seed ISO** (built on the host via IMAPI2 PowerShell).
  4. **VM** (`hyperv_machine_instance`) attaching the cloned VHD as the boot disk and the seed ISO as a DVD drive.

Caller declares `provider "hyperv" { user/password/host/... }` at root.
The submodule never reads provider config directly; it accepts a single
`hyperv_winrm_config` object so the `null_resource` `remote-exec` blocks
have what they need.

## 5. Host requirements

Documented in the submodule README and the docs site, not enforced:

- Hyper-V role installed.
- WinRM enabled (HTTPS preferred; HTTP + Basic + CredSSP works for lab).
- PowerShell 5.1+ (built into Windows Server 2016+).
- Outbound HTTPS reachable from the host to:
  - `s3-us-west-2.amazonaws.com` (master VHDX download)
  - the Netskope tenant URL (registration on first boot via cloud-init)
- IMAPI2 COM available (built into Windows Server; nothing to install).

## 6. Inputs

### Required

| Name | Type | Description |
|---|---|---|
| `tenant_url` | string | Netskope tenant URL, e.g. `https://tenant.goskope.com`. |
| `api_token` | string (sensitive) | NPA API token with publisher read/write scope. |
| `vswitch_name` | string | Name of the Hyper-V virtual switch to attach the publisher NIC to. |
| `hyperv_winrm_config` | object | `{ host, user, password (sensitive), port, https, insecure, use_ntlm }`. Mirrors the caller's `provider "hyperv"` config so the `null_resource` provisioners can re-use it. |

### Optional

| Name | Type | Default | Description |
|---|---|---|---|
| `name_prefix` | string | `"npa-publisher"` | Used to derive names when `names` is null. |
| `names` | list(string) | `null` | Explicit publisher names; overrides `name_prefix` + `replicas`. |
| `replicas` | number | `1` | Number to derive. |
| `tags` | map(string) | `{}` | Written into the VM's `notes` field as JSON (Hyper-V has no native tag concept). |
| `wizard_path` | string | `"/home/ubuntu/npa_publisher_wizard"` | On-VM wizard path; same default as every other submodule. |
| `vhdx_source_url` | string | `"https://s3-us-west-2.amazonaws.com/publisher.netskope.com/latest/NetskopePrivateAccessPublisher.vhdx"` | Where to download the master VHDX from. |
| `vhdx_cache_path` | string | `"C:\\hyperv\\netskope\\NetskopePrivateAccessPublisher.vhdx"` | Where on the host to cache the master VHDX. |
| `vhd_dir` | string | `"C:\\hyperv\\netskope\\vhds"` | Per-VM cloned VHD directory on the host. |
| `iso_dir` | string | `"C:\\hyperv\\netskope\\iso"` | Per-VM seed ISO directory on the host. |
| `vm_dir` | string | `"C:\\hyperv\\netskope\\vms"` | Per-VM VM-config directory on the host. |
| `processor_count` | number | `2` | vCPUs. |
| `memory_startup_bytes` | number | `4294967296` | 4 GiB. |
| `dynamic_memory` | bool | `false` | Publishers benefit from fixed memory. |
| `generation` | number | `2` | Gen 2 = UEFI; required for the Netskope VHDX. |
| `enable_secure_boot` | string | `"Off"` | Linux VMs on Gen 2 → Secure Boot off. |
| `vlan_id` | number | `null` | Optional VLAN tag on the NIC. |
| `force_redownload` | bool | `false` | Re-fetch the master VHDX even if cached (use for upgrades). |

## 7. Outputs

Parity with the other submodules.

```hcl
output "publishers" {
  sensitive = true
  # Map keyed by publisher name:
  #   { publisher_id, vm_id, private_ip, public_ip = null, registration_token }
}

output "publisher_names" {
  # Derived list (useful when name_prefix + replicas was used).
}

output "vm_ids" {
  # List of hyperv_machine_instance IDs.
}

output "seed_iso_paths_by_name" {
  # Per-publisher ISO path on the host (for audit / re-attach).
}
```

`private_ip` may be `null` on first apply (Hyper-V Integration Services
+ KVP reports it asynchronously). Same caveat as the vSphere submodule.

## 8. Internal resources

### 8.1 Master VHDX cache (singleton)

```hcl
resource "null_resource" "fetch_master_vhdx" {
  triggers = {
    url   = var.vhdx_source_url
    path  = var.vhdx_cache_path
    force = var.force_redownload ? timestamp() : "stable"
  }

  provisioner "remote-exec" {
    connection { … winrm from var.hyperv_winrm_config … }
    inline = [
      "powershell -NoProfile -ExecutionPolicy Bypass -Command \"<download script>\""
    ]
  }
}
```

PowerShell download script:
- Creates `$dir = Split-Path $path -Parent` if missing.
- Skips download when `Test-Path $path` and `$force -ne $true`.
- Otherwise: `[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri $url -OutFile $path`.

### 8.2 Per-VM cloned VHD

```hcl
resource "hyperv_vhd" "publisher" {
  for_each   = toset(local.publisher_names)
  path       = "${var.vhd_dir}\\${each.key}.vhdx"
  source     = var.vhdx_cache_path
  depends_on = [null_resource.fetch_master_vhdx]
}
```

### 8.3 Per-VM NoCloud seed ISO

```hcl
resource "null_resource" "build_seed_iso" {
  for_each = toset(local.publisher_names)

  triggers = {
    user_data = module.cloudinit.userdata_raw[each.key]
    meta_data = module.cloudinit.metadata_raw[each.key]
    path      = "${var.iso_dir}\\${each.key}-seed.iso"
  }

  provisioner "remote-exec" {
    connection { … winrm … }
    inline = [
      # `<base64-encoded-PS-command>` carries both the ISO build invocation
      # AND the (base64-encoded) user-data + meta-data strings, so we
      # don't need any file-transfer mechanism over WinRM.
      "powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand <base64>"
    ]
  }
}
```

The PowerShell helper `modules/hyperv/scripts/Build-NoCloudIso.ps1`
(shipped in the submodule) authors an ISO9660+Joliet image with volume
label `CIDATA` using `IMAPI2FS.MsftFileSystemImage` COM. The volume
label is mandatory — cloud-init's NoCloud datasource looks for `CIDATA`
specifically.

### 8.4 VM

```hcl
resource "hyperv_machine_instance" "publisher" {
  for_each = toset(local.publisher_names)

  name                 = each.key
  path                 = "${var.vm_dir}\\${each.key}"
  generation           = var.generation
  processor_count      = var.processor_count
  memory_startup_bytes = var.memory_startup_bytes
  dynamic_memory       = var.dynamic_memory
  notes                = jsonencode(var.tags)

  vm_firmware {
    enable_secure_boot = var.enable_secure_boot
  }

  hard_disk_drives {
    controller_type     = "Scsi"
    controller_number   = 0
    controller_location = 0
    path                = hyperv_vhd.publisher[each.key].path
  }

  dvd_drives {
    controller_number   = 0
    controller_location = 1
    path                = "${var.iso_dir}\\${each.key}-seed.iso"
  }

  network_adaptors {
    name        = "eth0"
    switch_name = var.vswitch_name
    vlan_access = var.vlan_id == null ? null : var.vlan_id
  }

  depends_on = [
    hyperv_vhd.publisher,
    null_resource.build_seed_iso,
  ]
}
```

## 9. Required change in `modules/cloudinit`

Add a `metadata_raw` output (currently it only exposes `metadata_b64`).
The Hyper-V submodule needs the raw string to base64-encode into the
PowerShell command line that builds the ISO.

```hcl
# New output to add:
output "metadata_raw" {
  description = "Map of publisher name => rendered NoCloud meta-data (string)."
  value       = local.metadata
  # not sensitive — meta-data only contains the publisher name
}
```

One-line addition; nothing in the existing submodules consumes it, so no
back-compat concern.

## 10. Update flow / known operational quirks

- **Changing `user_data` / `wizard_path`**: the seed-ISO `triggers`
  re-fire, ISO is rebuilt on the host. The VM itself does NOT
  automatically reboot — user runs
  `terraform taint 'module.publisher.hyperv_machine_instance.publisher["<name>"]'`
  + `apply` to pick up the new ISO contents. Documented in the submodule's
  Caveats section.
- **Master VHDX upgrade**: set `force_redownload = true`, apply, then
  `terraform taint` each VHD + VM. Differencing-disk semantics make this
  a multi-step dance — documented in `admin/operations/upgrading-software.md`
  with Hyper-V-specific notes.
- **Private IP `null` on first apply**: re-run `terraform refresh` after
  the VM has booted and Integration Services reports the address via
  KVP. Same as vSphere.

## 11. Testing

### Static
- `terraform fmt -check` and `terraform validate` from `modules/hyperv/`.

### Unit (`terraform test`, mocked providers)
- `tests/hyperv_plan.tftest.hcl`:
  - `mock_provider "hyperv"`, `mock_provider "http"`.
  - Mock `data.http.list` / `create` / `token` like the AWS test.
  - Run `command = plan`.
  - Assert: 1 master-VHDX `null_resource`, `replicas` cloned VHDs,
    `replicas` seed-ISO `null_resource`s, `replicas`
    `hyperv_machine_instance`s.
  - Assert each seed-ISO `triggers.user_data` contains the wizard path
    (proves the cloudinit→hyperv plumbing works).

### Integration
- Manual via `examples/hyperv-single/`. Not run in CI.

### PowerShell helper sanity
- Inline self-test instructions in the `Build-NoCloudIso.ps1` header
  comment: build a test ISO, mount with `Mount-DiskImage`, verify the
  volume label is `CIDATA` and `user-data` + `meta-data` files are
  present.

## 12. Example

`examples/hyperv-single/`:

```hcl
terraform {
  required_version = ">= 1.7"
  required_providers {
    hyperv    = { source = "taliesins/hyperv", version = "~> 1.2" }
    http      = { source = "hashicorp/http",   version = ">= 3.4" }
    cloudinit = { source = "hashicorp/cloudinit", version = ">= 2.3" }
  }
}

provider "hyperv" {
  user            = var.hyperv_user
  password        = var.hyperv_password
  host            = var.hyperv_host
  port            = 5986
  https           = true
  insecure        = true     # lab; flip for production
  use_ntlm        = true
  script_path     = "C:/Temp/terraform_%RAND%.cmd"
  timeout         = "30s"
}

module "publisher" {
  source = "../../modules/hyperv"

  name_prefix = "demo-hv"
  replicas    = 1

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  vswitch_name = var.vswitch_name

  hyperv_winrm_config = {
    host     = var.hyperv_host
    user     = var.hyperv_user
    password = var.hyperv_password
    port     = 5986
    https    = true
    insecure = true
    use_ntlm = true
  }
}

output "publishers" {
  value     = module.publisher.publishers
  sensitive = true
}
```

## 13. Documentation updates

- New: `site/source/admin/module/platforms/hyperv.md` (standard
  Inputs / Minimal / Full / Outputs / Caveats / WinRM bootstrap appendix).
- Modify: `site/source/admin/module/index.md` — add Hyper-V link.
- Modify: `site/source/admin/index.md` — add Hyper-V link.
- Modify: `site/source/admin/concepts/architecture-overview.md` — add
  `modules/hyperv` row to "What lives where".
- Modify: `site/source/admin/concepts/connectivity.md` — add Hyper-V
  section (vswitch on external network; host firewall outbound 443; no
  inbound).
- Modify: `site/source/reference/provider-matrix.md` — add
  `taliesins/hyperv ~> 1.2` row.
- Modify: `site/source/reference/roadmap.md` — move Hyper-V out of
  "Additional platforms".
- Modify: `README.md` (repo) — list Hyper-V in supported platforms +
  `//modules/hyperv` in alt-platform note.

## 14. Release

- Tag `v2.1.0` (minor — additive).
- `CHANGELOG.md` entry under `## [2.1.0]` listing: new
  `modules/hyperv`, `taliesins/hyperv ~> 1.2` provider requirement
  (only when used), S3 default download URL, IMAPI2 seed-ISO build,
  `metadata_raw` output added to `modules/cloudinit`.

## 15. Migration / impact on existing users

None. All four existing submodules are untouched. The cloudinit
submodule gains a new output that nobody currently consumes. No
breaking change.
