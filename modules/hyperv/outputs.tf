output "publishers" {
  description = "Map of publisher name => { publisher_id, vm_id, private_ip, public_ip, registration_token }."
  sensitive   = true
  value = {
    for n in local.publisher_names : n => {
      publisher_id       = module.registration.publishers[n].publisher_id
      registration_token = module.registration.publishers[n].registration_token
      vm_id              = hyperv_machine_instance.publisher[n].id
      # Hyper-V reports addresses asynchronously via KVP; surfacing them
      # would require a separate refresh step. Null here is consistent.
      private_ip = null
      public_ip  = null
    }
  }
}

output "publisher_names" {
  description = "Derived publisher names (useful when name_prefix+replicas was used)."
  value       = local.publisher_names
}

output "vm_ids" {
  description = "List of hyperv_machine_instance IDs in publisher-name order."
  value       = [for n in local.publisher_names : hyperv_machine_instance.publisher[n].id]
}

output "seed_iso_paths_by_name" {
  description = "Map of publisher name => seed ISO path on the host."
  value       = { for n in local.publisher_names : n => "${var.iso_dir}\\${n}-seed.iso" }
}
