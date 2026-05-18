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

locals {
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
    type     = "winrm"
    host     = var.hyperv_winrm_config.host
    user     = var.hyperv_winrm_config.user
    password = var.hyperv_winrm_config.password
    port     = var.hyperv_winrm_config.port
    https    = var.hyperv_winrm_config.https
    insecure = var.hyperv_winrm_config.insecure
    use_ntlm = var.hyperv_winrm_config.use_ntlm
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
    type     = "winrm"
    host     = var.hyperv_winrm_config.host
    user     = var.hyperv_winrm_config.user
    password = var.hyperv_winrm_config.password
    port     = var.hyperv_winrm_config.port
    https    = var.hyperv_winrm_config.https
    insecure = var.hyperv_winrm_config.insecure
    use_ntlm = var.hyperv_winrm_config.use_ntlm
  }

  provisioner "remote-exec" {
    inline = [
      <<-PS
      powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand ${base64encode(join("\n", [
      local.build_iso_script,
      "$ud = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${base64encode(module.cloudinit.userdata_raw[each.key])}'))",
      "$md = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${base64encode(module.cloudinit.metadata_raw[each.key])}'))",
      "Build-NoCloudIso -OutFile '${var.iso_dir}\\${each.key}-seed.iso' -UserDataContent $ud -MetaDataContent $md",
]))}
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
    vlan_access = var.vlan_id != null
    vlan_id     = var.vlan_id == null ? 0 : var.vlan_id
  }

  depends_on = [
    hyperv_vhd.publisher,
    null_resource.build_seed_iso,
  ]
}
