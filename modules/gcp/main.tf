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

resource "google_compute_instance" "publisher" {
  for_each = toset(var.publisher_names)

  name         = each.key
  project      = var.project
  zone         = var.zone
  machine_type = var.machine_type
  tags         = var.network_tags
  labels       = var.tags

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork

    dynamic "access_config" {
      for_each = var.assign_public_ip ? [1] : []
      content {}
    }
  }

  metadata = {
    "user-data" = module.cloudinit.userdata_raw[each.key]
  }

  dynamic "service_account" {
    for_each = var.service_account == null ? [] : [var.service_account]
    content {
      email  = service_account.value.email
      scopes = service_account.value.scopes
    }
  }
}
