output "publishers" {
  description = "Map of publisher name => { publisher_id, vm_id, private_ip, public_ip, registration_token }."
  sensitive   = true
  value = {
    for n in var.publisher_names : n => {
      publisher_id       = module.registration.publishers[n].publisher_id
      registration_token = module.registration.publishers[n].registration_token
      vm_id              = aws_instance.publisher[n].id
      private_ip         = aws_instance.publisher[n].private_ip
      public_ip          = aws_instance.publisher[n].public_ip
    }
  }
}

# Test-friendly helpers.
output "aws_instance_ids" {
  value = [for n in var.publisher_names : aws_instance.publisher[n].id]
}

output "userdata_b64_by_name" {
  value     = { for n in var.publisher_names : n => aws_instance.publisher[n].user_data_base64 }
  sensitive = true
}
