module "registration" {
  source          = "../registration"
  tenant_url      = var.tenant_url
  api_token       = var.api_token
  publisher_names = var.publisher_names
}

module "cloudinit" {
  source      = "../cloudinit"
  publishers  = { for n, p in module.registration.publishers : n => p.registration_token }
  wizard_path = var.wizard_path
}

resource "azurerm_marketplace_agreement" "publisher" {
  count     = var.accept_marketplace_terms && var.marketplace != null ? 1 : 0
  publisher = var.marketplace.publisher
  offer     = var.marketplace.offer
  plan      = var.marketplace.sku
}

resource "azurerm_public_ip" "publisher" {
  for_each = var.assign_public_ip ? toset(var.publisher_names) : []

  name                = "${each.key}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "publisher" {
  for_each = toset(var.publisher_names)

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
  for_each = var.network_security_group_id == null ? toset([]) : toset(var.publisher_names)

  network_interface_id      = azurerm_network_interface.publisher[each.key].id
  network_security_group_id = var.network_security_group_id
}

resource "azurerm_linux_virtual_machine" "publisher" {
  for_each = toset(var.publisher_names)

  name                  = each.key
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.publisher[each.key].id]
  custom_data           = module.cloudinit.userdata_b64[each.key]
  tags                  = merge(var.tags, { Name = each.key })

  admin_ssh_key {
    username   = var.admin_username
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
    for_each = var.image_id == null && var.marketplace != null ? [var.marketplace] : []
    content {
      publisher = source_image_reference.value.publisher
      offer     = source_image_reference.value.offer
      sku       = source_image_reference.value.sku
      version   = source_image_reference.value.version
    }
  }

  lifecycle {
    precondition {
      condition     = var.image_id != null || var.marketplace != null
      error_message = "Provide either azure.image_id or azure.marketplace."
    }
  }
}
