module "registration" {
  source          = "../registration"
  tenant_url      = var.tenant_url
  api_token       = var.api_token
  publisher_names = local.publisher_names
}

module "cloudinit" {
  source      = "../cloudinit"
  publishers  = { for n, p in module.registration.publishers : n => p.registration_token }
  wizard_path = var.wizard_path
}

data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_compute_cluster" "cluster" {
  count         = var.cluster != null ? 1 : 0
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_host" "host" {
  count         = var.host != null ? 1 : 0
  name          = var.host
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "ds" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "net" {
  name          = var.network_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_virtual_machine" "publisher" {
  for_each = toset(local.publisher_names)

  name             = each.key
  resource_pool_id = var.cluster != null ? data.vsphere_compute_cluster.cluster[0].resource_pool_id : data.vsphere_host.host[0].resource_pool_id
  datastore_id     = data.vsphere_datastore.ds.id
  folder           = var.folder

  num_cpus = var.num_cpus
  memory   = var.memory
  guest_id = data.vsphere_virtual_machine.template.guest_id

  network_interface {
    network_id   = data.vsphere_network.net.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks[0].size
    eagerly_scrub    = data.vsphere_virtual_machine.template.disks[0].eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.template.disks[0].thin_provisioned
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }

  extra_config = {
    "guestinfo.userdata"          = module.cloudinit.userdata_b64[each.key]
    "guestinfo.userdata.encoding" = "base64"
    "guestinfo.metadata"          = module.cloudinit.metadata_b64[each.key]
    "guestinfo.metadata.encoding" = "base64"
  }

  # vSphere custom_attributes require pre-created vsphere_custom_attribute
  # resources (admin-defined in vCenter); var.tags is ignored here. Users who
  # need them can wrap the module or pass attribute IDs upstream.

  lifecycle {
    precondition {
      condition     = var.cluster != null || var.host != null
      error_message = "Provide either vsphere.cluster or vsphere.host."
    }
    ignore_changes = [ovf_deploy]
  }
}
