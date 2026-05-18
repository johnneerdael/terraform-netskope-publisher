output "userdata_raw" {
  description = "Map of publisher name => rendered cloud-init user-data (string)."
  value       = local.userdata
  sensitive   = true
}

output "userdata_b64" {
  description = "Map of publisher name => base64-encoded user-data."
  value       = { for n, u in local.userdata : n => base64encode(u) }
  sensitive   = true
}

output "metadata_b64" {
  description = "Map of publisher name => base64-encoded NoCloud meta-data."
  value       = nonsensitive({ for n, m in local.metadata : n => base64encode(m) })
}
