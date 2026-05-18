# terraform-netskope-publisher

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/
> — starter walkthrough for first-time Terraform users + complete admin
> reference for AWS / Azure / GCP / vSphere.

Provision Netskope Private Access Publishers on **AWS**, **Azure**, **GCP**,
**vSphere**, or **Hyper-V** via the Netskope NPA API and cloud-init.

## Quick start

```hcl
module "publisher" {
  source = "github.com/johnneerdael/terraform-netskope-publisher//modules/aws?ref=v2.0.0"

  name_prefix = "pub-eu"
  replicas    = 2

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  subnet_id          = "subnet-…"
  security_group_ids = ["sg-…"]
  key_name           = "my-key"
}
```

For other platforms, source the matching submodule:
`//modules/azure`, `//modules/gcp`, `//modules/vsphere`, `//modules/hyperv`.

## Why per-platform submodules

Each submodule declares only the providers it needs. Sourcing
`//modules/aws` pulls in `aws`, `http`, `cloudinit` — nothing else. The
v1 root module that routed on a `platform` variable forced consumers to
configure all four cloud providers, which was a usability bug. v2
removes it.

## Inputs (common to every submodule)

| Name | Type | Default | Description |
|---|---|---|---|
| `name_prefix` | string | `"npa-publisher"` | Used to derive names when `names` is null |
| `names` | list(string) | `null` | Explicit publisher names; overrides `name_prefix` + `replicas` |
| `replicas` | number | `1` | Number of publishers to derive |
| `tags` | map(string) | `{}` | Tags / labels per platform |
| `tenant_url` | string | — | e.g. `https://tenant.goskope.com` |
| `api_token` | string (sensitive) | — | NPA API token |
| `wizard_path` | string | `/home/ubuntu/npa_publisher_wizard` | On-VM wizard path |

Platform-specific inputs (subnets, image refs, etc.) are documented in
each submodule's `variables.tf` and on the docs site.

## Outputs

```hcl
output "publishers" {
  # Map: name => { publisher_id, vm_id, private_ip, public_ip, registration_token }
  # sensitive (registration_token is inside)
}
output "publisher_names" {
  # The derived list of names (useful when you used name_prefix+replicas)
}
```

## Migration from v1.x

| v1.x (root module) | v2.0.0 (submodule) |
|---|---|
| `source = "...?ref=v1.x"` + `platform = "aws"` | `source = "...//modules/aws?ref=v2.0.0"` |
| `netskope_tenant_url = ...` | `tenant_url = ...` |
| `netskope_api_token = ...` | `api_token = ...` |
| `aws = { subnet_id = …, security_group_ids = … }` | `subnet_id = …`, `security_group_ids = …` (flat) |

## Requirements

- Terraform >= 1.7
- `hashicorp/http >= 3.4` (POST support)
- `hashicorp/cloudinit >= 2.3`
- Per-platform: `aws ~> 5.0`, `azurerm ~> 4.0`, `google ~> 6.0`, `vsphere ~> 2.10`

## Testing

```bash
terraform init -backend=false
terraform test
```

## License

Apache-2.0. See [LICENSE](LICENSE).
