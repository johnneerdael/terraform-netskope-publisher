locals {
  userdata = {
    for name, token in var.publishers : name => templatefile(
      "${path.module}/templates/user-data.yaml.tftpl",
      {
        publisher_name     = name
        registration_token = token
        wizard_path        = var.wizard_path
      }
    )
  }

  metadata = {
    for name, _ in var.publishers : name => templatefile(
      "${path.module}/templates/meta-data.yaml.tftpl",
      { publisher_name = name }
    )
  }
}
