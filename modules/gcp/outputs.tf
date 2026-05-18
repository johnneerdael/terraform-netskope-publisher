output "publishers" {
  sensitive = true
  value = {
    for n in var.publisher_names : n => {
      publisher_id       = module.registration.publishers[n].publisher_id
      registration_token = module.registration.publishers[n].registration_token
      vm_id              = google_compute_instance.publisher[n].instance_id
      private_ip         = google_compute_instance.publisher[n].network_interface[0].network_ip
      public_ip          = try(google_compute_instance.publisher[n].network_interface[0].access_config[0].nat_ip, null)
    }
  }
}

output "instance_ids" {
  value = [for n in var.publisher_names : google_compute_instance.publisher[n].instance_id]
}

output "user_data_by_name" {
  value     = { for n in var.publisher_names : n => google_compute_instance.publisher[n].metadata["user-data"] }
  sensitive = true
}
