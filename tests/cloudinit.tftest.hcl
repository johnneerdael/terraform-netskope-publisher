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
