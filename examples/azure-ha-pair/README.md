# Example: Azure, HA pair

Provisions two `azurerm_linux_virtual_machine` publishers in the same
subnet. The example defaults to **bootstrap mode** (v2.3+): each VM boots
Canonical's Ubuntu 22.04 LTS Minimal marketplace image
(`Canonical / 0001-com-ubuntu-minimal-jammy / minimal-22_04-lts-gen2`),
cloud-init runs Netskope's `bootstrap.sh`, and the Publisher self-registers
using the token returned by the Netskope API.

```bash
cp terraform.tfvars.example terraform.tfvars
# edit tenant URL, API token, RG, subnet ID, SSH public key
terraform init
terraform apply
```

The `azure_image_id` variable is now optional — leave it unset to take
the Canonical default. To use a pre-baked Netskope Publisher image
instead, set both:

```hcl
module "publisher" {
  source = "../../modules/azure"
  # ...
  bootstrap = false
  image_id  = "/subscriptions/.../Microsoft.Compute/images/netskope-publisher"
}
```

The Canonical default needs no marketplace-terms acceptance (no `plan {}`
block is emitted). Netskope's marketplace image still works via the
existing `marketplace` + `accept_marketplace_terms` inputs.
