# Per-platform module blocks are added by subsequent tasks:
#   modules/aws     (Task 5)
#   modules/azure   (Task 7)
#   modules/gcp     (Task 9)
#   modules/vsphere (Task 11)

# Root-level precondition: the platform-matched input object must be present.
resource "terraform_data" "platform_input_check" {
  lifecycle {
    precondition {
      condition = (
        (var.platform == "aws" && var.aws != null) ||
        (var.platform == "azure" && var.azure != null) ||
        (var.platform == "gcp" && var.gcp != null) ||
        (var.platform == "vsphere" && var.vsphere != null)
      )
      error_message = "var.${var.platform} must be set when platform = \"${var.platform}\"."
    }
  }
}

module "aws" {
  source = "./modules/aws"
  count  = var.platform == "aws" ? 1 : 0

  publisher_names = local.publisher_names
  tenant_url      = var.netskope_tenant_url
  api_token       = var.netskope_api_token
  wizard_path     = var.wizard_path
  tags            = var.tags

  subnet_id                   = try(var.aws.subnet_id, null)
  security_group_ids          = try(var.aws.security_group_ids, [])
  key_name                    = try(var.aws.key_name, null)
  instance_type               = try(var.aws.instance_type, "t3.medium")
  ami_id                      = try(var.aws.ami_id, null)
  associate_public_ip_address = try(var.aws.associate_public_ip_address, false)
  iam_instance_profile        = try(var.aws.iam_instance_profile, null)
  ebs_optimized               = try(var.aws.ebs_optimized, true)
  monitoring                  = try(var.aws.monitoring, true)
  metadata_options            = try(var.aws.metadata_options, {})
}
