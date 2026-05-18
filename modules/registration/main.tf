locals {
  base_headers = {
    "Netskope-Api-Token" = var.api_token
    "Accept"             = "application/json"
    "Content-Type"       = "application/json"
  }

  api_base = "${trimsuffix(var.tenant_url, "/")}/api/v2/infrastructure/publishers"
}

# 1. List existing publishers.
data "http" "list" {
  url             = local.api_base
  method          = "GET"
  request_headers = local.base_headers

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "List publishers failed (status=${self.status_code}). Check netskope_tenant_url and netskope_api_token."
    }
  }
}

locals {
  list_decoded = jsondecode(data.http.list.response_body)

  existing_by_name = {
    for p in try(local.list_decoded.data.publishers, []) :
    p.publisher_name => tonumber(p.publisher_id)
  }

  names_to_create = [
    for n in var.publisher_names : n
    if !contains(keys(local.existing_by_name), n)
  ]
}

# 2. Create publishers that are missing.
data "http" "create" {
  for_each = toset(local.names_to_create)

  url             = local.api_base
  method          = "POST"
  request_headers = local.base_headers
  request_body    = jsonencode({ name = each.value })

  lifecycle {
    postcondition {
      condition     = self.status_code >= 200 && self.status_code < 300
      error_message = "Create publisher ${each.value} failed (status=${self.status_code}): ${self.response_body}"
    }
  }
}

locals {
  created_by_name = {
    for n, d in data.http.create :
    n => tonumber(jsondecode(d.response_body).data.id)
  }

  publisher_ids = {
    for n in var.publisher_names :
    n => coalesce(
      lookup(local.existing_by_name, n, null),
      lookup(local.created_by_name, n, null),
    )
  }
}

# 3. Generate a registration token per publisher.
data "http" "token" {
  for_each = local.publisher_ids

  url             = "${local.api_base}/${each.value}/registration_token"
  method          = "POST"
  request_headers = local.base_headers

  lifecycle {
    postcondition {
      condition     = self.status_code >= 200 && self.status_code < 300
      error_message = "Token generation for publisher ${each.key} (id=${each.value}) failed (status=${self.status_code})."
    }
  }
}
