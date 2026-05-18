module "registration" {
  source          = "../registration"
  tenant_url      = var.tenant_url
  api_token       = var.api_token
  publisher_names = local.publisher_names
}

module "cloudinit" {
  source      = "../cloudinit"
  publishers  = { for n, p in module.registration.publishers : n => p.registration_token }
  wizard_path = var.wizard_path
}

data "aws_ami" "publisher" {
  most_recent = true
  owners      = ["679593333241"]

  filter {
    name   = "name"
    values = ["Netskope Private Access Publisher*"]
  }
}

resource "aws_instance" "publisher" {
  for_each = toset(local.publisher_names)

  ami                         = coalesce(var.ami_id, data.aws_ami.publisher.id)
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
