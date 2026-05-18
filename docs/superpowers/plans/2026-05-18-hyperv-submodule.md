# Hyper-V Submodule (`modules/hyperv`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `modules/hyperv` submodule that provisions Netskope Private Access Publishers on Hyper-V with the same interface (`name_prefix`/`replicas`/`names`, `tenant_url`/`api_token`) as the other four platform submodules.

**Architecture:** `null_resource` + `remote-exec` over WinRM drive PowerShell on the Hyper-V host to (a) cache the master VHDX from S3 and (b) build per-VM NoCloud seed ISOs via IMAPI2 COM. `hyperv_vhd` clones per-VM VHDs from the master; `hyperv_machine_instance` creates each VM with the cloned VHD + seed ISO attached. Cloud-init's NoCloud datasource reads the ISO on first boot and runs the registration wizard.

**Tech Stack:** Existing stack + `taliesins/hyperv ~> 1.2` (only loaded when this submodule is sourced). Host needs Windows Server 2016+ with Hyper-V + WinRM + PowerShell 5.1.

**Spec:** `docs/superpowers/specs/2026-05-18-hyperv-submodule-design.md`

**Working directory:** `/Users/jneerdael/Scripts/terraform-netskope-publisher`. Currently on `main` at `v2.0.0`. Direct-to-main per established pattern.

---

## Task 1: Add `metadata_raw` output to `modules/cloudinit`

Hyper-V needs the raw NoCloud meta-data string (not base64) so it can be embedded in a PowerShell `EncodedCommand`. The existing submodule only emits `metadata_b64`.

**Files:**
- Modify: `modules/cloudinit/outputs.tf`

- [ ] **Step 1: Add `metadata_raw` to `modules/cloudinit/outputs.tf`**

Append this block to the bottom of `modules/cloudinit/outputs.tf` (leave the three existing outputs untouched):

```hcl
output "metadata_raw" {
  description = "Map of publisher name => rendered NoCloud meta-data (string)."
  value       = nonsensitive(local.metadata)
}
```

`nonsensitive(...)` mirrors how `metadata_b64` is exposed today (meta-data only contains the publisher name, which isn't a secret).

- [ ] **Step 2: Verify tests still pass**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher
terraform fmt -recursive
terraform test 2>&1 | tail -5
```

Expected: `Success! 4 passed, 0 failed.` The existing `cloudinit.tftest.hcl` doesn't reference `metadata_raw` but should still pass.

- [ ] **Step 3: Commit**

```bash
git add modules/cloudinit/outputs.tf
git commit -m "feat(cloudinit): add metadata_raw output (consumed by modules/hyperv)"
git push
```

---

## Task 2: `modules/hyperv` — versions, variables, locals

**Files:**
- Create: `modules/hyperv/versions.tf`
- Create: `modules/hyperv/variables.tf`
- Create: `modules/hyperv/locals.tf`

- [ ] **Step 1: Create `modules/hyperv/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.7"

  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = "~> 1.2"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.3"
    }
  }
}
```

- [ ] **Step 2: Create `modules/hyperv/variables.tf`**

```hcl
variable "name_prefix" {
  description = "Prefix used to derive publisher names when var.names is null."
  type        = string
  default     = "npa-publisher"
}

variable "names" {
  description = "Explicit publisher names. When set, overrides name_prefix + replicas."
  type        = list(string)
  default     = null
}

variable "replicas" {
  description = "Number of publishers to derive from name_prefix when var.names is null."
  type        = number
  default     = 1

  validation {
    condition     = var.replicas >= 1
    error_message = "replicas must be >= 1."
  }
}

variable "tenant_url" {
  description = "Netskope tenant URL, e.g. https://tenant.goskope.com."
  type        = string

  validation {
    condition     = can(regex("^https://", var.tenant_url))
    error_message = "tenant_url must start with https://."
  }
}

variable "api_token" {
  description = "Netskope NPA API token."
  type        = string
  sensitive   = true
}

variable "wizard_path" {
  description = "Absolute path to npa_publisher_wizard on the VM."
  type        = string
  default     = "/home/ubuntu/npa_publisher_wizard"
}

variable "tags" {
  description = "Written into each VM's `notes` field as a JSON object (Hyper-V has no native tag concept)."
  type        = map(string)
  default     = {}
}

variable "vswitch_name" {
  description = "Name of the Hyper-V virtual switch to attach the publisher NIC to."
  type        = string
}

variable "hyperv_winrm_config" {
  description = "WinRM connection settings used by the null_resource provisioners. Mirror your provider \"hyperv\" block."
  type = object({
    host     = string
    user     = string
    password = string
    port     = optional(number, 5986)
    https    = optional(bool, true)
    insecure = optional(bool, false)
    use_ntlm = optional(bool, true)
  })
  sensitive = true
}

variable "vhdx_source_url" {
  description = "URL to the master Netskope publisher VHDX."
  type        = string
  default     = "https://s3-us-west-2.amazonaws.com/publisher.netskope.com/latest/NetskopePrivateAccessPublisher.vhdx"
}

variable "vhdx_cache_path" {
  description = "Absolute path on the Hyper-V host where the master VHDX is cached."
  type        = string
  default     = "C:\\hyperv\\netskope\\NetskopePrivateAccessPublisher.vhdx"
}

variable "vhd_dir" {
  description = "Directory on the host for per-VM cloned VHDs."
  type        = string
  default     = "C:\\hyperv\\netskope\\vhds"
}

variable "iso_dir" {
  description = "Directory on the host for per-VM NoCloud seed ISOs."
  type        = string
  default     = "C:\\hyperv\\netskope\\iso"
}

variable "vm_dir" {
  description = "Directory on the host for per-VM Hyper-V VM config."
  type        = string
  default     = "C:\\hyperv\\netskope\\vms"
}

variable "processor_count" {
  type    = number
  default = 2
}

variable "memory_startup_bytes" {
  type    = number
  default = 4294967296
}

variable "dynamic_memory" {
  type    = bool
  default = false
}

variable "generation" {
  type    = number
  default = 2
}

variable "enable_secure_boot" {
  type    = string
  default = "Off"
}

variable "vlan_id" {
  type    = number
  default = null
}

variable "force_redownload" {
  description = "Re-fetch the master VHDX even if cached. Use for upgrades."
  type        = bool
  default     = false
}
```

- [ ] **Step 3: Create `modules/hyperv/locals.tf`**

```hcl
locals {
  publisher_names = var.names != null ? var.names : [
    for i in range(var.replicas) :
    format("%s-%d", var.name_prefix, i + 1)
  ]
}
```

- [ ] **Step 4: Commit**

```bash
terraform fmt -recursive
git add modules/hyperv/versions.tf modules/hyperv/variables.tf modules/hyperv/locals.tf
git commit -m "feat(hyperv): scaffold variables, locals, versions"
git push
```

---

## Task 3: `modules/hyperv/scripts/Build-NoCloudIso.ps1`

Stand-alone PowerShell helper that authors a NoCloud seed ISO using IMAPI2 COM. The submodule's `main.tf` loads this file via `file(...)`, wraps it with parameter setup, and ships the whole thing as a base64-encoded WinRM command — so there's no separate file transfer.

**Files:**
- Create: `modules/hyperv/scripts/Build-NoCloudIso.ps1`

- [ ] **Step 1: Create the script**

```powershell
<#
.SYNOPSIS
  Build a NoCloud seed ISO containing user-data + meta-data files, with
  volume label CIDATA (required by cloud-init's NoCloud datasource).

.PARAMETER OutFile
  Path the ISO will be written to.

.PARAMETER UserDataContent
  Raw cloud-init user-data string.

.PARAMETER MetaDataContent
  Raw cloud-init meta-data string.

.NOTES
  Uses IMAPI2FS.MsftFileSystemImage (built into Windows Server 2016+;
  no ADK / no oscdimg needed).

.EXAMPLE
  Build-NoCloudIso -OutFile C:\tmp\seed.iso -UserDataContent "#cloud-config..." -MetaDataContent "instance-id: pub-1"

  # Verify volume label after building:
  $img = Mount-DiskImage -ImagePath C:\tmp\seed.iso -PassThru
  (Get-Volume -DiskImage $img).FileSystemLabel  # → CIDATA
  Dismount-DiskImage -ImagePath C:\tmp\seed.iso
#>
function Build-NoCloudIso {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $OutFile,
    [Parameter(Mandatory)] [string] $UserDataContent,
    [Parameter(Mandatory)] [string] $MetaDataContent
  )

  $stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) ("nocloud-" + [Guid]::NewGuid())
  New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

  try {
    # Cloud-init NoCloud datasource requires LF line endings.
    $userDataPath = Join-Path $stagingDir "user-data"
    $metaDataPath = Join-Path $stagingDir "meta-data"
    [System.IO.File]::WriteAllText($userDataPath, ($UserDataContent -replace "`r`n","`n"))
    [System.IO.File]::WriteAllText($metaDataPath, ($MetaDataContent -replace "`r`n","`n"))

    $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
    $fsi.FileSystemsToCreate = 7  # ISO9660 + Joliet + UDF
    $fsi.VolumeName          = 'CIDATA'

    $root = $fsi.Root
    $root.AddTree($stagingDir, $false)

    $result = $fsi.CreateResultImage()
    $stream = $result.ImageStream

    $outDir = Split-Path -Parent $OutFile
    if (-not (Test-Path $outDir)) {
      New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    # Persist COM IStream to disk.
    $shellApp = New-Object -ComObject Shell.Application
    $bytes    = New-Object byte[] $result.BlockSize
    $fileStream = [System.IO.File]::Create($OutFile)
    try {
      $intRead = 0
      do {
        $stream.Read([ref] $bytes, $result.BlockSize, [ref] $intRead) | Out-Null
        $fileStream.Write($bytes, 0, $intRead)
      } while ($intRead -eq $result.BlockSize)
    } finally {
      $fileStream.Close()
    }
  } finally {
    Remove-Item -Recurse -Force $stagingDir -ErrorAction SilentlyContinue
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/hyperv/scripts/Build-NoCloudIso.ps1
git commit -m "feat(hyperv): IMAPI2 PowerShell helper to author NoCloud seed ISOs"
git push
```

---

## Task 4: `modules/hyperv/main.tf` — all four resources

The resources are tightly coupled (master VHDX → cloned VHDs → seed ISOs → VMs); writing them in one task keeps the dependency graph clear.

**Files:**
- Create: `modules/hyperv/main.tf`

- [ ] **Step 1: Create `modules/hyperv/main.tf`**

```hcl
module "registration" {
  source          = "../registration"
  tenant_url      = var.tenant_url
  api_token       = var.api_token
  publisher_names = local.publisher_names
}

module "cloudinit" {
  source      = "../cloudinit"
  publishers  = { for n, p in module.registration.publishers : n => p.registration_token }
  wizard_path = var.wizard_path
}

# Reusable connection block as a local — same struct passed to every
# null_resource provisioner.
locals {
  winrm_conn = {
    type     = "winrm"
    host     = var.hyperv_winrm_config.host
    user     = var.hyperv_winrm_config.user
    password = var.hyperv_winrm_config.password
    port     = var.hyperv_winrm_config.port
    https    = var.hyperv_winrm_config.https
    insecure = var.hyperv_winrm_config.insecure
    use_ntlm = var.hyperv_winrm_config.use_ntlm
  }

  # IMAPI2 ISO-builder script body (no parameters bound yet).
  build_iso_script = file("${path.module}/scripts/Build-NoCloudIso.ps1")
}

# ---------------------------------------------------------------------------
# 1) Master VHDX cache — singleton, shared across replicas.
# ---------------------------------------------------------------------------

resource "null_resource" "fetch_master_vhdx" {
  triggers = {
    url   = var.vhdx_source_url
    path  = var.vhdx_cache_path
    force = var.force_redownload ? timestamp() : "stable"
  }

  connection {
    type     = local.winrm_conn.type
    host     = local.winrm_conn.host
    user     = local.winrm_conn.user
    password = local.winrm_conn.password
    port     = local.winrm_conn.port
    https    = local.winrm_conn.https
    insecure = local.winrm_conn.insecure
    use_ntlm = local.winrm_conn.use_ntlm
  }

  provisioner "remote-exec" {
    inline = [
      <<-PS
      powershell -NoProfile -ExecutionPolicy Bypass -Command "
        $ErrorActionPreference = 'Stop';
        $url   = '${var.vhdx_source_url}';
        $path  = '${var.vhdx_cache_path}';
        $force = $${var.force_redownload};
        $dir   = Split-Path -Parent $path;
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null };
        if ((Test-Path $path) -and (-not $force)) { Write-Host 'Cached VHDX exists; skipping download.'; exit 0 };
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
        Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing;
      "
      PS
    ]
  }
}

# ---------------------------------------------------------------------------
# 2) Per-publisher cloned VHD — copy of the master into a per-VM file.
# ---------------------------------------------------------------------------

resource "hyperv_vhd" "publisher" {
  for_each = toset(local.publisher_names)

  path   = "${var.vhd_dir}\\${each.key}.vhdx"
  source = var.vhdx_cache_path

  depends_on = [null_resource.fetch_master_vhdx]
}

# ---------------------------------------------------------------------------
# 3) Per-publisher NoCloud seed ISO — built on the host via IMAPI2.
# ---------------------------------------------------------------------------

resource "null_resource" "build_seed_iso" {
  for_each = toset(local.publisher_names)

  triggers = {
    user_data = module.cloudinit.userdata_raw[each.key]
    meta_data = module.cloudinit.metadata_raw[each.key]
    out_path  = "${var.iso_dir}\\${each.key}-seed.iso"
  }

  connection {
    type     = local.winrm_conn.type
    host     = local.winrm_conn.host
    user     = local.winrm_conn.user
    password = local.winrm_conn.password
    port     = local.winrm_conn.port
    https    = local.winrm_conn.https
    insecure = local.winrm_conn.insecure
    use_ntlm = local.winrm_conn.use_ntlm
  }

  provisioner "remote-exec" {
    inline = [
      <<-PS
      powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand ${base64encode(
        join("\n", [
          local.build_iso_script,
          "$ud = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${base64encode(module.cloudinit.userdata_raw[each.key])}'))",
          "$md = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${base64encode(nonsensitive(module.cloudinit.metadata_raw[each.key]))}'))",
          "Build-NoCloudIso -OutFile '${var.iso_dir}\\${each.key}-seed.iso' -UserDataContent $ud -MetaDataContent $md",
        ])
      )}
      PS
    ]
  }
}

# ---------------------------------------------------------------------------
# 4) The VM — cloned VHD + seed ISO + vNIC.
# ---------------------------------------------------------------------------

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
    vlan_access = var.vlan_id
  }

  depends_on = [
    hyperv_vhd.publisher,
    null_resource.build_seed_iso,
  ]
}
```

- [ ] **Step 2: Format check**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher
terraform fmt -recursive
```

- [ ] **Step 3: Validate from inside the submodule**

```bash
( cd modules/hyperv && rm -rf .terraform .terraform.lock.hcl && terraform init -backend=false 2>&1 | tail -3 && terraform validate 2>&1 | tail -3 )
```

Expected: `Success! The configuration is valid.`

If validate complains that `hyperv_machine_instance.network_adaptors.vlan_access` doesn't accept `null`, change the line to:

```hcl
    vlan_access = var.vlan_id == null ? 0 : var.vlan_id
```

(The provider treats `0` as "no VLAN tag".)

- [ ] **Step 4: Commit**

```bash
git add modules/hyperv/main.tf
git commit -m "feat(hyperv): master VHDX cache, cloned VHDs, seed ISOs, hyperv_machine_instance"
git push
```

---

## Task 5: `modules/hyperv/outputs.tf`

**Files:**
- Create: `modules/hyperv/outputs.tf`

- [ ] **Step 1: Create the file**

```hcl
output "publishers" {
  description = "Map of publisher name => { publisher_id, vm_id, private_ip, public_ip, registration_token }."
  sensitive   = true
  value = {
    for n in local.publisher_names : n => {
      publisher_id       = module.registration.publishers[n].publisher_id
      registration_token = module.registration.publishers[n].registration_token
      vm_id              = hyperv_machine_instance.publisher[n].id
      # Hyper-V reports addresses via KVP / Integration Services asynchronously.
      # `network_adaptors[0].ip_addresses` may be empty on first apply.
      private_ip = try(hyperv_machine_instance.publisher[n].network_adaptors[0].ip_addresses[0], null)
      public_ip  = null
    }
  }
}

output "publisher_names" {
  description = "Derived publisher names (useful when name_prefix+replicas was used)."
  value       = local.publisher_names
}

output "vm_ids" {
  description = "List of hyperv_machine_instance IDs in publisher-name order."
  value       = [for n in local.publisher_names : hyperv_machine_instance.publisher[n].id]
}

output "seed_iso_paths_by_name" {
  description = "Map of publisher name => seed ISO path on the host."
  value       = { for n in local.publisher_names : n => "${var.iso_dir}\\${n}-seed.iso" }
}
```

- [ ] **Step 2: Re-validate**

```bash
( cd modules/hyperv && terraform validate 2>&1 | tail -3 )
```

Expected: `Success!`. If the `private_ip` line errors because `network_adaptors[0].ip_addresses` isn't a known attribute on this provider version, replace the line with:

```hcl
      private_ip = null
```

and note in the submodule README that IP discovery isn't surfaced (consistent with the spec's "private_ip may be null on first apply").

- [ ] **Step 3: Commit**

```bash
terraform fmt -recursive
git add modules/hyperv/outputs.tf
git commit -m "feat(hyperv): outputs (publishers, publisher_names, vm_ids, seed_iso_paths_by_name)"
git push
```

---

## Task 6: `tests/hyperv_plan.tftest.hcl`

Mocked-provider plan test, same pattern as `tests/aws_plan.tftest.hcl`.

**Files:**
- Create: `tests/hyperv_plan.tftest.hcl`

- [ ] **Step 1: Create the test**

```hcl
variables {
  name_prefix  = "pub-hv"
  replicas     = 1
  tenant_url   = "https://tenant.example.goskope.com"
  api_token    = "MOCK-API-TOKEN"
  vswitch_name = "vSwitch-Test"

  hyperv_winrm_config = {
    host     = "hyperv.test.local"
    user     = "Administrator"
    password = "mock-password"
  }
}

mock_provider "hyperv" {}
mock_provider "http" {}

run "hyperv_plan_emits_vm_and_seed_iso" {
  command = plan
  module {
    source = "./modules/hyperv"
  }

  override_data {
    target = module.registration.data.http.list
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"publishers\":[]}}"
    }
  }
  override_data {
    target = module.registration.data.http.create["pub-hv-1"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"id\":401,\"name\":\"pub-hv-1\"}}"
    }
  }
  override_data {
    target = module.registration.data.http.token["pub-hv-1"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"token\":\"HV-TOKEN\"}}"
    }
  }

  assert {
    condition     = length(output.vm_ids) == 1
    error_message = "Expected 1 hyperv_machine_instance"
  }

  assert {
    condition     = output.seed_iso_paths_by_name["pub-hv-1"] == "C:\\hyperv\\netskope\\iso\\pub-hv-1-seed.iso"
    error_message = "Seed ISO path should follow the documented convention"
  }

  assert {
    condition     = strcontains(null_resource.build_seed_iso["pub-hv-1"].triggers.user_data, "HV-TOKEN")
    error_message = "Seed ISO build trigger should embed the registration token"
  }

  assert {
    condition     = strcontains(null_resource.build_seed_iso["pub-hv-1"].triggers.user_data, "/home/ubuntu/npa_publisher_wizard")
    error_message = "Seed ISO build trigger should reference the wizard path"
  }
}
```

- [ ] **Step 2: Run the test**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher
rm -rf .terraform .terraform.lock.hcl
terraform init -backend=false 2>&1 | tail -3
terraform test -filter=tests/hyperv_plan.tftest.hcl 2>&1 | tail -10
```

Expected: `1 passed, 0 failed.`

If the test fails because `taliesins/hyperv` authenticates at provider-configure time (the same trap that bit Azure/GCP/vSphere in v1), delete this test file and document the deviation: Hyper-V is covered by `terraform validate` on the submodule + the runnable example, like the other three. Add a CHANGELOG note: "Plan-time test omitted for Hyper-V (provider eager-auth)."

- [ ] **Step 3: Commit**

```bash
git add tests/hyperv_plan.tftest.hcl
git commit -m "test(hyperv): plan-time test with mocked hyperv + http providers"
git push
```

---

## Task 7: `examples/hyperv-single/`

**Files:**
- Create: `examples/hyperv-single/main.tf`
- Create: `examples/hyperv-single/variables.tf`
- Create: `examples/hyperv-single/terraform.tfvars.example`
- Create: `examples/hyperv-single/README.md`

- [ ] **Step 1: Create `examples/hyperv-single/variables.tf`**

```hcl
variable "netskope_tenant_url" {
  type = string
}

variable "netskope_api_token" {
  type      = string
  sensitive = true
}

variable "hyperv_host" {
  description = "Hyper-V host hostname or IP (reachable via WinRM)."
  type        = string
}

variable "hyperv_user" {
  description = "Local admin or domain user on the Hyper-V host."
  type        = string
}

variable "hyperv_password" {
  type      = string
  sensitive = true
}

variable "vswitch_name" {
  description = "Existing virtual switch on the Hyper-V host."
  type        = string
}
```

- [ ] **Step 2: Create `examples/hyperv-single/main.tf`**

```hcl
terraform {
  required_version = ">= 1.7"
  required_providers {
    hyperv    = { source = "taliesins/hyperv", version = "~> 1.2" }
    http      = { source = "hashicorp/http", version = ">= 3.4" }
    cloudinit = { source = "hashicorp/cloudinit", version = ">= 2.3" }
  }
}

provider "hyperv" {
  host        = var.hyperv_host
  user        = var.hyperv_user
  password    = var.hyperv_password
  port        = 5986
  https       = true
  insecure    = true        # lab default; configure WinRM HTTPS properly for production
  use_ntlm    = true
  script_path = "C:/Temp/terraform_%RAND%.cmd"
  timeout     = "30s"
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

- [ ] **Step 3: Create `examples/hyperv-single/terraform.tfvars.example`**

```hcl
netskope_tenant_url = "https://tenant.goskope.com"
netskope_api_token  = "..."
hyperv_host         = "hyperv01.lab.local"
hyperv_user         = "Administrator"
hyperv_password     = "..."
vswitch_name        = "External vSwitch"
```

- [ ] **Step 4: Create `examples/hyperv-single/README.md`**

```markdown
# Example: Hyper-V, single publisher

Provisions one Netskope Private Access Publisher VM on a Hyper-V host
over WinRM. The Hyper-V host downloads the master VHDX from S3 on
first apply (subsequent applies reuse the cached copy).

## Prerequisites on the Hyper-V host

- Windows Server 2016+ with the Hyper-V role.
- WinRM enabled (HTTPS preferred). Quick HTTPS bootstrap:
  ```powershell
  winrm quickconfig
  $cert = New-SelfSignedCertificate -CertStoreLocation cert:\LocalMachine\My `
            -DnsName $env:COMPUTERNAME
  New-Item -Path WSMan:\localhost\Listener -Transport HTTPS `
           -Address * -CertificateThumbPrint $cert.Thumbprint -Force
  New-NetFirewallRule -DisplayName "WinRM-HTTPS" -Direction Inbound `
                      -LocalPort 5986 -Protocol TCP -Action Allow
  ```
- An existing virtual switch (external type, with outbound internet
  access). `Get-VMSwitch` to list.
- Outbound HTTPS reachable from the host to
  `s3-us-west-2.amazonaws.com` and your Netskope tenant.

## Run

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars
terraform init
terraform apply
```

First apply downloads ~3 GiB (the master VHDX). Subsequent applies for
additional replicas reuse the cached VHDX.
```

- [ ] **Step 5: Validate the example**

```bash
( cd examples/hyperv-single && rm -rf .terraform .terraform.lock.hcl && terraform init -backend=false 2>&1 | tail -1 && terraform validate 2>&1 | grep -o "Success\|Error" | head -1 )
```

Expected: `Success`.

- [ ] **Step 6: Commit**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher
terraform fmt -recursive
git add examples/hyperv-single
git commit -m "feat(examples): hyperv-single example"
git push
```

---

## Task 8: Docs site — new platform page

**Files:**
- Create: `site/source/admin/module/platforms/hyperv.md`
- Modify: `site/source/admin/module/index.md`
- Modify: `site/source/admin/index.md`
- Modify: `site/source/admin/module/platforms/index.md`

- [ ] **Step 1: Create `site/source/admin/module/platforms/hyperv.md`**

```markdown
---
title: Hyper-V platform inputs
date: 2026-05-18
toc: true
---

> ⚠️ The publisher VM needs outbound TCP/443 to your Netskope tenant.
> See [Connectivity requirements → Hyper-V](/terraform-netskope-publisher/admin/concepts/connectivity/)
> for vswitch, host firewall, and DNS considerations.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `vswitch_name` | string | required | Name of the Hyper-V virtual switch the publisher NIC attaches to. |
| `hyperv_winrm_config` | object | required | `{ host, user, password, port, https, insecure, use_ntlm }` — mirror your `provider "hyperv"` block. |
| `vhdx_source_url` | string | Netskope S3 URL | Where to download the master VHDX from. Default is `https://s3-us-west-2.amazonaws.com/publisher.netskope.com/latest/NetskopePrivateAccessPublisher.vhdx`. |
| `vhdx_cache_path` | string | `C:\hyperv\netskope\NetskopePrivateAccessPublisher.vhdx` | Where on the host to cache the master VHDX. |
| `vhd_dir` | string | `C:\hyperv\netskope\vhds` | Per-VM cloned VHD directory. |
| `iso_dir` | string | `C:\hyperv\netskope\iso` | Per-VM seed ISO directory. |
| `vm_dir` | string | `C:\hyperv\netskope\vms` | Per-VM VM-config directory. |
| `processor_count` | number | `2` | vCPUs. |
| `memory_startup_bytes` | number | `4294967296` | 4 GiB. |
| `dynamic_memory` | bool | `false` | Publishers benefit from fixed memory. |
| `generation` | number | `2` | Gen 2 (UEFI); required for the Netskope VHDX. |
| `enable_secure_boot` | string | `"Off"` | Linux VMs on Gen 2 → Secure Boot off. |
| `vlan_id` | number | `null` | Optional NIC VLAN tag. |
| `force_redownload` | bool | `false` | Re-fetch the master VHDX even if cached. |

## Minimal example

```hcl
module "publisher" {
  source = "github.com/johnneerdael/terraform-netskope-publisher//modules/hyperv?ref=v2.1.0"

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

## Full example

```hcl
module "publisher" {
  source = "github.com/johnneerdael/terraform-netskope-publisher//modules/hyperv?ref=v2.1.0"

  name_prefix = "pub-hv"
  replicas    = 2
  tags        = { Owner = "platform-team", Env = "prod" }

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  vswitch_name        = "vSwitch-Prod"
  vlan_id             = 100
  processor_count     = 4
  memory_startup_bytes = 8589934592   # 8 GiB
  enable_secure_boot   = "Off"

  hyperv_winrm_config = {
    host     = "hyperv01.lab.local"
    user     = "DOMAIN\\svc-terraform"
    password = var.hyperv_password
    port     = 5986
    https    = true
    insecure = false
    use_ntlm = true
  }
}
```

## Platform-specific outputs

| Output | Type | Description |
|---|---|---|
| `vm_ids` | list(string) | `hyperv_machine_instance` IDs in publisher-name order. |
| `seed_iso_paths_by_name` | map(string) | Per-publisher NoCloud seed ISO path on the host. |

## Caveats

- **Provider authenticates over WinRM eagerly.** Plan + apply both
  require a reachable Hyper-V host with valid WinRM credentials. The
  module's `null_resource` provisioners use the same WinRM config.
- **First-apply download is large.** The master VHDX is ~3 GiB and gets
  downloaded once per `vhdx_cache_path` on the host. Subsequent replicas
  share it.
- **User-data changes don't auto-reboot the VM.** Editing inputs that
  affect cloud-init (e.g., `wizard_path`) rebuilds the seed ISO but the
  VM keeps running. To pick up the change:
  `terraform taint 'module.publisher.hyperv_machine_instance.publisher["<name>"]'`
  + `terraform apply`.
- **`private_ip` may be `null` on first apply.** Hyper-V reports IPs
  via Integration Services / KVP asynchronously. Re-run `terraform refresh`
  after the VM has finished booting.
- **`tags` not native to Hyper-V** — written into each VM's `notes`
  field as a JSON object.

## WinRM bootstrap (Hyper-V host)

```powershell
winrm quickconfig
$cert = New-SelfSignedCertificate -CertStoreLocation cert:\LocalMachine\My `
          -DnsName $env:COMPUTERNAME
New-Item -Path WSMan:\localhost\Listener -Transport HTTPS `
         -Address * -CertificateThumbPrint $cert.Thumbprint -Force
New-NetFirewallRule -DisplayName "WinRM-HTTPS" -Direction Inbound `
                    -LocalPort 5986 -Protocol TCP -Action Allow
```

For production: use a CA-issued cert, kerberos auth, and a service
account scoped to Hyper-V management.
```

- [ ] **Step 2: Update `site/source/admin/module/index.md`**

Replace the "Platform-specific inputs" list with:

```markdown
## Platform-specific inputs

- [AWS](/terraform-netskope-publisher/admin/module/platforms/aws/)
- [Azure](/terraform-netskope-publisher/admin/module/platforms/azure/)
- [GCP](/terraform-netskope-publisher/admin/module/platforms/gcp/)
- [vSphere](/terraform-netskope-publisher/admin/module/platforms/vsphere/)
- [Hyper-V](/terraform-netskope-publisher/admin/module/platforms/hyperv/)
```

- [ ] **Step 3: Update `site/source/admin/index.md`**

Replace the per-platform list in the "Module reference" block with the same five entries (add Hyper-V at the end of the bullet list).

- [ ] **Step 4: Update `site/source/admin/module/platforms/index.md`**

Replace its body with:

```markdown
---
title: Per-platform inputs
date: 2026-05-18
---

- [AWS](/terraform-netskope-publisher/admin/module/platforms/aws/)
- [Azure](/terraform-netskope-publisher/admin/module/platforms/azure/)
- [GCP](/terraform-netskope-publisher/admin/module/platforms/gcp/)
- [vSphere](/terraform-netskope-publisher/admin/module/platforms/vsphere/)
- [Hyper-V](/terraform-netskope-publisher/admin/module/platforms/hyperv/)
```

- [ ] **Step 5: Build and commit**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher/site
./node_modules/.bin/hexo generate 2>&1 | tail -3
cd ..
git add site/source/admin/module/platforms/hyperv.md site/source/admin/module/index.md site/source/admin/index.md site/source/admin/module/platforms/index.md
git commit -m "docs(site/admin): add Hyper-V platform page and link from indexes"
git push
```

---

## Task 9: Docs site — Concepts + Connectivity + Reference

**Files:**
- Modify: `site/source/admin/concepts/architecture-overview.md`
- Modify: `site/source/admin/concepts/connectivity.md`
- Modify: `site/source/reference/provider-matrix.md`
- Modify: `site/source/reference/roadmap.md`

- [ ] **Step 1: Architecture overview — extend the "What lives where" table**

Add this row to the existing table in `site/source/admin/concepts/architecture-overview.md` (under the `vsphere` row):

```markdown
| `modules/hyperv` | VM cloned from a master VHDX, NoCloud seed ISO built on the host via IMAPI2 | `taliesins/hyperv` |
```

- [ ] **Step 2: Connectivity page — add a Hyper-V section**

In `site/source/admin/concepts/connectivity.md`, insert this section after the `## GCP` section and before `## vSphere`:

```markdown
## Hyper-V

`modules/hyperv` requires only a virtual switch (`vswitch_name`) and a
host that can reach the public internet on TCP/443.

| Switch type | Outbound 443 reachable? | Notes |
|---|---|---|
| **External (bridged to a NIC with internet)** | Yes — same as the host | Most common in labs and small deployments. |
| **Internal (host + VMs only)** | No | The publisher cannot register. Add NAT on the host or use an External switch. |
| **Private (VMs only)** | No | Same as Internal. |

Minimal example:

```hcl
module "publisher" {
  source = "github.com/johnneerdael/terraform-netskope-publisher//modules/hyperv?ref=v2.1.0"

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

Additional considerations:

- **Host firewall** (Windows Defender Firewall): the host needs outbound
  443 to `s3-us-west-2.amazonaws.com` for the VHDX download and the
  Netskope tenant URL.
- **WinRM** (5985 HTTP or 5986 HTTPS) must be reachable from wherever
  you run Terraform.
- **DNS on the VM**: by default it uses the vswitch's DHCP-assigned
  DNS. If you use an internal-only DNS, make sure it can resolve public
  Netskope hostnames or the publisher won't register.
- **VLANs**: set `vlan_id` on the module to tag the publisher NIC.
```

- [ ] **Step 3: Provider matrix — add the Hyper-V row**

In `site/source/reference/provider-matrix.md`, add to the "Required per platform" table:

```markdown
| `hyperv` | `hyperv` | `taliesins/hyperv` | `~> 1.2` |
```

- [ ] **Step 4: Roadmap — move Hyper-V out of "Additional platforms"**

In `site/source/reference/roadmap.md`, find the bullet list under
"Additional platforms" and remove the Hyper-V entry. Add a note at the
top of that section:

```markdown
## Additional platforms

> Hyper-V shipped in v2.1.0 — see
> [Hyper-V platform inputs](/terraform-netskope-publisher/admin/module/platforms/hyperv/).
```

(Keep the remaining Nutanix / KVM / OpenShift bullets.)

- [ ] **Step 5: Build and commit**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher/site
./node_modules/.bin/hexo generate 2>&1 | tail -3
cd ..
git add site/source/admin/concepts site/source/reference
git commit -m "docs(site): Hyper-V additions to architecture, connectivity, provider matrix, roadmap"
git push
```

---

## Task 10: README + CHANGELOG + `v2.1.0` tag

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update the README "Quick start" follow-on paragraph**

In `README.md`, find this paragraph:

```markdown
For Azure / GCP / vSphere, source the matching submodule:
`//modules/azure`, `//modules/gcp`, `//modules/vsphere`.
```

Replace it with:

```markdown
For other platforms, source the matching submodule:
`//modules/azure`, `//modules/gcp`, `//modules/vsphere`, `//modules/hyperv`.
```

- [ ] **Step 2: Update the README intro paragraph**

In `README.md`, find:

```markdown
Provision Netskope Private Access Publishers on **AWS**, **Azure**, **GCP**,
or **vSphere** via the Netskope NPA API and cloud-init.
```

Replace with:

```markdown
Provision Netskope Private Access Publishers on **AWS**, **Azure**, **GCP**,
**vSphere**, or **Hyper-V** via the Netskope NPA API and cloud-init.
```

- [ ] **Step 3: Add `v2.1.0` to `CHANGELOG.md`**

Insert immediately under `## [Unreleased]`:

```markdown
## [Unreleased]

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
```

- [ ] **Step 4: Tag and push**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher
git add README.md CHANGELOG.md
git commit -m "docs: README + CHANGELOG for v2.1.0 (Hyper-V submodule)"
git tag -a v2.1.0 -m "v2.1.0 — Hyper-V support"
git push && git push --tags
```

- [ ] **Step 5: Verify live site**

After the Pages workflow finishes, spot-check:

- `https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/hyperv/` returns 200
- `https://johnneerdael.github.io/terraform-netskope-publisher/admin/concepts/connectivity/` shows the new Hyper-V section
- Footer still reads "Applies to terraform-netskope-publisher v2.x" (Section 11 bump comes in a follow-up when we go v3, not now)

---

## Self-review notes

**Spec coverage:**
- §4 Architecture → Task 4 builds all four resource categories.
- §5 Host requirements → Task 7 README + Task 8 platform page document them.
- §6 Inputs → Task 2.
- §7 Outputs → Task 5.
- §8 Internal resources → Task 4.
- §9 `metadata_raw` addition → Task 1.
- §10 Update flow / quirks → Task 8 Caveats section.
- §11 Testing → Task 6.
- §12 Example → Task 7.
- §13 Documentation updates → Tasks 8 + 9.
- §14 Release → Task 10.

**Intentional deviations:**
- The plan inlines the PowerShell IMAPI2 helper into the WinRM
  `EncodedCommand` rather than transferring a `.ps1` to the host. The
  helper file (Task 3) is still shipped for auditability and so that the
  PowerShell is editable independently of the terraform module wiring.
- The plan test (Task 6) might fail if `taliesins/hyperv` auth-checks at
  provider-configure time. The task documents the fallback (delete the
  test, document under "Plan-time tests omitted for Hyper-V" in
  CHANGELOG), mirroring how Azure/GCP/vSphere are handled today.
