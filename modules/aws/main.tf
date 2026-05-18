module "registration" {
  source          = "../registration"
  tenant_url      = var.tenant_url
  api_token       = var.api_token
  publisher_names = local.publisher_names
}

module "cloudinit" {
  source                           = "../cloudinit"
  publishers                       = { for n, p in module.registration.publishers : n => p.registration_token }
  wizard_path                      = var.wizard_path
  bootstrap                        = var.bootstrap
  bootstrap_url                    = var.bootstrap_url
  nonat                            = var.nonat
  install_user                     = var.install_user
  install_user_password            = var.install_user_password
  install_user_password_is_hash    = var.install_user_password_is_hash
  install_user_ssh_authorized_keys = var.install_user_ssh_authorized_keys
  delete_default_user              = var.delete_default_user
  guest_network_interface          = var.guest_network_interface
}

data "aws_ami" "publisher" {
  count       = var.ami_id == null && !var.bootstrap ? 1 : 0
  most_recent = true
  owners      = ["679593333241"]

  filter {
    name   = "name"
    values = ["Netskope Private Access Publisher*"]
  }
}

data "aws_ami" "ubuntu_minimal" {
  count       = var.ami_id == null && var.bootstrap ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu-minimal/images/hvm-ssd*/ubuntu-jammy-22.04-amd64-minimal-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  effective_ami = coalesce(
    var.ami_id,
    var.bootstrap ? try(data.aws_ami.ubuntu_minimal[0].id, null) : try(data.aws_ami.publisher[0].id, null),
  )
}

resource "aws_instance" "publisher" {
  for_each = toset(local.publisher_names)

  ami                         = local.effective_ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip_address
  iam_instance_profile        = var.iam_instance_profile
  ebs_optimized               = var.ebs_optimized
  monitoring                  = var.monitoring
  user_data_base64            = module.cloudinit.userdata_b64[each.key]

  metadata_options {
    http_endpoint = var.metadata_options.http_endpoint
    http_tokens   = var.metadata_options.http_tokens
  }

  tags = merge(var.tags, { Name = each.key })
}
