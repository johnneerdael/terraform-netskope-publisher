# Example: AWS, single publisher

Provisions one EC2 publisher. The example defaults to **bootstrap mode**
(v2.3+): the EC2 instance boots Canonical's official Ubuntu 22.04 LTS
Minimal AMI, cloud-init runs Netskope's generic `bootstrap.sh`, and the
Publisher self-registers using the token returned by the Netskope API.

```bash
cp terraform.tfvars.example terraform.tfvars
# edit tenant URL, API token, subnet, SG, key_name
terraform init
terraform apply
```

To use a pre-baked Netskope Publisher AMI instead (no script install),
set `bootstrap = false` on the module and pass `ami_id` explicitly:

```hcl
module "publisher" {
  source = "../../modules/aws"
  # ...
  bootstrap = false
  ami_id    = "ami-0123456789abcdef0" # Netskope marketplace AMI
}
```

The Netskope Publisher AMI lookup (owner `679593333241`) is skipped
whenever `bootstrap = true`, so callers don't need access to the
marketplace listing for the default path.
