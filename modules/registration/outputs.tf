output "publishers" {
  description = "Map of publisher name => { publisher_id, registration_token, existed_before }."
  sensitive   = true
  value = {
    for n in var.publisher_names : n => {
      publisher_id       = local.publisher_ids[n]
      registration_token = jsondecode(data.http.token[n].response_body).data.token
      existed_before     = contains(keys(local.existing_by_name), n)
    }
  }
}
