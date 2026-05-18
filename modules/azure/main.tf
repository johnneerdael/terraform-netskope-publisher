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

locals {
  effective_admin_username = coalesce(var.admin_username, var.install_user)

  canonical_ubuntu_minimal_jammy = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-minimal-jammy"
    sku       = "minimal-22_04-lts-gen2"
    version   = "latest"
  }

  effective_marketplace = (
    var.marketplace != null
    ? var.marketplace
    : (var.bootstrap && var.image_id == null ? local.canonical_ubuntu_minimal_jammy : null)
  )
}

resource "azurerm_marketplace_agreement" "publisher" {
  count     = var.accept_marketplace_terms && var.marketplace != null ? 1 : 0
  publisher = var.marketplace.publisher
  offer     = var.marketplace.offer
  plan      = var.marketplace.sku
}

resource "azurerm_public_ip" "publisher" {
  for_each = var.assign_public_ip ? toset(local.publisher_names) : []

  name                = "${each.key}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "publisher" {
  for_each = toset(local.publisher_names)

  name                = "${each.key}-nic"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.assign_public_ip ? azurerm_public_ip.publisher[each.key].id : null
  }
}

resource "azurerm_network_interface_security_group_association" "publisher" {
  for_each = var.network_security_group_id == null ? toset([]) : toset(local.publisher_names)

  network_interface_id      = azurerm_network_interface.publisher[each.key].id
  network_security_group_id = var.network_security_group_id
}

resource "azurerm_linux_virtual_machine" "publisher" {
  for_each = toset(local.publisher_names)

  name                  = each.key
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = var.vm_size
  admin_username        = local.effective_admin_username
  network_interface_ids = [azurerm_network_interface.publisher[each.key].id]
  custom_data           = module.cloudinit.userdata_b64[each.key]
  tags                  = merge(var.tags, { Name = each.key })

  admin_ssh_key {
    username   = local.effective_admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk.type
    disk_size_gb         = var.os_disk.size_gb
  }

  source_image_id = var.image_id

  dynamic "plan" {
    for_each = var.image_id == null && var.marketplace != null ? [var.marketplace] : []
    content {
      publisher = plan.value.publisher
      product   = plan.value.offer
      name      = plan.value.sku
    }
  }

  dynamic "source_image_reference" {
    for_each = var.image_id == null && local.effective_marketplace != null ? [local.effective_marketplace] : []
    content {
      publisher = source_image_reference.value.publisher
      offer     = source_image_reference.value.offer
      sku       = source_image_reference.value.sku
      version   = source_image_reference.value.version
    }
  }

  lifecycle {
    precondition {
      condition     = var.image_id != null || local.effective_marketplace != null
      error_message = "Provide azure.image_id, azure.marketplace, or set azure.bootstrap = true to default to the Canonical Ubuntu 22.04 LTS Minimal marketplace image."
    }
  }
}
