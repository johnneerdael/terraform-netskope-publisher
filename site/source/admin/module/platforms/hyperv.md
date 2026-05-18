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

  vswitch_name         = "vSwitch-Prod"
  vlan_id              = 100
  processor_count      = 4
  memory_startup_bytes = 8589934592 # 8 GiB
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
- **`private_ip` is `null` in module outputs.** Hyper-V reports IPs via
  Integration Services / KVP asynchronously; the module does not surface
  them. Use the Hyper-V console or `Get-VMNetworkAdapter -VMName <name>`
  to find addresses post-boot.
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
