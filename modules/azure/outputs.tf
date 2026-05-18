output "publishers" {
  sensitive = true
  value = {
    for n in local.publisher_names : n => {
      publisher_id       = module.registration.publishers[n].publisher_id
      registration_token = module.registration.publishers[n].registration_token
      vm_id              = azurerm_linux_virtual_machine.publisher[n].id
      private_ip         = azurerm_network_interface.publisher[n].private_ip_address
      public_ip          = var.assign_public_ip ? azurerm_public_ip.publisher[n].ip_address : null
    }
  }
}

output "vm_ids" {
  value = [for n in local.publisher_names : azurerm_linux_virtual_machine.publisher[n].id]
}

output "custom_data_by_name" {
  value     = { for n in local.publisher_names : n => azurerm_linux_virtual_machine.publisher[n].custom_data }
  sensitive = true
}

output "publisher_names" {
  description = "Derived publisher names (useful when name_prefix+replicas was used)."
  value       = local.publisher_names
}
