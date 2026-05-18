variables {
  tenant_url      = "https://tenant.example.goskope.com"
  api_token       = "MOCK-API-TOKEN"
  publisher_names = ["pub-a", "pub-b"]
}

mock_provider "http" {}

run "creates_missing_and_reuses_existing" {
  command = plan
  module {
    source = "./modules/registration"
  }

  override_data {
    target = data.http.list
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"publishers\":[{\"publisher_id\":101,\"publisher_name\":\"pub-a\"}]}}"
    }
  }

  override_data {
    target = data.http.create["pub-b"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"id\":202,\"name\":\"pub-b\"}}"
    }
  }

  override_data {
    target = data.http.token["pub-a"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"token\":\"MOCK-REG-TOKEN\"}}"
    }
  }

  override_data {
    target = data.http.token["pub-b"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"token\":\"MOCK-REG-TOKEN\"}}"
    }
  }

  assert {
    condition     = output.publishers["pub-a"].publisher_id == 101
    error_message = "Existing publisher pub-a should resolve to id 101"
  }

  assert {
    condition     = output.publishers["pub-b"].publisher_id == 202
    error_message = "Missing publisher pub-b should be created and resolve to id 202"
  }

  assert {
    condition     = output.publishers["pub-a"].existed_before == true
    error_message = "pub-a should report existed_before=true"
  }

  assert {
    condition     = output.publishers["pub-b"].existed_before == false
    error_message = "pub-b should report existed_before=false"
  }

  assert {
    condition     = nonsensitive(output.publishers["pub-a"].registration_token) == "MOCK-REG-TOKEN"
    error_message = "Token for pub-a should be MOCK-REG-TOKEN"
  }
}

run "lists_empty_creates_both" {
  command = plan
  module {
    source = "./modules/registration"
  }

  override_data {
    target = data.http.list
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"publishers\":[]}}"
    }
  }

  override_data {
    target = data.http.create["pub-a"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"id\":101,\"name\":\"pub-a\"}}"
    }
  }

  override_data {
    target = data.http.create["pub-b"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"id\":202,\"name\":\"pub-b\"}}"
    }
  }

  override_data {
    target = data.http.token["pub-a"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"token\":\"MOCK-REG-TOKEN\"}}"
    }
  }

  override_data {
    target = data.http.token["pub-b"]
    values = {
      status_code   = 200
      response_body = "{\"status\":\"success\",\"data\":{\"token\":\"MOCK-REG-TOKEN\"}}"
    }
  }

  assert {
    condition     = output.publishers["pub-a"].publisher_id == 101
    error_message = "pub-a should be created with id 101"
  }
  assert {
    condition     = output.publishers["pub-b"].publisher_id == 202
    error_message = "pub-b should be created with id 202"
  }
  assert {
    condition     = output.publishers["pub-a"].existed_before == false
    error_message = "pub-a should report existed_before=false"
  }
}
