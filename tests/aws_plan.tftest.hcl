variables {
  name_prefix        = "pub-eu"
  replicas           = 2
  tenant_url         = "https://tenant.example.goskope.com"
  api_token          = "MOCK-API-TOKEN"
  subnet_id          = "subnet-0123456789abcdef0"
  security_group_ids = ["sg-0123456789abcdef0"]
  key_name           = "test-key"
  instance_type      = "t3.medium"
}

mock_provider "aws" {}
mock_provider "http" {}

run "aws_plan_produces_two_instances_with_userdata" {
  command = plan
  module {
    source = "./modules/aws"
  }

  override_data {
    target = module.registration.data.http.list
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"publishers\":[]}}"
    }
  }

  override_data {
    target = module.registration.data.http.create["pub-eu-1"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"id\":1,\"name\":\"pub-eu-1\"}}"
    }
  }

  override_data {
    target = module.registration.data.http.create["pub-eu-2"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"id\":2,\"name\":\"pub-eu-2\"}}"
    }
  }

  override_data {
    target = module.registration.data.http.token["pub-eu-1"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"token\":\"TOKEN-1\"}}"
    }
  }

  override_data {
    target = module.registration.data.http.token["pub-eu-2"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"token\":\"TOKEN-2\"}}"
    }
  }

  override_data {
    target = data.aws_ami.publisher[0]
    values = {
      id = "ami-0123456789abcdef0"
    }
  }

  assert {
    condition     = length(output.aws_instance_ids) == 2
    error_message = "Expected 2 aws_instance resources"
  }

  assert {
    condition     = length(nonsensitive(output.userdata_b64_by_name["pub-eu-1"])) > 0
    error_message = "userdata for pub-eu-1 should be non-empty"
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(output.userdata_b64_by_name["pub-eu-1"])), "TOKEN-1")
    error_message = "userdata for pub-eu-1 should contain TOKEN-1"
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(output.userdata_b64_by_name["pub-eu-1"])), "/home/ubuntu/npa_publisher_wizard")
    error_message = "userdata for pub-eu-1 should contain wizard path"
  }
}

run "aws_bootstrap_mode_uses_canonical_ubuntu_ami" {
  command = plan
  module {
    source = "./modules/aws"
  }

  variables {
    bootstrap = true
  }

  override_data {
    target = module.registration.data.http.list
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"publishers\":[]}}"
    }
  }

  override_data {
    target = module.registration.data.http.create["pub-eu-1"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"id\":1,\"name\":\"pub-eu-1\"}}"
    }
  }

  override_data {
    target = module.registration.data.http.create["pub-eu-2"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"id\":2,\"name\":\"pub-eu-2\"}}"
    }
  }

  override_data {
    target = module.registration.data.http.token["pub-eu-1"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"token\":\"TOKEN-1\"}}"
    }
  }

  override_data {
    target = module.registration.data.http.token["pub-eu-2"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"token\":\"TOKEN-2\"}}"
    }
  }

  override_data {
    target = data.aws_ami.ubuntu_minimal[0]
    values = {
      id = "ami-canonicalubuntu000"
    }
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(output.userdata_b64_by_name["pub-eu-1"])), "bootstrap.sh")
    error_message = "bootstrap mode should embed bootstrap.sh in user-data"
  }

  assert {
    condition     = strcontains(base64decode(nonsensitive(output.userdata_b64_by_name["pub-eu-1"])), "su - ubuntu -c 'curl -fsSL")
    error_message = "bootstrap must run as install_user (ubuntu by default)"
  }

  assert {
    condition     = length(output.aws_instance_ids) == 2
    error_message = "Expected 2 instances in bootstrap mode"
  }
}
