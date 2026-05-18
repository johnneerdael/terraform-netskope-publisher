# Cross-Platform Netskope Publisher Module — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Terraform module that provisions Netskope Private Access Publishers on AWS, Azure, GCP, and vSphere from one consistent interface, with API-driven registration and cloud-init-based token delivery.

**Architecture:** Root module routes on `var.platform` to one of `modules/aws|azure|gcp|vsphere`. Each platform submodule calls shared `modules/registration` (Netskope API via `http` provider) and `modules/cloudinit` (renders user-data containing `/home/ubuntu/npa_publisher_wizard -token <token>`), then provisions VMs with `for_each` over publisher names.

**Tech Stack:** Terraform >= 1.7 (for `mock_provider`), `hashicorp/http` >= 3.4, `hashicorp/cloudinit` >= 2.3, `hashicorp/aws` ~> 5.0, `hashicorp/azurerm` ~> 4.0, `hashicorp/google` ~> 6.0, `vmware/vsphere` ~> 2.10. Tests use `terraform test` with `.tftest.hcl` and mocked providers.

**Spec:** `docs/superpowers/specs/2026-05-18-cross-platform-publisher-module-design.md`

**Working directory:** `/Users/jneerdael/Scripts/terraform-netskope-publisher` (repo already bootstrapped: `main` branch with `README.md` + spec, pushed to `origin`).

---

## Task 1: Repository foundations

**Files:**
- Create: `LICENSE`
- Create: `.gitignore`
- Create: `versions.tf`
- Create: `CHANGELOG.md`

- [ ] **Step 1: Add `.gitignore`**

Create `.gitignore`:

```
# Terraform
*.tfstate
*.tfstate.*
*.tfstate.backup
.terraform/
.terraform.lock.hcl
crash.log
crash.*.log
*.tfvars
*.tfvars.json
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc

# OS
.DS_Store

# Editors
.idea/
.vscode/
*.swp
```

- [ ] **Step 2: Add `LICENSE`**

Copy the Apache 2.0 license text from the source repo:

```bash
cp /Users/jneerdael/Scripts/terraform-netskope-publisher-aws/LICENSE LICENSE
```

Open `LICENSE` and change the copyright line at the bottom (if present) to: `Copyright 2026 John Neerdael`. Leave the rest unchanged.

- [ ] **Step 3: Add root `versions.tf`**

Create `versions.tf`:

```hcl
terraform {
  required_version = ">= 1.7"

  required_providers {
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.3"
    }
  }
}
```

- [ ] **Step 4: Add `CHANGELOG.md`**

Create `CHANGELOG.md`:

```markdown
# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
```

- [ ] **Step 5: Verify formatting**

Run: `terraform fmt -recursive -check`
Expected: exit 0, no output.

- [ ] **Step 6: Commit**

```bash
git add LICENSE .gitignore versions.tf CHANGELOG.md
git commit -m "chore: add license, gitignore, versions.tf, changelog"
git push
```

---

## Task 2: `modules/cloudinit` — render user-data

**Files:**
- Create: `modules/cloudinit/versions.tf`
- Create: `modules/cloudinit/variables.tf`
- Create: `modules/cloudinit/main.tf`
- Create: `modules/cloudinit/outputs.tf`
- Create: `modules/cloudinit/templates/user-data.yaml.tftpl`
- Create: `modules/cloudinit/templates/meta-data.yaml.tftpl`
- Create: `tests/cloudinit.tftest.hcl`

- [ ] **Step 1: Write the failing test**

Create `tests/cloudinit.tftest.hcl`:

```hcl
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `terraform test`
Expected: FAIL — `Module not installed` for `./modules/cloudinit`.

- [ ] **Step 3: Create `modules/cloudinit/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.7"

  required_providers {
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.3"
    }
  }
}
```

- [ ] **Step 4: Create `modules/cloudinit/variables.tf`**

```hcl
variable "publishers" {
  description = "Map of publisher name => registration token."
  type        = map(string)
  sensitive   = true
}

variable "wizard_path" {
  description = "Absolute path to npa_publisher_wizard on the VM."
  type        = string
  default     = "/home/ubuntu/npa_publisher_wizard"
}
```

- [ ] **Step 5: Create `modules/cloudinit/templates/user-data.yaml.tftpl`**

```yaml
#cloud-config
hostname: ${publisher_name}
preserve_hostname: false
runcmd:
  - [ ${wizard_path}, -token, "${registration_token}" ]
```

- [ ] **Step 6: Create `modules/cloudinit/templates/meta-data.yaml.tftpl`**

```yaml
instance-id: ${publisher_name}
local-hostname: ${publisher_name}
```

- [ ] **Step 7: Create `modules/cloudinit/main.tf`**

```hcl
locals {
  userdata = {
    for name, token in var.publishers : name => templatefile(
      "${path.module}/templates/user-data.yaml.tftpl",
      {
        publisher_name     = name
        registration_token = token
        wizard_path        = var.wizard_path
      }
    )
  }

  metadata = {
    for name, _ in var.publishers : name => templatefile(
      "${path.module}/templates/meta-data.yaml.tftpl",
      { publisher_name = name }
    )
  }
}
```

- [ ] **Step 8: Create `modules/cloudinit/outputs.tf`**

```hcl
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
  value       = { for n, m in local.metadata : n => base64encode(m) }
}
```

- [ ] **Step 9: Run test to verify it passes**

Run: `terraform test`
Expected: `1 passed, 0 failed.`

- [ ] **Step 10: Commit**

```bash
terraform fmt -recursive
git add modules/cloudinit tests/cloudinit.tftest.hcl
git commit -m "feat(cloudinit): render user-data and metadata per publisher"
git push
```

---

## Task 3: `modules/registration` — Netskope API → publisher_id + token

**Files:**
- Create: `modules/registration/versions.tf`
- Create: `modules/registration/variables.tf`
- Create: `modules/registration/main.tf`
- Create: `modules/registration/outputs.tf`
- Create: `tests/registration.tftest.hcl`
- Create: `tests/fixtures/registration/list_with_pub_a.json`
- Create: `tests/fixtures/registration/list_empty.json`
- Create: `tests/fixtures/registration/create_pub_a.json`
- Create: `tests/fixtures/registration/create_pub_b.json`
- Create: `tests/fixtures/registration/token_response.json`

> **Note on test approach:** Terraform's `mock_provider` block lets us provide
> canned responses for `data "http"` calls. Because `data "http"` has only one
> resource type ("http"), we use `override_data` blocks inside the `run` block
> to give each addressed data source a distinct response body. The fixtures
> exist as files for readability but get inlined in the `.tftest.hcl` via
> `file()`.

- [ ] **Step 1: Create fixture files**

Create `tests/fixtures/registration/list_with_pub_a.json`:

```json
{
  "status": "success",
  "data": {
    "publishers": [
      { "publisher_id": 101, "publisher_name": "pub-a" }
    ]
  }
}
```

Create `tests/fixtures/registration/list_empty.json`:

```json
{ "status": "success", "data": { "publishers": [] } }
```

Create `tests/fixtures/registration/create_pub_a.json`:

```json
{ "status": "success", "data": { "publisher_id": 101, "publisher_name": "pub-a" } }
```

Create `tests/fixtures/registration/create_pub_b.json`:

```json
{ "status": "success", "data": { "publisher_id": 202, "publisher_name": "pub-b" } }
```

Create `tests/fixtures/registration/token_response.json`:

```json
{ "status": "success", "data": { "token": "MOCK-REG-TOKEN" } }
```

- [ ] **Step 2: Write the failing test — "publisher missing, gets created"**

Create `tests/registration.tftest.hcl`:

```hcl
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
      response_body = file("${path.module}/tests/fixtures/registration/list_with_pub_a.json")
    }
  }

  override_data {
    target = data.http.create["pub-b"]
    values = {
      status_code   = 200
      response_body = file("${path.module}/tests/fixtures/registration/create_pub_b.json")
    }
  }

  override_data {
    target = data.http.token["pub-a"]
    values = {
      status_code   = 200
      response_body = file("${path.module}/tests/fixtures/registration/token_response.json")
    }
  }

  override_data {
    target = data.http.token["pub-b"]
    values = {
      status_code   = 200
      response_body = file("${path.module}/tests/fixtures/registration/token_response.json")
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
      response_body = file("${path.module}/tests/fixtures/registration/list_empty.json")
    }
  }

  override_data {
    target = data.http.create["pub-a"]
    values = {
      status_code   = 200
      response_body = file("${path.module}/tests/fixtures/registration/create_pub_a.json")
    }
  }

  override_data {
    target = data.http.create["pub-b"]
    values = {
      status_code   = 200
      response_body = file("${path.module}/tests/fixtures/registration/create_pub_b.json")
    }
  }

  override_data {
    target = data.http.token["pub-a"]
    values = {
      status_code   = 200
      response_body = file("${path.module}/tests/fixtures/registration/token_response.json")
    }
  }

  override_data {
    target = data.http.token["pub-b"]
    values = {
      status_code   = 200
      response_body = file("${path.module}/tests/fixtures/registration/token_response.json")
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
```

- [ ] **Step 3: Run test to verify it fails**

Run: `terraform test`
Expected: FAIL — `Module not installed` for `./modules/registration`.

- [ ] **Step 4: Create `modules/registration/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.7"

  required_providers {
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
  }
}
```

- [ ] **Step 5: Create `modules/registration/variables.tf`**

```hcl
variable "tenant_url" {
  description = "Netskope tenant URL, e.g. https://tenant.goskope.com."
  type        = string

  validation {
    condition     = can(regex("^https://", var.tenant_url))
    error_message = "tenant_url must start with https://."
  }
}

variable "api_token" {
  description = "Netskope NPA API token."
  type        = string
  sensitive   = true
}

variable "publisher_names" {
  description = "Publisher names to ensure exist in the tenant."
  type        = list(string)

  validation {
    condition     = length(var.publisher_names) > 0
    error_message = "publisher_names must contain at least one name."
  }
}
```

- [ ] **Step 6: Create `modules/registration/main.tf`**

```hcl
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
  request_body    = jsonencode({ publisher_name = each.value })

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
    n => tonumber(jsondecode(d.response_body).data.publisher_id)
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
```

- [ ] **Step 7: Create `modules/registration/outputs.tf`**

```hcl
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
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `terraform test`
Expected: `2 passed, 0 failed.`

- [ ] **Step 9: Commit**

```bash
terraform fmt -recursive
git add modules/registration tests/registration.tftest.hcl tests/fixtures/registration
git commit -m "feat(registration): list/create publisher via Netskope API and emit registration token"
git push
```

---

## Task 4: Root module wiring (no platform yet)

**Files:**
- Create: `variables.tf`
- Create: `main.tf`
- Create: `locals.tf`

> Goal of this task: produce the root module skeleton that derives publisher
> names and validates `var.platform`. `outputs.tf` is intentionally NOT
> created here because Terraform validates module references statically —
> referencing `module.aws[0].publishers` before `module "aws"` is declared
> fails validation. Outputs are created in Task 5 (first platform) and
> extended by each subsequent platform task.

- [ ] **Step 1: Create `variables.tf`**

```hcl
variable "platform" {
  description = "Target platform: aws | azure | gcp | vsphere."
  type        = string

  validation {
    condition     = contains(["aws", "azure", "gcp", "vsphere"], var.platform)
    error_message = "platform must be one of: aws, azure, gcp, vsphere."
  }
}

variable "name_prefix" {
  description = "Prefix used to derive publisher names when var.names is null."
  type        = string
  default     = "npa-publisher"
}

variable "names" {
  description = "Explicit publisher names. When set, overrides name_prefix + replicas."
  type        = list(string)
  default     = null
}

variable "replicas" {
  description = "Number of publishers to create when var.names is null."
  type        = number
  default     = 1

  validation {
    condition     = var.replicas >= 1
    error_message = "replicas must be >= 1."
  }
}

variable "tags" {
  description = "Map of tags / labels applied per platform."
  type        = map(string)
  default     = {}
}

variable "netskope_tenant_url" {
  description = "Netskope tenant URL, e.g. https://tenant.goskope.com."
  type        = string
}

variable "netskope_api_token" {
  description = "Netskope NPA API token."
  type        = string
  sensitive   = true
}

variable "wizard_path" {
  description = "Absolute path to npa_publisher_wizard on the VM."
  type        = string
  default     = "/home/ubuntu/npa_publisher_wizard"
}

variable "aws" {
  description = "AWS-specific inputs (see modules/aws/variables.tf)."
  type        = any
  default     = null
}

variable "azure" {
  description = "Azure-specific inputs (see modules/azure/variables.tf)."
  type        = any
  default     = null
}

variable "gcp" {
  description = "GCP-specific inputs (see modules/gcp/variables.tf)."
  type        = any
  default     = null
}

variable "vsphere" {
  description = "vSphere-specific inputs (see modules/vsphere/variables.tf)."
  type        = any
  default     = null
}
```

- [ ] **Step 2: Create `locals.tf`**

```hcl
locals {
  publisher_names = var.names != null ? var.names : [
    for i in range(var.replicas) :
    format("%s-%d", var.name_prefix, i + 1)
  ]
}
```

- [ ] **Step 3: Create `main.tf`** (platform module calls added per task)

```hcl
# Per-platform module blocks are added by subsequent tasks:
#   modules/aws     (Task 5)
#   modules/azure   (Task 7)
#   modules/gcp     (Task 9)
#   modules/vsphere (Task 11)

# Root-level precondition: the platform-matched input object must be present.
resource "terraform_data" "platform_input_check" {
  lifecycle {
    precondition {
      condition = (
        (var.platform == "aws" && var.aws != null) ||
        (var.platform == "azure" && var.azure != null) ||
        (var.platform == "gcp" && var.gcp != null) ||
        (var.platform == "vsphere" && var.vsphere != null)
      )
      error_message = "var.${var.platform} must be set when platform = \"${var.platform}\"."
    }
  }
}
```

- [ ] **Step 4: Validate**

Run: `terraform init -backend=false && terraform validate`
Expected: `Success! The configuration is valid.`

- [ ] **Step 5: Commit**

```bash
terraform fmt -recursive
git add variables.tf locals.tf main.tf
git commit -m "feat(root): scaffold root module variables, locals, and platform precondition"
git push
```

---

## Task 5: `modules/aws` — AWS EC2 submodule

**Files:**
- Create: `modules/aws/versions.tf`
- Create: `modules/aws/variables.tf`
- Create: `modules/aws/main.tf`
- Create: `modules/aws/outputs.tf`
- Create: `tests/aws_plan.tftest.hcl`
- Create: `outputs.tf` (root) — first platform creates it
- Modify: `main.tf` (root) — add `module "aws"` block

- [ ] **Step 1: Write the failing test**

Create `tests/aws_plan.tftest.hcl`:

```hcl
variables {
  platform            = "aws"
  name_prefix         = "pub-eu"
  replicas            = 2
  netskope_tenant_url = "https://tenant.example.goskope.com"
  netskope_api_token  = "MOCK-API-TOKEN"

  aws = {
    subnet_id          = "subnet-0123456789abcdef0"
    security_group_ids = ["sg-0123456789abcdef0"]
    key_name           = "test-key"
    instance_type      = "t3.medium"
  }
}

mock_provider "aws" {}
mock_provider "http" {}

override_data {
  target = module.aws[0].module.registration.data.http.list
  values = {
    status_code   = 200
    response_body = "{\"status\":\"success\",\"data\":{\"publishers\":[]}}"
  }
}

override_data {
  target = module.aws[0].module.registration.data.http.create["pub-eu-1"]
  values = {
    status_code   = 200
    response_body = "{\"status\":\"success\",\"data\":{\"publisher_id\":1,\"publisher_name\":\"pub-eu-1\"}}"
  }
}

override_data {
  target = module.aws[0].module.registration.data.http.create["pub-eu-2"]
  values = {
    status_code   = 200
    response_body = "{\"status\":\"success\",\"data\":{\"publisher_id\":2,\"publisher_name\":\"pub-eu-2\"}}"
  }
}

override_data {
  target = module.aws[0].module.registration.data.http.token["pub-eu-1"]
  values = {
    status_code   = 200
    response_body = "{\"status\":\"success\",\"data\":{\"token\":\"TOKEN-1\"}}"
  }
}

override_data {
  target = module.aws[0].module.registration.data.http.token["pub-eu-2"]
  values = {
    status_code   = 200
    response_body = "{\"status\":\"success\",\"data\":{\"token\":\"TOKEN-2\"}}"
  }
}

override_data {
  target = module.aws[0].data.aws_ami.publisher
  values = {
    id = "ami-0123456789abcdef0"
  }
}

run "aws_plan_produces_two_instances_with_userdata" {
  command = plan

  assert {
    condition     = length(module.aws[0].aws_instance_ids) == 2
    error_message = "Expected 2 aws_instance resources"
  }

  assert {
    condition     = length(module.aws[0].userdata_b64_by_name["pub-eu-1"]) > 0
    error_message = "userdata for pub-eu-1 should be non-empty"
  }

  assert {
    condition     = strcontains(base64decode(module.aws[0].userdata_b64_by_name["pub-eu-1"]), "TOKEN-1")
    error_message = "userdata for pub-eu-1 should contain TOKEN-1"
  }

  assert {
    condition     = strcontains(base64decode(module.aws[0].userdata_b64_by_name["pub-eu-1"]), "/home/ubuntu/npa_publisher_wizard")
    error_message = "userdata for pub-eu-1 should contain wizard path"
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `terraform init -backend=false && terraform test -filter=tests/aws_plan.tftest.hcl`
Expected: FAIL — `Module not installed` for `./modules/aws`.

- [ ] **Step 3: Create `modules/aws/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.3"
    }
  }
}
```

- [ ] **Step 4: Create `modules/aws/variables.tf`**

```hcl
variable "publisher_names" {
  type = list(string)
}

variable "tenant_url" {
  type = string
}

variable "api_token" {
  type      = string
  sensitive = true
}

variable "wizard_path" {
  type    = string
  default = "/home/ubuntu/npa_publisher_wizard"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "key_name" {
  type    = string
  default = null
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "ami_id" {
  description = "Override the auto-discovered Netskope publisher AMI."
  type        = string
  default     = null
}

variable "associate_public_ip_address" {
  type    = bool
  default = false
}

variable "iam_instance_profile" {
  type    = string
  default = null
}

variable "ebs_optimized" {
  type    = bool
  default = true
}

variable "monitoring" {
  type    = bool
  default = true
}

variable "metadata_options" {
  type = object({
    http_endpoint = optional(string, "enabled")
    http_tokens   = optional(string, "required")
  })
  default = {}
}
```

- [ ] **Step 5: Create `modules/aws/main.tf`**

```hcl
module "registration" {
  source          = "../registration"
  tenant_url      = var.tenant_url
  api_token       = var.api_token
  publisher_names = var.publisher_names
}

module "cloudinit" {
  source     = "../cloudinit"
  publishers = { for n, p in module.registration.publishers : n => p.registration_token }
  wizard_path = var.wizard_path
}

data "aws_ami" "publisher" {
  most_recent = true
  owners      = ["679593333241"]

  filter {
    name   = "name"
    values = ["Netskope Private Access Publisher*"]
  }
}

resource "aws_instance" "publisher" {
  for_each = toset(var.publisher_names)

  ami                         = coalesce(var.ami_id, data.aws_ami.publisher.id)
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip_address
  iam_instance_profile        = var.iam_instance_profile
  ebs_optimized               = var.ebs_optimized
  monitoring                  = var.monitoring
  user_data_base64            = module.cloudinit.userdata_b64[each.key]

  metadata_options {
    http_endpoint = var.metadata_options.http_endpoint
    http_tokens   = var.metadata_options.http_tokens
  }

  tags = merge(var.tags, { Name = each.key })
}
```

- [ ] **Step 6: Create `modules/aws/outputs.tf`**

```hcl
output "publishers" {
  description = "Map of publisher name => { publisher_id, vm_id, private_ip, public_ip, registration_token }."
  sensitive   = true
  value = {
    for n in var.publisher_names : n => {
      publisher_id       = module.registration.publishers[n].publisher_id
      registration_token = module.registration.publishers[n].registration_token
      vm_id              = aws_instance.publisher[n].id
      private_ip         = aws_instance.publisher[n].private_ip
      public_ip          = aws_instance.publisher[n].public_ip
    }
  }
}

# Test-friendly helpers.
output "aws_instance_ids" {
  value = [for n in var.publisher_names : aws_instance.publisher[n].id]
}

output "userdata_b64_by_name" {
  value     = { for n in var.publisher_names : n => aws_instance.publisher[n].user_data_base64 }
  sensitive = true
}
```

- [ ] **Step 7: Wire root `main.tf`**

Append to `main.tf`:

```hcl
module "aws" {
  source = "./modules/aws"
  count  = var.platform == "aws" ? 1 : 0

  publisher_names = local.publisher_names
  tenant_url      = var.netskope_tenant_url
  api_token       = var.netskope_api_token
  wizard_path     = var.wizard_path
  tags            = var.tags

  subnet_id                   = try(var.aws.subnet_id, null)
  security_group_ids          = try(var.aws.security_group_ids, [])
  key_name                    = try(var.aws.key_name, null)
  instance_type               = try(var.aws.instance_type, "t3.medium")
  ami_id                      = try(var.aws.ami_id, null)
  associate_public_ip_address = try(var.aws.associate_public_ip_address, false)
  iam_instance_profile        = try(var.aws.iam_instance_profile, null)
  ebs_optimized               = try(var.aws.ebs_optimized, true)
  monitoring                  = try(var.aws.monitoring, true)
  metadata_options            = try(var.aws.metadata_options, {})
}
```

- [ ] **Step 8: Create root `outputs.tf`** (AWS-only — extended by later platform tasks)

```hcl
locals {
  publishers_by_platform = {
    aws = try(module.aws[0].publishers, {})
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
}

output "registration_tokens" {
  description = "Map of publisher_name => registration_token."
  value       = { for n, p in local.publishers_by_platform[var.platform] : n => p.registration_token }
  sensitive   = true
}
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `terraform init -backend=false -upgrade && terraform test`
Expected: All previously passing tests still pass; `aws_plan_produces_two_instances_with_userdata` passes.

- [ ] **Step 10: Commit**

```bash
terraform fmt -recursive
git add modules/aws tests/aws_plan.tftest.hcl main.tf outputs.tf
git commit -m "feat(aws): add AWS submodule and wire into root"
git push
```

---

## Task 6: AWS example + v0.1.0 release

**Files:**
- Create: `examples/aws-single/README.md`
- Create: `examples/aws-single/main.tf`
- Create: `examples/aws-single/variables.tf`
- Create: `examples/aws-single/terraform.tfvars.example`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Create `examples/aws-single/variables.tf`**

```hcl
variable "netskope_tenant_url" { type = string }
variable "netskope_api_token"  { type = string, sensitive = true }
variable "aws_region"          { type = string, default = "eu-west-1" }
variable "subnet_id"           { type = string }
variable "security_group_id"   { type = string }
variable "key_name"            { type = string }
```

- [ ] **Step 2: Create `examples/aws-single/main.tf`**

```hcl
terraform {
  required_version = ">= 1.7"

  required_providers {
    aws       = { source = "hashicorp/aws", version = "~> 5.0" }
    http      = { source = "hashicorp/http", version = ">= 3.4" }
    cloudinit = { source = "hashicorp/cloudinit", version = ">= 2.3" }
  }
}

provider "aws" {
  region = var.aws_region
}

module "publisher" {
  source      = "../.."
  platform    = "aws"
  name_prefix = "demo-aws"
  replicas    = 1

  netskope_tenant_url = var.netskope_tenant_url
  netskope_api_token  = var.netskope_api_token

  aws = {
    subnet_id          = var.subnet_id
    security_group_ids = [var.security_group_id]
    key_name           = var.key_name
  }
}

output "publishers"          { value = module.publisher.publishers }
output "registration_tokens" { value = module.publisher.registration_tokens, sensitive = true }
```

- [ ] **Step 3: Create `examples/aws-single/terraform.tfvars.example`**

```hcl
netskope_tenant_url = "https://tenant.goskope.com"
netskope_api_token  = "..."
aws_region          = "eu-west-1"
subnet_id           = "subnet-..."
security_group_id   = "sg-..."
key_name            = "my-key"
```

- [ ] **Step 4: Create `examples/aws-single/README.md`**

```markdown
# Example: AWS, single publisher

Provisions one EC2 publisher in AWS using the latest Netskope-published AMI.
Copy `terraform.tfvars.example` to `terraform.tfvars`, fill in values, then:

```bash
terraform init
terraform apply
```

The publisher is registered with your tenant via cloud-init on first boot.
````

- [ ] **Step 5: Validate the example**

```bash
cd examples/aws-single
terraform init -backend=false
terraform validate
cd -
```
Expected: `Success! The configuration is valid.`

- [ ] **Step 6: Update `CHANGELOG.md`**

Replace the `## [Unreleased]` section with:

```markdown
## [Unreleased]

## [0.1.0] - 2026-05-18

### Added
- Initial release.
- AWS submodule (`modules/aws`) provisioning EC2 publishers with cloud-init registration.
- Shared `modules/registration` (Netskope API list/create/token) and `modules/cloudinit` (NoCloud user-data + meta-data).
- Root module routing on `var.platform` (only `aws` supported in this release).
- `terraform test` unit suite with mocked `http` and `aws` providers.
```

- [ ] **Step 7: Commit and tag v0.1.0**

```bash
terraform fmt -recursive
git add examples/aws-single CHANGELOG.md
git commit -m "feat: aws-single example; release v0.1.0"
git tag -a v0.1.0 -m "v0.1.0 — AWS-only release"
git push && git push --tags
```

---

## Task 7: `modules/azure` — Azure Linux VM submodule

**Files:**
- Create: `modules/azure/versions.tf`
- Create: `modules/azure/variables.tf`
- Create: `modules/azure/main.tf`
- Create: `modules/azure/outputs.tf`
- Create: `tests/azure_plan.tftest.hcl`
- Modify: `main.tf` (root)

- [ ] **Step 1: Write the failing test**

Create `tests/azure_plan.tftest.hcl`:

```hcl
variables {
  platform            = "azure"
  name_prefix         = "pub-az"
  replicas            = 1
  netskope_tenant_url = "https://tenant.example.goskope.com"
  netskope_api_token  = "MOCK-API-TOKEN"

  azure = {
    resource_group_name    = "rg-test"
    location               = "westeurope"
    subnet_id              = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/sn"
    admin_ssh_public_key   = "ssh-rsa AAAAB3..."
    image_id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/images/netskope-publisher"
  }
}

mock_provider "azurerm" {}
mock_provider "http" {}

override_data {
  target = module.azure[0].module.registration.data.http.list
  values = {
    status_code   = 200
    response_body = "{\"status\":\"success\",\"data\":{\"publishers\":[]}}"
  }
}
override_data {
  target = module.azure[0].module.registration.data.http.create["pub-az-1"]
  values = {
    status_code   = 200
    response_body = "{\"status\":\"success\",\"data\":{\"publisher_id\":11,\"publisher_name\":\"pub-az-1\"}}"
  }
}
override_data {
  target = module.azure[0].module.registration.data.http.token["pub-az-1"]
  values = {
    status_code   = 200
    response_body = "{\"status\":\"success\",\"data\":{\"token\":\"AZ-TOKEN\"}}"
  }
}

run "azure_plan_emits_vm_with_custom_data" {
  command = plan

  assert {
    condition     = length(module.azure[0].vm_ids) == 1
    error_message = "Expected 1 azurerm_linux_virtual_machine"
  }
  assert {
    condition     = strcontains(base64decode(module.azure[0].custom_data_by_name["pub-az-1"]), "AZ-TOKEN")
    error_message = "custom_data for pub-az-1 should contain AZ-TOKEN"
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `terraform test -filter=tests/azure_plan.tftest.hcl`
Expected: FAIL — `Module not installed` for `./modules/azure`.

- [ ] **Step 3: Create `modules/azure/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.3"
    }
  }
}
```

- [ ] **Step 4: Create `modules/azure/variables.tf`**

```hcl
variable "publisher_names" { type = list(string) }
variable "tenant_url"      { type = string }
variable "api_token"       { type = string, sensitive = true }
variable "wizard_path"     { type = string, default = "/home/ubuntu/npa_publisher_wizard" }
variable "tags"            { type = map(string), default = {} }

variable "resource_group_name" { type = string }
variable "location"            { type = string }
variable "subnet_id"           { type = string }

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "admin_username" {
  type    = string
  default = "ubuntu"
}

variable "admin_ssh_public_key" {
  type = string
}

variable "network_security_group_id" {
  type    = string
  default = null
}

variable "assign_public_ip" {
  type    = bool
  default = false
}

variable "os_disk" {
  type = object({
    type    = optional(string, "Premium_LRS")
    size_gb = optional(number, 64)
  })
  default = {}
}

variable "image_id" {
  description = "Resource ID of an existing image. Mutually exclusive with marketplace."
  type        = string
  default     = null
}

variable "marketplace" {
  description = "Marketplace image reference. Used when image_id is null."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = optional(string, "latest")
  })
  default = null
}

variable "accept_marketplace_terms" {
  type    = bool
  default = false
}
```

- [ ] **Step 5: Create `modules/azure/main.tf`**

```hcl
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

resource "azurerm_marketplace_agreement" "publisher" {
  count     = var.accept_marketplace_terms && var.marketplace != null ? 1 : 0
  publisher = var.marketplace.publisher
  offer     = var.marketplace.offer
  plan      = var.marketplace.sku
}

resource "azurerm_public_ip" "publisher" {
  for_each = var.assign_public_ip ? toset(var.publisher_names) : []

  name                = "${each.key}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "publisher" {
  for_each = toset(var.publisher_names)

  name                = "${each.key}-nic"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.assign_public_ip ? azurerm_public_ip.publisher[each.key].id : null
  }
}

resource "azurerm_network_interface_security_group_association" "publisher" {
  for_each = var.network_security_group_id == null ? toset([]) : toset(var.publisher_names)

  network_interface_id      = azurerm_network_interface.publisher[each.key].id
  network_security_group_id = var.network_security_group_id
}

resource "azurerm_linux_virtual_machine" "publisher" {
  for_each = toset(var.publisher_names)

  name                  = each.key
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.publisher[each.key].id]
  custom_data           = module.cloudinit.userdata_b64[each.key]
  tags                  = merge(var.tags, { Name = each.key })

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk.type
    disk_size_gb         = var.os_disk.size_gb
  }

  source_image_id = var.image_id

  dynamic "plan" {
    for_each = var.image_id == null && var.marketplace != null ? [var.marketplace] : []
    content {
      publisher = plan.value.publisher
      product   = plan.value.offer
      name      = plan.value.sku
    }
  }

  dynamic "source_image_reference" {
    for_each = var.image_id == null && var.marketplace != null ? [var.marketplace] : []
    content {
      publisher = source_image_reference.value.publisher
      offer     = source_image_reference.value.offer
      sku       = source_image_reference.value.sku
      version   = source_image_reference.value.version
    }
  }

  lifecycle {
    precondition {
      condition     = var.image_id != null || var.marketplace != null
      error_message = "Provide either azure.image_id or azure.marketplace."
    }
  }
}
```

- [ ] **Step 6: Create `modules/azure/outputs.tf`**

```hcl
output "publishers" {
  sensitive = true
  value = {
    for n in var.publisher_names : n => {
      publisher_id       = module.registration.publishers[n].publisher_id
      registration_token = module.registration.publishers[n].registration_token
      vm_id              = azurerm_linux_virtual_machine.publisher[n].id
      private_ip         = azurerm_network_interface.publisher[n].private_ip_address
      public_ip          = var.assign_public_ip ? azurerm_public_ip.publisher[n].ip_address : null
    }
  }
}

output "vm_ids" {
  value = [for n in var.publisher_names : azurerm_linux_virtual_machine.publisher[n].id]
}

output "custom_data_by_name" {
  value     = { for n in var.publisher_names : n => azurerm_linux_virtual_machine.publisher[n].custom_data }
  sensitive = true
}
```

- [ ] **Step 7: Wire root `main.tf`**

Append to `main.tf`:

```hcl
module "azure" {
  source = "./modules/azure"
  count  = var.platform == "azure" ? 1 : 0

  publisher_names = local.publisher_names
  tenant_url      = var.netskope_tenant_url
  api_token       = var.netskope_api_token
  wizard_path     = var.wizard_path
  tags            = var.tags

  resource_group_name       = try(var.azure.resource_group_name, null)
  location                  = try(var.azure.location, null)
  subnet_id                 = try(var.azure.subnet_id, null)
  vm_size                   = try(var.azure.vm_size, "Standard_D2s_v5")
  admin_username            = try(var.azure.admin_username, "ubuntu")
  admin_ssh_public_key      = try(var.azure.admin_ssh_public_key, null)
  network_security_group_id = try(var.azure.network_security_group_id, null)
  assign_public_ip          = try(var.azure.assign_public_ip, false)
  os_disk                   = try(var.azure.os_disk, {})
  image_id                  = try(var.azure.image_id, null)
  marketplace               = try(var.azure.marketplace, null)
  accept_marketplace_terms  = try(var.azure.accept_marketplace_terms, false)
}
```

- [ ] **Step 8: Extend root `outputs.tf`**

Replace the `locals { publishers_by_platform = { ... } }` block in `outputs.tf` with:

```hcl
locals {
  publishers_by_platform = {
    aws   = try(module.aws[0].publishers, {})
    azure = try(module.azure[0].publishers, {})
  }
}
```

- [ ] **Step 9: Run tests**

Run: `terraform init -backend=false -upgrade && terraform test`
Expected: all tests pass including `azure_plan_emits_vm_with_custom_data`.

- [ ] **Step 10: Commit**

```bash
terraform fmt -recursive
git add modules/azure tests/azure_plan.tftest.hcl main.tf outputs.tf
git commit -m "feat(azure): add Azure Linux VM submodule"
git push
```

---

## Task 8: Azure HA-pair example + v0.2.0 release

**Files:**
- Create: `examples/azure-ha-pair/README.md`
- Create: `examples/azure-ha-pair/main.tf`
- Create: `examples/azure-ha-pair/variables.tf`
- Create: `examples/azure-ha-pair/terraform.tfvars.example`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Create `examples/azure-ha-pair/variables.tf`**

```hcl
variable "netskope_tenant_url"  { type = string }
variable "netskope_api_token"   { type = string, sensitive = true }
variable "resource_group_name"  { type = string }
variable "location"             { type = string, default = "westeurope" }
variable "subnet_id"            { type = string }
variable "admin_ssh_public_key" { type = string }
variable "azure_image_id"       { type = string }
```

- [ ] **Step 2: Create `examples/azure-ha-pair/main.tf`**

```hcl
terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm   = { source = "hashicorp/azurerm", version = "~> 4.0" }
    http      = { source = "hashicorp/http",    version = ">= 3.4" }
    cloudinit = { source = "hashicorp/cloudinit", version = ">= 2.3" }
  }
}

provider "azurerm" { features {} }

module "publisher" {
  source      = "../.."
  platform    = "azure"
  name_prefix = "demo-az"
  replicas    = 2

  netskope_tenant_url = var.netskope_tenant_url
  netskope_api_token  = var.netskope_api_token

  azure = {
    resource_group_name  = var.resource_group_name
    location             = var.location
    subnet_id            = var.subnet_id
    admin_ssh_public_key = var.admin_ssh_public_key
    image_id             = var.azure_image_id
  }
}

output "publishers" { value = module.publisher.publishers }
```

- [ ] **Step 3: Create `examples/azure-ha-pair/terraform.tfvars.example`**

```hcl
netskope_tenant_url  = "https://tenant.goskope.com"
netskope_api_token   = "..."
resource_group_name  = "rg-npa"
location             = "westeurope"
subnet_id            = "/subscriptions/.../subnets/sn"
admin_ssh_public_key = "ssh-rsa AAAA..."
azure_image_id       = "/subscriptions/.../Microsoft.Compute/images/netskope-publisher"
```

- [ ] **Step 4: Create `examples/azure-ha-pair/README.md`**

```markdown
# Example: Azure, HA pair

Provisions two Linux VM publishers in the same subnet, each registered with
your Netskope tenant. Copy `terraform.tfvars.example` to `terraform.tfvars`,
fill in values, then `terraform init && terraform apply`.
```

- [ ] **Step 5: Validate**

```bash
cd examples/azure-ha-pair && terraform init -backend=false && terraform validate && cd -
```
Expected: `Success!`

- [ ] **Step 6: Update CHANGELOG**

Insert under `## [Unreleased]` (then move to a new `## [0.2.0] - 2026-05-18` section):

```markdown
## [Unreleased]

## [0.2.0] - 2026-05-18

### Added
- Azure submodule (`modules/azure`) provisioning `azurerm_linux_virtual_machine` with `custom_data` cloud-init.
- `examples/azure-ha-pair` showing two-VM deployment.
```

- [ ] **Step 7: Commit and tag**

```bash
terraform fmt -recursive
git add examples/azure-ha-pair CHANGELOG.md
git commit -m "feat: azure-ha-pair example; release v0.2.0"
git tag -a v0.2.0 -m "v0.2.0 — Azure support"
git push && git push --tags
```

---

## Task 9: `modules/gcp` — Compute Engine submodule

**Files:**
- Create: `modules/gcp/versions.tf`
- Create: `modules/gcp/variables.tf`
- Create: `modules/gcp/main.tf`
- Create: `modules/gcp/outputs.tf`
- Create: `tests/gcp_plan.tftest.hcl`
- Modify: `main.tf` (root)

- [ ] **Step 1: Write the failing test**

Create `tests/gcp_plan.tftest.hcl`:

```hcl
variables {
  platform            = "gcp"
  name_prefix         = "pub-gcp"
  replicas            = 1
  netskope_tenant_url = "https://tenant.example.goskope.com"
  netskope_api_token  = "MOCK-API-TOKEN"

  gcp = {
    project    = "demo-project"
    zone       = "europe-west4-a"
    network    = "default"
    subnetwork = "default"
    image      = "projects/demo-project/global/images/netskope-publisher"
  }
}

mock_provider "google" {}
mock_provider "http" {}

override_data {
  target = module.gcp[0].module.registration.data.http.list
  values = {
    status_code   = 200
    response_body = "{\"status\":\"success\",\"data\":{\"publishers\":[]}}"
  }
}
override_data {
  target = module.gcp[0].module.registration.data.http.create["pub-gcp-1"]
  values = {
    status_code   = 200
    response_body = "{\"status\":\"success\",\"data\":{\"publisher_id\":21,\"publisher_name\":\"pub-gcp-1\"}}"
  }
}
override_data {
  target = module.gcp[0].module.registration.data.http.token["pub-gcp-1"]
  values = {
    status_code   = 200
    response_body = "{\"status\":\"success\",\"data\":{\"token\":\"GCP-TOKEN\"}}"
  }
}

run "gcp_plan_emits_instance_with_user_data_metadata" {
  command = plan

  assert {
    condition     = length(module.gcp[0].instance_ids) == 1
    error_message = "Expected 1 google_compute_instance"
  }
  assert {
    condition     = strcontains(module.gcp[0].user_data_by_name["pub-gcp-1"], "GCP-TOKEN")
    error_message = "user-data for pub-gcp-1 should contain GCP-TOKEN"
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `terraform test -filter=tests/gcp_plan.tftest.hcl`
Expected: FAIL — `Module not installed`.

- [ ] **Step 3: Create `modules/gcp/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.7"

  required_providers {
    google    = { source = "hashicorp/google", version = "~> 6.0" }
    http      = { source = "hashicorp/http",   version = ">= 3.4" }
    cloudinit = { source = "hashicorp/cloudinit", version = ">= 2.3" }
  }
}
```

- [ ] **Step 4: Create `modules/gcp/variables.tf`**

```hcl
variable "publisher_names" { type = list(string) }
variable "tenant_url"      { type = string }
variable "api_token"       { type = string, sensitive = true }
variable "wizard_path"     { type = string, default = "/home/ubuntu/npa_publisher_wizard" }
variable "tags"            { type = map(string), default = {} }

variable "project"      { type = string }
variable "zone"         { type = string }
variable "network"      { type = string }
variable "subnetwork"   { type = string }
variable "machine_type" { type = string, default = "e2-medium" }

variable "image" {
  description = "Compute image self-link (e.g. projects/.../global/images/...)."
  type        = string
}

variable "assign_public_ip" { type = bool, default = false }
variable "network_tags"     { type = list(string), default = [] }

variable "service_account" {
  type = object({
    email  = string
    scopes = optional(list(string), ["https://www.googleapis.com/auth/cloud-platform"])
  })
  default = null
}
```

- [ ] **Step 5: Create `modules/gcp/main.tf`**

```hcl
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
```

- [ ] **Step 6: Create `modules/gcp/outputs.tf`**

```hcl
output "publishers" {
  sensitive = true
  value = {
    for n in var.publisher_names : n => {
      publisher_id       = module.registration.publishers[n].publisher_id
      registration_token = module.registration.publishers[n].registration_token
      vm_id              = google_compute_instance.publisher[n].instance_id
      private_ip         = google_compute_instance.publisher[n].network_interface[0].network_ip
      public_ip          = try(google_compute_instance.publisher[n].network_interface[0].access_config[0].nat_ip, null)
    }
  }
}

output "instance_ids" {
  value = [for n in var.publisher_names : google_compute_instance.publisher[n].instance_id]
}

output "user_data_by_name" {
  value     = { for n in var.publisher_names : n => google_compute_instance.publisher[n].metadata["user-data"] }
  sensitive = true
}
```

- [ ] **Step 7: Wire root `main.tf`**

Append:

```hcl
module "gcp" {
  source = "./modules/gcp"
  count  = var.platform == "gcp" ? 1 : 0

  publisher_names = local.publisher_names
  tenant_url      = var.netskope_tenant_url
  api_token       = var.netskope_api_token
  wizard_path     = var.wizard_path
  tags            = var.tags

  project          = try(var.gcp.project, null)
  zone             = try(var.gcp.zone, null)
  network          = try(var.gcp.network, "default")
  subnetwork       = try(var.gcp.subnetwork, "default")
  machine_type     = try(var.gcp.machine_type, "e2-medium")
  image            = try(var.gcp.image, null)
  assign_public_ip = try(var.gcp.assign_public_ip, false)
  network_tags     = try(var.gcp.network_tags, [])
  service_account  = try(var.gcp.service_account, null)
}
```

- [ ] **Step 8: Extend root `outputs.tf`**

Replace the `locals { publishers_by_platform = { ... } }` block in `outputs.tf` with:

```hcl
locals {
  publishers_by_platform = {
    aws   = try(module.aws[0].publishers, {})
    azure = try(module.azure[0].publishers, {})
    gcp   = try(module.gcp[0].publishers, {})
  }
}
```

- [ ] **Step 9: Run tests**

Run: `terraform init -backend=false -upgrade && terraform test`
Expected: all tests pass.

- [ ] **Step 10: Commit**

```bash
terraform fmt -recursive
git add modules/gcp tests/gcp_plan.tftest.hcl main.tf outputs.tf
git commit -m "feat(gcp): add Compute Engine submodule"
git push
```

---

## Task 10: GCP example + v0.3.0 release

**Files:**
- Create: `examples/gcp-single/README.md`
- Create: `examples/gcp-single/main.tf`
- Create: `examples/gcp-single/variables.tf`
- Create: `examples/gcp-single/terraform.tfvars.example`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Create `examples/gcp-single/variables.tf`**

```hcl
variable "netskope_tenant_url" { type = string }
variable "netskope_api_token"  { type = string, sensitive = true }
variable "project"             { type = string }
variable "zone"                { type = string, default = "europe-west4-a" }
variable "network"             { type = string, default = "default" }
variable "subnetwork"          { type = string, default = "default" }
variable "image"               { type = string }
```

- [ ] **Step 2: Create `examples/gcp-single/main.tf`**

```hcl
terraform {
  required_version = ">= 1.7"
  required_providers {
    google    = { source = "hashicorp/google", version = "~> 6.0" }
    http      = { source = "hashicorp/http", version = ">= 3.4" }
    cloudinit = { source = "hashicorp/cloudinit", version = ">= 2.3" }
  }
}

provider "google" {
  project = var.project
  zone    = var.zone
}

module "publisher" {
  source      = "../.."
  platform    = "gcp"
  name_prefix = "demo-gcp"
  replicas    = 1

  netskope_tenant_url = var.netskope_tenant_url
  netskope_api_token  = var.netskope_api_token

  gcp = {
    project    = var.project
    zone       = var.zone
    network    = var.network
    subnetwork = var.subnetwork
    image      = var.image
  }
}

output "publishers" { value = module.publisher.publishers }
```

- [ ] **Step 3: Create `examples/gcp-single/terraform.tfvars.example`**

```hcl
netskope_tenant_url = "https://tenant.goskope.com"
netskope_api_token  = "..."
project             = "my-gcp-project"
zone                = "europe-west4-a"
network             = "default"
subnetwork          = "default"
image               = "projects/my-gcp-project/global/images/netskope-publisher"
```

- [ ] **Step 4: Create `examples/gcp-single/README.md`**

```markdown
# Example: GCP, single publisher

Provisions one `google_compute_instance` publisher. Configure
`terraform.tfvars` and run `terraform init && terraform apply`.
```

- [ ] **Step 5: Validate**

```bash
cd examples/gcp-single && terraform init -backend=false && terraform validate && cd -
```

- [ ] **Step 6: Update CHANGELOG**

Add to top:

```markdown
## [0.3.0] - 2026-05-18

### Added
- GCP submodule (`modules/gcp`) provisioning Compute Engine publishers via `metadata["user-data"]`.
- `examples/gcp-single`.
```

- [ ] **Step 7: Commit and tag**

```bash
terraform fmt -recursive
git add examples/gcp-single CHANGELOG.md
git commit -m "feat: gcp-single example; release v0.3.0"
git tag -a v0.3.0 -m "v0.3.0 — GCP support"
git push && git push --tags
```

---

## Task 11: `modules/vsphere` — vSphere submodule via guestinfo

**Files:**
- Create: `modules/vsphere/versions.tf`
- Create: `modules/vsphere/variables.tf`
- Create: `modules/vsphere/main.tf`
- Create: `modules/vsphere/outputs.tf`
- Create: `tests/vsphere_plan.tftest.hcl`
- Modify: `main.tf` (root)

- [ ] **Step 1: Write the failing test**

Create `tests/vsphere_plan.tftest.hcl`:

```hcl
variables {
  platform            = "vsphere"
  name_prefix         = "pub-vc"
  replicas            = 1
  netskope_tenant_url = "https://tenant.example.goskope.com"
  netskope_api_token  = "MOCK-API-TOKEN"

  vsphere = {
    datacenter    = "dc1"
    cluster       = "cluster1"
    datastore     = "ds1"
    network_name  = "vm-net"
    template_name = "netskope-publisher-template"
    folder        = null
  }
}

mock_provider "vsphere" {}
mock_provider "http" {}

override_data {
  target = module.vsphere[0].module.registration.data.http.list
  values = {
    status_code   = 200
    response_body = "{\"status\":\"success\",\"data\":{\"publishers\":[]}}"
  }
}
override_data {
  target = module.vsphere[0].module.registration.data.http.create["pub-vc-1"]
  values = {
    status_code   = 200
    response_body = "{\"status\":\"success\",\"data\":{\"publisher_id\":31,\"publisher_name\":\"pub-vc-1\"}}"
  }
}
override_data {
  target = module.vsphere[0].module.registration.data.http.token["pub-vc-1"]
  values = {
    status_code   = 200
    response_body = "{\"status\":\"success\",\"data\":{\"token\":\"VC-TOKEN\"}}"
  }
}

run "vsphere_plan_emits_vm_with_guestinfo" {
  command = plan

  assert {
    condition     = length(module.vsphere[0].vm_uuids) == 1
    error_message = "Expected 1 vsphere_virtual_machine"
  }
  assert {
    condition     = strcontains(base64decode(module.vsphere[0].guestinfo_by_name["pub-vc-1"]), "VC-TOKEN")
    error_message = "guestinfo.userdata for pub-vc-1 should contain VC-TOKEN"
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `terraform test -filter=tests/vsphere_plan.tftest.hcl`
Expected: FAIL — `Module not installed`.

- [ ] **Step 3: Create `modules/vsphere/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.7"

  required_providers {
    vsphere   = { source = "vmware/vsphere", version = "~> 2.10" }
    http      = { source = "hashicorp/http", version = ">= 3.4" }
    cloudinit = { source = "hashicorp/cloudinit", version = ">= 2.3" }
  }
}
```

- [ ] **Step 4: Create `modules/vsphere/variables.tf`**

```hcl
variable "publisher_names" { type = list(string) }
variable "tenant_url"      { type = string }
variable "api_token"       { type = string, sensitive = true }
variable "wizard_path"     { type = string, default = "/home/ubuntu/npa_publisher_wizard" }
variable "tags"            { type = map(string), default = {} }

variable "datacenter"   { type = string }
variable "cluster"      { type = string, default = null }
variable "host"         { type = string, default = null }
variable "datastore"    { type = string }
variable "network_name" { type = string }
variable "template_name" { type = string }
variable "folder"       { type = string, default = null }
variable "num_cpus"     { type = number, default = 2 }
variable "memory"       { type = number, default = 4096 }
```

- [ ] **Step 5: Create `modules/vsphere/main.tf`**

```hcl
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
  for_each = toset(var.publisher_names)

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

  custom_attributes = var.tags

  lifecycle {
    precondition {
      condition     = var.cluster != null || var.host != null
      error_message = "Provide either vsphere.cluster or vsphere.host."
    }
    ignore_changes = [ovf_deploy]
  }
}
```

- [ ] **Step 6: Create `modules/vsphere/outputs.tf`**

```hcl
output "publishers" {
  sensitive = true
  value = {
    for n in var.publisher_names : n => {
      publisher_id       = module.registration.publishers[n].publisher_id
      registration_token = module.registration.publishers[n].registration_token
      vm_id              = vsphere_virtual_machine.publisher[n].id
      private_ip         = vsphere_virtual_machine.publisher[n].default_ip_address
      public_ip          = null
    }
  }
}

output "vm_uuids" {
  value = [for n in var.publisher_names : vsphere_virtual_machine.publisher[n].uuid]
}

output "guestinfo_by_name" {
  value     = { for n in var.publisher_names : n => vsphere_virtual_machine.publisher[n].extra_config["guestinfo.userdata"] }
  sensitive = true
}
```

- [ ] **Step 7: Wire root `main.tf`**

Append:

```hcl
module "vsphere" {
  source = "./modules/vsphere"
  count  = var.platform == "vsphere" ? 1 : 0

  publisher_names = local.publisher_names
  tenant_url      = var.netskope_tenant_url
  api_token       = var.netskope_api_token
  wizard_path     = var.wizard_path
  tags            = var.tags

  datacenter    = try(var.vsphere.datacenter, null)
  cluster       = try(var.vsphere.cluster, null)
  host          = try(var.vsphere.host, null)
  datastore     = try(var.vsphere.datastore, null)
  network_name  = try(var.vsphere.network_name, null)
  template_name = try(var.vsphere.template_name, null)
  folder        = try(var.vsphere.folder, null)
  num_cpus      = try(var.vsphere.num_cpus, 2)
  memory        = try(var.vsphere.memory, 4096)
}
```

- [ ] **Step 8: Extend root `outputs.tf`**

Replace the `locals { publishers_by_platform = { ... } }` block in `outputs.tf` with:

```hcl
locals {
  publishers_by_platform = {
    aws     = try(module.aws[0].publishers, {})
    azure   = try(module.azure[0].publishers, {})
    gcp     = try(module.gcp[0].publishers, {})
    vsphere = try(module.vsphere[0].publishers, {})
  }
}
```

- [ ] **Step 9: Run tests**

Run: `terraform init -backend=false -upgrade && terraform test`
Expected: all tests pass.

- [ ] **Step 10: Commit**

```bash
terraform fmt -recursive
git add modules/vsphere tests/vsphere_plan.tftest.hcl main.tf outputs.tf
git commit -m "feat(vsphere): add vSphere submodule with guestinfo cloud-init"
git push
```

---

## Task 12: vSphere example + v0.4.0 release

**Files:**
- Create: `examples/vsphere-single/README.md`
- Create: `examples/vsphere-single/main.tf`
- Create: `examples/vsphere-single/variables.tf`
- Create: `examples/vsphere-single/terraform.tfvars.example`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Create `examples/vsphere-single/variables.tf`**

```hcl
variable "netskope_tenant_url" { type = string }
variable "netskope_api_token"  { type = string, sensitive = true }
variable "vsphere_user"        { type = string }
variable "vsphere_password"    { type = string, sensitive = true }
variable "vsphere_server"      { type = string }
variable "datacenter"          { type = string }
variable "cluster"             { type = string }
variable "datastore"           { type = string }
variable "network_name"        { type = string }
variable "template_name"       { type = string }
```

- [ ] **Step 2: Create `examples/vsphere-single/main.tf`**

```hcl
terraform {
  required_version = ">= 1.7"
  required_providers {
    vsphere   = { source = "vmware/vsphere", version = "~> 2.10" }
    http      = { source = "hashicorp/http", version = ">= 3.4" }
    cloudinit = { source = "hashicorp/cloudinit", version = ">= 2.3" }
  }
}

provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server
  # Self-signed certs are common in vSphere labs; flip this for production.
  allow_unverified_ssl = true
}

module "publisher" {
  source      = "../.."
  platform    = "vsphere"
  name_prefix = "demo-vc"
  replicas    = 1

  netskope_tenant_url = var.netskope_tenant_url
  netskope_api_token  = var.netskope_api_token

  vsphere = {
    datacenter    = var.datacenter
    cluster       = var.cluster
    datastore     = var.datastore
    network_name  = var.network_name
    template_name = var.template_name
  }
}

output "publishers" { value = module.publisher.publishers }
```

- [ ] **Step 3: Create `examples/vsphere-single/terraform.tfvars.example`**

```hcl
netskope_tenant_url = "https://tenant.goskope.com"
netskope_api_token  = "..."
vsphere_user        = "administrator@vsphere.local"
vsphere_password    = "..."
vsphere_server      = "vcenter.lab.local"
datacenter          = "dc1"
cluster             = "cluster1"
datastore           = "ds1"
network_name        = "vm-net"
template_name       = "netskope-publisher-template"
```

- [ ] **Step 4: Create `examples/vsphere-single/README.md`**

```markdown
# Example: vSphere, single publisher

Clones a Netskope publisher template VM and bootstraps it via cloud-init's
VMware datasource (`guestinfo.userdata`). The template must contain
cloud-init (the official Netskope OVA does).
```

- [ ] **Step 5: Validate**

```bash
cd examples/vsphere-single && terraform init -backend=false && terraform validate && cd -
```

- [ ] **Step 6: Update CHANGELOG**

Add to top:

```markdown
## [0.4.0] - 2026-05-18

### Added
- vSphere submodule (`modules/vsphere`) cloning Netskope OVA template, cloud-init via `guestinfo`.
- `examples/vsphere-single`.
```

- [ ] **Step 7: Commit and tag**

```bash
terraform fmt -recursive
git add examples/vsphere-single CHANGELOG.md
git commit -m "feat: vsphere-single example; release v0.4.0"
git tag -a v0.4.0 -m "v0.4.0 — vSphere support"
git push && git push --tags
```

---

## Task 13: README, v1.0.0 release

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Replace `README.md`**

Overwrite `README.md` with:

````markdown
# terraform-netskope-publisher

Provision Netskope Private Access Publishers on **AWS**, **Azure**, **GCP**, or
**vSphere** from a single Terraform module. Publishers are created via the
Netskope NPA API and registered on first boot through cloud-init — no
out-of-band wizard runs.

## Quick start

```hcl
module "publisher" {
  source   = "github.com/johnneerdael/terraform-netskope-publisher?ref=v1.0.0"
  platform = "aws"

  name_prefix = "pub-eu"
  replicas    = 2

  netskope_tenant_url = "https://tenant.goskope.com"
  netskope_api_token  = var.netskope_api_token

  aws = {
    subnet_id          = "subnet-…"
    security_group_ids = ["sg-…"]
    key_name           = "my-key"
  }
}
```

Switch platform by changing `platform = "azure"` / `"gcp"` / `"vsphere"` and
populating the matching input object.

## Inputs (common)

| Name | Type | Default | Description |
|---|---|---|---|
| `platform` | string | — | `aws` \| `azure` \| `gcp` \| `vsphere` |
| `name_prefix` | string | `"npa-publisher"` | Used when `names` is null |
| `names` | list(string) | `null` | Explicit publisher names |
| `replicas` | number | `1` | Number of publishers when `names` is null |
| `tags` | map(string) | `{}` | Tags / labels per platform |
| `netskope_tenant_url` | string | — | e.g. `https://tenant.goskope.com` |
| `netskope_api_token` | string (sensitive) | — | NPA API token |
| `wizard_path` | string | `/home/ubuntu/npa_publisher_wizard` | On-VM wizard path |

Platform-specific inputs live in each submodule's `variables.tf`. See the
examples in `examples/`.

## Outputs

```hcl
output "publishers" {
  # Map: name => { publisher_id, vm_id, private_ip, public_ip, platform }
}

output "registration_tokens" {
  # Map: name => token (sensitive)
}
```

## Registration flow

1. `data "http" "list"` → `GET /api/v2/infrastructure/publishers`
2. For each name missing in the response → `POST /publishers`
3. For every name → `POST /publishers/{id}/registration_token`
4. Cloud-init runcmd on the VM: `/home/ubuntu/npa_publisher_wizard -token <token>`

## Requirements

- Terraform >= 1.7
- `hashicorp/http >= 3.4` (POST support)
- `hashicorp/cloudinit >= 2.3`
- Per-platform: `aws ~> 5.0`, `azurerm ~> 4.0`, `google ~> 6.0`, `vsphere ~> 2.10`

## Testing

```bash
terraform init -backend=false
terraform test
```

All tests use mocked providers and require no cloud credentials.

## License

Apache-2.0. See [LICENSE](LICENSE).
````

- [ ] **Step 2: Update CHANGELOG**

Add at top:

```markdown
## [1.0.0] - 2026-05-18

### Changed
- First blessed release with AWS, Azure, GCP, and vSphere all green.
- README rewritten to cover full multi-platform surface.
```

- [ ] **Step 3: Final validation**

```bash
terraform fmt -recursive -check
terraform init -backend=false -upgrade
terraform validate
terraform test
```
Expected: all green.

- [ ] **Step 4: Commit and tag**

```bash
git add README.md CHANGELOG.md
git commit -m "docs: v1.0.0 README; release v1.0.0"
git tag -a v1.0.0 -m "v1.0.0 — AWS, Azure, GCP, vSphere"
git push && git push --tags
```

---

## Task 14: Deprecate `terraform-netskope-publisher-aws`

**Files:**
- Modify: `/Users/jneerdael/Scripts/terraform-netskope-publisher-aws/README.md`

- [ ] **Step 1: Replace the old README**

Open `/Users/jneerdael/Scripts/terraform-netskope-publisher-aws/README.md` and replace its contents with:

````markdown
# terraform-netskope-publisher-aws (DEPRECATED)

> **This module is deprecated.** Use
> [`terraform-netskope-publisher`](https://github.com/johnneerdael/terraform-netskope-publisher)
> with `platform = "aws"` instead. The replacement module supports AWS, Azure,
> GCP, and vSphere from a single interface and registers publishers via the
> Netskope NPA API (no `netskope/netskope` provider dependency).

## Migration

```hcl
module "publisher" {
  source   = "github.com/johnneerdael/terraform-netskope-publisher?ref=v1.0.0"
  platform = "aws"

  name_prefix = "my-publisher"
  replicas    = 1

  netskope_tenant_url = "https://tenant.goskope.com"
  netskope_api_token  = var.netskope_api_token

  aws = {
    subnet_id          = var.subnet_id
    security_group_ids = [var.security_group_id]
    key_name           = var.key_name
    instance_type      = "t3.medium"
  }
}
```

The legacy `netskope_publishers` resource and `use_ssm` flag have been replaced
by cloud-init-based registration. No additional provider configuration is
needed for the Netskope API beyond `netskope_tenant_url` and
`netskope_api_token`.
````

- [ ] **Step 2: Commit and push in the old repo**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher-aws
git add README.md
git commit -m "docs: deprecate in favor of terraform-netskope-publisher"
git push
cd -
```

---

## Self-review notes

- **Spec coverage:** Every spec section maps to a task —
  §3 layout → Task 1; §4 registration → Task 3; §5 cloudinit → Task 2;
  §6.1 AWS → Task 5+6; §6.2 Azure → Task 7+8; §6.3 GCP → Task 9+10;
  §6.4 vSphere → Task 11+12; §7 inputs → Task 4; §8 outputs → Task 4 (extended in each platform task);
  §9 error handling → preconditions in Tasks 3/7/11; §10 testing → tests created in every task;
  §11 versioning/release → Tasks 6/8/10/12/13; §12 rollout → tasks in stated order; deprecation → Task 14.
- **Things deliberately deferred:** `delete_publisher_on_destroy` and
  `force_token_rotation` are declared in the spec but not implemented in v1.0.0.
  They get their own tasks in a follow-up plan once the core module is in
  users' hands (avoids overloading this plan).
- **Things not in tests:** Real Marketplace agreement creation on Azure
  (`accept_marketplace_terms`) is implementation only — exercising it requires
  a real Azure subscription, so it's covered by the manual integration tier in
  the README, not the unit suite.
