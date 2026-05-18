# terraform-netskope-publisher

Provision Netskope Private Access Publishers on **AWS**, **Azure**, **GCP**, or
**vSphere** from a single Terraform module. Publishers are created via the
Netskope NPA API and registered on first boot through cloud-init — no
out-of-band wizard runs.

## Quick start

```hcl
module "publisher" {
  source   = "github.com/johnneerdael/terraform-netskope-publisher?ref=v1.0.0"
  platform = "aws"

  name_prefix = "pub-eu"
  replicas    = 2

  netskope_tenant_url = "https://tenant.goskope.com"
  netskope_api_token  = var.netskope_api_token

  aws = {
    subnet_id          = "subnet-…"
    security_group_ids = ["sg-…"]
    key_name           = "my-key"
  }
}
```

Switch platform by changing `platform = "azure"` / `"gcp"` / `"vsphere"` and
populating the matching input object.

## Inputs (common)

| Name | Type | Default | Description |
|---|---|---|---|
| `platform` | string | — | `aws` \| `azure` \| `gcp` \| `vsphere` |
| `name_prefix` | string | `"npa-publisher"` | Used when `names` is null |
| `names` | list(string) | `null` | Explicit publisher names |
| `replicas` | number | `1` | Number of publishers when `names` is null |
| `tags` | map(string) | `{}` | Tags / labels per platform |
| `netskope_tenant_url` | string | — | e.g. `https://tenant.goskope.com` |
| `netskope_api_token` | string (sensitive) | — | NPA API token |
| `wizard_path` | string | `/home/ubuntu/npa_publisher_wizard` | On-VM wizard path |

Platform-specific inputs live in each submodule's `variables.tf`. See the
examples in `examples/`.

## Outputs

```hcl
output "publishers" {
  # Map: name => { publisher_id, vm_id, private_ip, public_ip, platform }
  # sensitive (contains registration_token transitively)
}

output "registration_tokens" {
  # Map: name => token (sensitive)
}
```

## Registration flow

1. `data "http" "list"` → `GET /api/v2/infrastructure/publishers`
2. For each name missing in the response → `POST /publishers`
3. For every name → `POST /publishers/{id}/registration_token`
4. Cloud-init runcmd on the VM: `/home/ubuntu/npa_publisher_wizard -token <token>`

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

Plan-time tests cover the cloud-init renderer, the Netskope API registration
flow, and the AWS submodule end-to-end with mocked providers. The
`azurerm`/`google`/`vsphere` providers authenticate at configure time even for
`command = plan`, so those submodules are covered by `terraform validate`
(per submodule + per example) plus the runnable examples in `examples/`.

## License

Apache-2.0. See [LICENSE](LICENSE).
