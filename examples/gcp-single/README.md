# Example: GCP, single publisher

Provisions one `google_compute_instance` publisher on the public Ubuntu 22.04
LTS Minimal image (`projects/ubuntu-os-cloud/global/images/family/ubuntu-minimal-2204-lts`).
Cloud-init runs Netskope's generic `bootstrap.sh`, enables No-NAT mode
(`~ubuntu/resources/.nonat`), and registers the Publisher with the
registration token returned by the Netskope API.

Set `var.image` to a pre-baked Netskope Publisher image and set
`bootstrap = false`, `nonat = false` on the module if you want to skip the
script install.

Configure `terraform.tfvars` and run `terraform init && terraform apply`.
