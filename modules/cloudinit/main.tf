locals {
  effective_wizard_path = coalesce(var.wizard_path, "/home/${var.install_user}/npa_publisher_wizard")

  userdata = {
    for name, token in var.publishers : name => templatefile(
      "${path.module}/templates/user-data.yaml.tftpl",
      {
        publisher_name                   = name
        registration_token               = token
        wizard_path                      = local.effective_wizard_path
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
    )
  }

  metadata = {
    for name, _ in var.publishers : name => templatefile(
      "${path.module}/templates/meta-data.yaml.tftpl",
      { publisher_name = name }
    )
  }
}
