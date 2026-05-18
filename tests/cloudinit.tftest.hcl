variables {
  publishers = {
    "pub-a" = "TOKEN-A"
    "pub-b" = "TOKEN-B"
  }
}

run "renders_userdata_for_each_publisher" {
  command = plan
  module {
    source = "./modules/cloudinit"
  }

  assert {
    condition     = length(keys(output.userdata_raw)) == 2
    error_message = "Expected userdata_raw to contain two entries"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "/home/ubuntu/npa_publisher_wizard")
    error_message = "userdata for pub-a missing wizard path"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "TOKEN-A")
    error_message = "userdata for pub-a missing its token"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-b"], "TOKEN-B")
    error_message = "userdata for pub-b missing its token"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "hostname: pub-a")
    error_message = "userdata for pub-a missing hostname"
  }

  assert {
    condition     = length(output.userdata_b64["pub-a"]) > 0
    error_message = "userdata_b64 for pub-a is empty"
  }

  assert {
    condition     = strcontains(base64decode(output.metadata_b64["pub-a"]), "local-hostname: pub-a")
    error_message = "metadata_b64 for pub-a missing local-hostname"
  }
}

run "renders_bootstrap_and_nonat" {
  command = plan
  module {
    source = "./modules/cloudinit"
  }

  variables {
    bootstrap = true
    nonat     = true
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "bootstrap.sh")
    error_message = "bootstrap mode missing bootstrap.sh curl"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "/home/ubuntu/resources/.nonat")
    error_message = "nonat mode missing /home/ubuntu/resources/.nonat"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "chmod 1777 /tmp")
    error_message = "bootstrap mode missing /tmp permission fix"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "TOKEN-A")
    error_message = "bootstrap mode missing registration token"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "su - ubuntu -c 'sudo /home/ubuntu/npa_publisher_wizard")
    error_message = "enrollment must run as install_user from their home"
  }
}

run "renders_custom_user_replaces_ubuntu" {
  command = plan
  module {
    source = "./modules/cloudinit"
  }

  variables {
    bootstrap                        = true
    nonat                            = true
    install_user                     = "npa"
    install_user_password            = "S3cret-Passw0rd!"
    install_user_ssh_authorized_keys = ["ssh-ed25519 AAAA fake-key-for-tests"]
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "name: npa")
    error_message = "custom install_user not declared in users block"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "/home/npa/npa_publisher_wizard")
    error_message = "wizard_path did not derive from custom install_user"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "userdel -r ubuntu")
    error_message = "default ubuntu user not removed when delete_default_user defaulted true"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "ssh-ed25519 AAAA fake-key-for-tests")
    error_message = "ssh authorized key not rendered"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "S3cret-Passw0rd!")
    error_message = "install_user_password not rendered in chpasswd"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "su - npa -c 'curl -fsSL")
    error_message = "bootstrap must run as the new install_user"
  }
}

run "renders_static_network_override" {
  command = plan
  module {
    source = "./modules/cloudinit"
  }

  variables {
    bootstrap = true
    guest_network_interface = {
      name        = "ens4"
      dhcp4       = false
      addresses   = ["10.0.0.5/24"]
      gateway4    = "10.0.0.1"
      nameservers = ["8.8.8.8", "1.1.1.1"]
      mtu         = 1460
    }
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "60-cloudinit-override.yaml")
    error_message = "netplan override file not written"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "addresses:\n              - 10.0.0.5/24")
    error_message = "static address not rendered in netplan config"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "gateway4: 10.0.0.1")
    error_message = "gateway not rendered in netplan config"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "mtu: 1460")
    error_message = "mtu not rendered in netplan config"
  }

  assert {
    condition     = strcontains(output.userdata_raw["pub-a"], "netplan apply")
    error_message = "netplan apply not in runcmd"
  }
}
