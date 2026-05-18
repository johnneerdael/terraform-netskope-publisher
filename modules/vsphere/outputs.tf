output "publishers" {
  sensitive = true
  value = {
    for n in local.publisher_names : n => {
      publisher_id       = module.registration.publishers[n].publisher_id
      registration_token = module.registration.publishers[n].registration_token
      vm_id              = vsphere_virtual_machine.publisher[n].id
      private_ip         = vsphere_virtual_machine.publisher[n].default_ip_address
      public_ip          = null
    }
  }
}

output "vm_uuids" {
  value = [for n in local.publisher_names : vsphere_virtual_machine.publisher[n].uuid]
}

output "guestinfo_by_name" {
  value     = { for n in local.publisher_names : n => vsphere_virtual_machine.publisher[n].extra_config["guestinfo.userdata"] }
  sensitive = true
}

output "publisher_names" {
  description = "Derived publisher names (useful when name_prefix+replicas was used)."
  value       = local.publisher_names
}
