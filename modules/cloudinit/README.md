# terraform-netskope-publisher — `cloudinit` shared module

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/concepts/registration-flow/

Renders the cloud-init `user-data` (and NoCloud `meta-data`) that the AWS,
Azure, GCP, Hyper-V, and vSphere submodules feed to each Publisher VM. Not
intended to be sourced directly by end users — it is wired in by the
platform submodules.

## What it produces

For each publisher in `var.publishers` (map of `name => registration_token`)
the module renders two strings (raw and base64) consumed downstream:

| Output | Used by |
|---|---|
| `userdata_raw` / `userdata_b64` | `metadata["user-data"]` on GCE, `user_data_base64` on EC2, `custom_data` on `azurerm_linux_virtual_machine`, NoCloud `user-data` on vSphere / Hyper-V |
| `metadata_raw` / `metadata_b64` | NoCloud `meta-data` on the seed ISO platforms (vSphere `guestinfo`, Hyper-V NoCloud ISO) |

## Two install modes

| Mode | What runs in `runcmd` | When to use |
|---|---|---|
| **Bootstrap** (`bootstrap = true`) | `curl … bootstrap.sh \| sudo bash` → `sudo <wizard_path> -token <TOKEN>` | Stock Canonical Ubuntu 22.04 image; the script installs the Publisher then we register |
| **Pre-baked** (`bootstrap = false`, default) | `sudo <wizard_path> -token <TOKEN>` | Netskope Publisher image where the wizard is already on disk |

Both modes run as `install_user` (default `ubuntu`) via `su -`, so the
enrollment no longer hard-codes `/home/ubuntu`.

## Rendered user-data structure (v2.3)

Top-level sections emitted, in order:

```yaml
#cloud-config
hostname: <publisher_name>
preserve_hostname: false

system_info:
  default_user:
    name: <install_user>          # cloud-init treats install_user as "the" user

users:
  - name: <install_user>
    groups: [sudo]
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    lock_passwd: <true unless password set>
    ssh_authorized_keys: …        # when install_user_ssh_authorized_keys non-empty

chpasswd: …                       # when install_user_password set; ssh_pwauth: true

write_files:                      # when guest_network_interface set
  - path: /etc/netplan/60-cloudinit-override.yaml
    content: |
      network:
        version: 2
        ethernets:
          <name>:
            dhcp4: <bool>
            addresses: [...]
            gateway4: …
            nameservers: { addresses: [...] }
            mtu: …

runcmd:
  - chmod 0600 /etc/netplan/60-cloudinit-override.yaml  # when network override
  - netplan apply                                       # when network override
  - pkill -KILL -u ubuntu / userdel -r ubuntu           # when install_user != ubuntu && delete_default_user
  - chmod 1777 /tmp                                     # when bootstrap || nonat
  - install -d … /home/<install_user>/resources         # when nonat
  - install … /home/<install_user>/resources/.nonat     # when nonat
  - su - <install_user> -c 'curl … bootstrap.sh | sudo bash'  # when bootstrap
  - su - <install_user> -c 'sudo <wizard_path> -token "<TOKEN>"'
```

`package_update` is deliberately **not** set: `bootstrap.sh` owns all `apt`
activity and we don't want cloud-init's apt module racing it for the
`dpkg` lock.

## Inputs

| Name | Type | Default | Notes |
|---|---|---|---|
| `publishers` | `map(string)` sensitive | — | `{ name => registration_token }`. One user-data is rendered per entry. |
| `bootstrap` | bool | `false` | Toggle the script install path. |
| `bootstrap_url` | string | Netskope S3 URL | Override for mirrors / air-gap. |
| `nonat` | bool | `false` | Drop `~install_user/resources/.nonat`. |
| `wizard_path` | string | `null` → `/home/<install_user>/npa_publisher_wizard` | Absolute path on the VM. |
| `install_user` | string | `"ubuntu"` | Default user replacement, see above. |
| `install_user_password` | string sensitive | `null` | Plaintext unless `_is_hash` set. |
| `install_user_password_is_hash` | bool | `false` | `crypt(3)` hash. |
| `install_user_ssh_authorized_keys` | list(string) | `[]` | Public keys for inbound SSH. |
| `delete_default_user` | bool | `true` | `userdel -r ubuntu` when `install_user != "ubuntu"`. |
| `guest_network_interface` | object | `null` | Netplan override for the primary NIC. |

The platform submodules pass these through; consult their READMEs for the
default each chooses (GCP defaults to `bootstrap = true` and `nonat = true`,
AWS/Azure leave both `false`).

## Outputs

```hcl
output "userdata_raw"   { type = map(string) (sensitive) }
output "userdata_b64"   { type = map(string) (sensitive) }
output "metadata_raw"   { type = map(string) }
output "metadata_b64"   { type = map(string) }
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.7 |
| hashicorp/cloudinit | >= 2.3 |
