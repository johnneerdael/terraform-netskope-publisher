# This repository is NOT a Terraform module on its own. Source one of the
# platform submodules instead:
#
#   module "publisher" {
#     source = "github.com/johnneerdael/terraform-netskope-publisher//modules/aws?ref=v2.0.0"
#     # ...
#   }
#
# Supported platforms: aws | azure | gcp | vsphere.
# See https://johnneerdael.github.io/terraform-netskope-publisher/ for guides.

terraform {
  required_version = ">= 1.7"
}
