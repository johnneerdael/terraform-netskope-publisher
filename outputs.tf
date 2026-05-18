locals {
  publishers_by_platform = {
    aws   = try(module.aws[0].publishers, {})
    azure = try(module.azure[0].publishers, {})
  }
}

output "publishers" {
  description = "Map keyed by publisher name."
  value = {
    for name, p in local.publishers_by_platform[var.platform] : name => {
      publisher_id = p.publisher_id
      vm_id        = p.vm_id
      private_ip   = p.private_ip
      public_ip    = p.public_ip
      platform     = var.platform
    }
  }
  sensitive = true
}

output "registration_tokens" {
  description = "Map of publisher_name => registration_token."
  value       = { for n, p in local.publishers_by_platform[var.platform] : n => p.registration_token }
  sensitive   = true
}
