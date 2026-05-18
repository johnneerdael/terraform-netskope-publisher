# Kubernetes Submodule (`modules/kubernetes`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `modules/kubernetes` submodule that installs the existing `kubernetes-netskope-publisher` Helm chart on any Kubernetes cluster (EKS/AKS/GKE/OpenShift/vanilla), with the same `name_prefix`/`replicas`/`names` ergonomics as the other v2 submodules. Two enrollment modes: `token` (Terraform owns publisher records via our provider) and `api` (chart self-registers).

**Architecture:** New submodule pulls in `helm`, `kubernetes`, and (transitively) `http`. In `token` mode it calls `modules/registration` to mint per-replica tokens and feeds them to the chart via Helm `values`; in `api` mode it just hands the chart the tenant URL + API token as a Kubernetes Secret. The chart itself is published as an OCI artifact at `ghcr.io/johnneerdael/charts/kubernetes-netskope-publisher` via a new GH Actions workflow in the chart repo.

**Tech Stack:** No new module dependencies. `hashicorp/helm ~> 2.13`, `hashicorp/kubernetes ~> 2.30`. Helm chart unchanged; chart repo gains an OCI-publish workflow.

**Spec:** `docs/superpowers/specs/2026-05-18-kubernetes-submodule-design.md`

**Working directories:**
- Chart repo: `/Users/jneerdael/Scripts/kubernetes-netskope-publisher` (currently at `v1.3.1`)
- Module repo: `/Users/jneerdael/Scripts/terraform-netskope-publisher` (currently at `v2.1.1`)

Direct-to-`main` per established pattern in both repos.

---

## Task 1: Chart repo — OCI publish workflow

**Files:**
- Create: `~/Scripts/kubernetes-netskope-publisher/.github/workflows/release-chart.yml`

- [ ] **Step 1: Create the workflow**

```yaml
name: Release chart

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: read
  packages: write

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Helm
        uses: azure/setup-helm@v4
        with:
          version: latest

      - name: Lint chart
        run: helm lint .

      - name: Compute version
        id: ver
        run: echo "v=${GITHUB_REF_NAME#v}" >> "$GITHUB_OUTPUT"

      - name: Package chart
        run: helm package . --version "${{ steps.ver.outputs.v }}" --app-version "${{ steps.ver.outputs.v }}"

      - name: Log in to GHCR
        run: echo "${{ secrets.GITHUB_TOKEN }}" | helm registry login ghcr.io -u "${{ github.actor }}" --password-stdin

      - name: Push to OCI registry
        run: helm push kubernetes-netskope-publisher-${{ steps.ver.outputs.v }}.tgz oci://ghcr.io/johnneerdael/charts
```

- [ ] **Step 2: Commit and push**

```bash
cd /Users/jneerdael/Scripts/kubernetes-netskope-publisher
git add .github/workflows/release-chart.yml
git commit -m "ci: add OCI chart publish workflow (ghcr.io)"
git push
```

- [ ] **Step 3: Verify the workflow appears in the Actions tab**

Run: `gh workflow list --repo johnneerdael/kubernetes-netskope-publisher`
Expected: `Release chart` listed. No run yet (no tag pushed).

---

## Task 2: Chart repo — tag v1.4.0

**Files:** none modified; tag only.

- [ ] **Step 1: Tag and push**

```bash
cd /Users/jneerdael/Scripts/kubernetes-netskope-publisher
git tag -a v1.4.0 -m "v1.4.0 — add OCI publishing workflow (chart unchanged)"
git push --tags
```

- [ ] **Step 2: Wait for workflow completion**

```bash
gh run watch --repo johnneerdael/kubernetes-netskope-publisher --exit-status
```

Expected: green ✓ on `Release chart` for tag `v1.4.0`.

If `helm lint` fails: fix the chart issue, delete the tag locally and remotely (`git tag -d v1.4.0 && git push --delete origin v1.4.0`), commit the fix, re-tag, push again.

If `helm push` fails with `403 unauthorized`: confirm the workflow's `packages: write` permission is set (already in the YAML in Task 1) and that the `johnneerdael` GitHub account hasn't restricted `GITHUB_TOKEN` to read-only at the org/account level.

---

## Task 3: One-time GHCR visibility (manual, browser)

**Files:** none.

- [ ] **Step 1: Set the package public**

In a browser:
1. Open https://github.com/users/johnneerdael/packages/container/kubernetes-netskope-publisher
2. Click **Package settings** (right-hand side)
3. Scroll to **Danger Zone** → **Change visibility** → pick **Public** → confirm

This is one-time. Future pushes inherit the package's existing visibility.

- [ ] **Step 2: Smoke-test the OCI pull**

```bash
helm show chart oci://ghcr.io/johnneerdael/charts/kubernetes-netskope-publisher --version 1.4.0 | head -10
```

Expected: prints `apiVersion: v2`, `name: kubernetes-netskope-publisher`, `version: 1.4.0`, etc. If it errors with `pull access denied`, the visibility flip in Step 1 didn't take effect — re-check.

---

## Task 4: Module — `modules/kubernetes` scaffolding

**Files:**
- Create: `modules/kubernetes/versions.tf`
- Create: `modules/kubernetes/variables.tf`
- Create: `modules/kubernetes/locals.tf`

- [ ] **Step 1: Create `modules/kubernetes/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.7"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
  }
}
```

- [ ] **Step 2: Create `modules/kubernetes/variables.tf`**

```hcl
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
  description = "Number of publishers. In token mode this is one Helm release per name. In api mode this is one Helm release whose pod replicas register themselves."
  type        = number
  default     = 1

  validation {
    condition     = var.replicas >= 1
    error_message = "replicas must be >= 1."
  }
}

variable "tenant_url" {
  description = "Netskope tenant URL, e.g. https://tenant.goskope.com."
  type        = string

  validation {
    condition     = can(regex("^https://", var.tenant_url))
    error_message = "tenant_url must start with https://."
  }
}

variable "api_token" {
  description = "Netskope NPA API token. Used by modules/registration (token mode) or written to the chart's API secret (api mode)."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Map of labels applied to all chart resources via commonLabels."
  type        = map(string)
  default     = {}
}

variable "namespace" {
  description = "Namespace to install the chart into. Created if it does not exist."
  type        = string
  default     = "netskope"
}

variable "enrollment_mode" {
  description = "token: Terraform owns the publisher record via our provider and feeds the chart a registration token. api: chart self-registers via the Netskope API on pod start."
  type        = string
  default     = "token"

  validation {
    condition     = contains(["token", "api"], var.enrollment_mode)
    error_message = "enrollment_mode must be \"token\" or \"api\"."
  }
}

variable "chart_version" {
  description = "Helm chart version constraint."
  type        = string
  default     = "~> 1.4"
}

variable "chart_repository" {
  description = "Helm chart repository (OCI URL or HTTPS repo URL)."
  type        = string
  default     = "oci://ghcr.io/johnneerdael/charts"
}

variable "chart_values" {
  description = "Free-form object merged into the Helm values last. Escape hatch for anything not surfaced as a typed input."
  type        = any
  default     = {}
}

variable "workload_type" {
  description = "daemonset or statefulset. Pass-through to chart values.workload.type. statefulset is required for HPA."
  type        = string
  default     = "daemonset"

  validation {
    condition     = contains(["daemonset", "statefulset"], var.workload_type)
    error_message = "workload_type must be \"daemonset\" or \"statefulset\"."
  }
}

variable "hpa_enabled" {
  description = "Enable HorizontalPodAutoscaler. Only meaningful with workload_type = \"statefulset\"."
  type        = bool
  default     = false
}

variable "hpa_min_replicas" {
  type    = number
  default = 2
}

variable "hpa_max_replicas" {
  type    = number
  default = 6
}

variable "image_repository" {
  description = "Override the publisher container image repository (e.g. a private mirror). null = use chart default."
  type        = string
  default     = null
}

variable "image_tag" {
  description = "Override the publisher container image tag. null = use chart default."
  type        = string
  default     = null
}
```

- [ ] **Step 3: Create `modules/kubernetes/locals.tf`**

```hcl
locals {
  publisher_names = var.names != null ? var.names : [
    for i in range(var.replicas) :
    format("%s-%d", var.name_prefix, i + 1)
  ]
}
```

- [ ] **Step 4: Format check**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher
terraform fmt -recursive
```

- [ ] **Step 5: Commit**

```bash
git add modules/kubernetes
git commit -m "feat(kubernetes): scaffold versions, variables, locals"
git push
```

---

## Task 5: Module — `modules/kubernetes/main.tf` (registration + helm_release)

**Files:**
- Create: `modules/kubernetes/main.tf`

- [ ] **Step 1: Create `main.tf`**

```hcl
# Token-mode only: create per-replica publisher records + tokens via the
# shared registration submodule. In api-mode this whole block evaluates to
# an empty map (count=0 on its for_each inputs handled in helm_release values).
module "registration" {
  count = var.enrollment_mode == "token" ? 1 : 0

  source          = "../registration"
  tenant_url      = var.tenant_url
  api_token       = var.api_token
  publisher_names = local.publisher_names
}

# Namespace creation: idempotent (kubernetes provider tolerates re-creating
# an existing namespace as a managed resource only if we explicitly own it).
resource "kubernetes_namespace_v1" "ns" {
  metadata {
    name = var.namespace
  }
  lifecycle {
    # If the user created the namespace out-of-band, don't fight them.
    ignore_changes = [metadata]
  }
}

# Shared Secret for api-mode: chart reads NETSKOPE_API_TOKEN from this Secret.
# Only created when enrollment_mode = "api".
resource "kubernetes_secret_v1" "api_token" {
  count = var.enrollment_mode == "api" ? 1 : 0

  metadata {
    name      = "npa-api-token"
    namespace = kubernetes_namespace_v1.ns.metadata[0].name
  }
  data = {
    "api-token" = var.api_token
  }
  type = "Opaque"
}

# Token-mode: one Secret per publisher holding its registration token.
# Chart reads via registrationToken.existingSecret in values.
resource "kubernetes_secret_v1" "registration_token" {
  for_each = var.enrollment_mode == "token" ? toset(local.publisher_names) : toset([])

  metadata {
    name      = "${each.key}-registration-token"
    namespace = kubernetes_namespace_v1.ns.metadata[0].name
  }
  data = {
    token = module.registration[0].publishers[each.key].registration_token
  }
  type = "Opaque"
}

locals {
  # Common chart-values block (merged with per-release overrides below).
  common_values = {
    workload = {
      type = var.workload_type
    }
    hpa = {
      enabled        = var.hpa_enabled && var.workload_type == "statefulset"
      minReplicas    = var.hpa_min_replicas
      maxReplicas    = var.hpa_max_replicas
    }
    commonLabels = var.tags
    image = merge(
      var.image_repository == null ? {} : { repository = var.image_repository },
      var.image_tag == null ? {} : { tag = var.image_tag },
    )
  }

  api_values = {
    enrollment = {
      mode = "api"
      api = {
        baseUrl         = var.tenant_url
        existingSecret  = "npa-api-token"
        tokenKey        = "api-token"
        cleanupOnDelete = false
      }
    }
  }

  token_values_by_name = var.enrollment_mode != "token" ? {} : {
    for name in local.publisher_names : name => {
      enrollment = {
        mode       = "token"
        commonName = name
      }
      registrationToken = {
        existingSecret    = "${name}-registration-token"
        existingSecretKey = "token"
      }
    }
  }

  # Helm release set: one per name in token mode, one shared release in api mode.
  release_names = var.enrollment_mode == "token" ? toset(local.publisher_names) : toset(["npa-publisher"])
}

resource "helm_release" "publisher" {
  for_each = local.release_names

  name             = each.key
  namespace        = kubernetes_namespace_v1.ns.metadata[0].name
  repository       = var.chart_repository
  chart            = "kubernetes-netskope-publisher"
  version          = var.chart_version
  create_namespace = false
  atomic           = true
  wait             = true
  timeout          = 300

  # Merge order: common → mode-specific → caller's chart_values (last wins).
  values = [
    yamlencode(merge(
      local.common_values,
      var.enrollment_mode == "api" ? local.api_values : local.token_values_by_name[each.key],
      var.chart_values,
    )),
  ]

  depends_on = [
    kubernetes_secret_v1.registration_token,
    kubernetes_secret_v1.api_token,
  ]
}
```

- [ ] **Step 2: Validate from inside the submodule**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher
terraform fmt -recursive
( cd modules/kubernetes && rm -rf .terraform .terraform.lock.hcl && terraform init -backend=false 2>&1 | tail -3 && terraform validate 2>&1 | tail -5 )
```

Expected: `Success! The configuration is valid.`

If validate complains about `kubernetes_namespace_v1` not existing: the kubernetes provider 2.30 uses `kubernetes_namespace` (without `_v1`). Try that. The provider documentation has both names depending on version; we can flip if needed.

- [ ] **Step 3: Commit**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher
git add modules/kubernetes/main.tf
git commit -m "feat(kubernetes): namespace + per-mode Secrets + helm_release(s)"
git push
```

---

## Task 6: Module — `modules/kubernetes/outputs.tf`

**Files:**
- Create: `modules/kubernetes/outputs.tf`

- [ ] **Step 1: Create `outputs.tf`**

```hcl
output "publishers" {
  description = "Map of publisher name => { publisher_id, registration_token (token mode only), helm_release_name, namespace, status, vm_id, private_ip, public_ip }. VM-style fields are null for K8s deployments."
  sensitive   = true
  value = var.enrollment_mode == "token" ? {
    for n in local.publisher_names : n => {
      publisher_id       = module.registration[0].publishers[n].publisher_id
      registration_token = module.registration[0].publishers[n].registration_token
      helm_release_name  = n
      namespace          = kubernetes_namespace_v1.ns.metadata[0].name
      status             = helm_release.publisher[n].status
      vm_id              = null
      private_ip         = null
      public_ip          = null
    }
    } : {
    "npa-publisher" = {
      publisher_id       = null
      registration_token = null
      helm_release_name  = "npa-publisher"
      namespace          = kubernetes_namespace_v1.ns.metadata[0].name
      status             = helm_release.publisher["npa-publisher"].status
      vm_id              = null
      private_ip         = null
      public_ip          = null
    }
  }
}

output "publisher_names" {
  description = "Derived publisher names."
  value       = local.publisher_names
}

output "helm_release_names" {
  description = "List of Helm release names in cluster."
  value       = [for k in keys(local.release_names) : k]
}
```

- [ ] **Step 2: Validate**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher
terraform fmt -recursive
( cd modules/kubernetes && terraform validate 2>&1 | tail -3 )
```

Expected: `Success!`. If it errors that `local.release_names` is a set and `keys()` doesn't apply, change `helm_release_names` to `value = sort(tolist(local.release_names))`.

- [ ] **Step 3: Commit**

```bash
git add modules/kubernetes/outputs.tf
git commit -m "feat(kubernetes): outputs (publishers, publisher_names, helm_release_names)"
git push
```

---

## Task 7: Module — `modules/kubernetes/README.md` (Registry surface)

**Files:**
- Create: `modules/kubernetes/README.md`

- [ ] **Step 1: Create the README**

```markdown
# terraform-netskope-publisher — Kubernetes submodule

> 📖 **Full guides:** https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/kubernetes/

Provisions Netskope Private Access Publishers on Kubernetes by installing
the [`kubernetes-netskope-publisher`](https://github.com/johnneerdael/kubernetes-netskope-publisher)
Helm chart from `ghcr.io/johnneerdael/charts`. Works on EKS, AKS, GKE,
OpenShift, vanilla K8s, Kind — bring your own cluster context.

## Usage

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/kubernetes"
  version = "~> 2.2"

  name_prefix = "pub-k8s"
  replicas    = 1

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  namespace = "netskope"
}
```

See the [common inputs](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/common-inputs/)
and the [Kubernetes reference](https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/kubernetes/)
for the full input table, both enrollment modes, and HPA configuration.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.7 |
| hashicorp/helm | ~> 2.13 |
| hashicorp/kubernetes | ~> 2.30 |
| hashicorp/http | >= 3.4 |
```

- [ ] **Step 2: Commit**

```bash
git add modules/kubernetes/README.md
git commit -m "docs(kubernetes): per-submodule README for the Registry"
git push
```

---

## Task 8: Module — `examples/kubernetes-kind/`

**Files:**
- Create: `examples/kubernetes-kind/main.tf`
- Create: `examples/kubernetes-kind/variables.tf`
- Create: `examples/kubernetes-kind/terraform.tfvars.example`
- Create: `examples/kubernetes-kind/README.md`

- [ ] **Step 1: Create `examples/kubernetes-kind/variables.tf`**

```hcl
variable "netskope_tenant_url" {
  type = string
}

variable "netskope_api_token" {
  type      = string
  sensitive = true
}

variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context name to target. Empty string = current context."
  type        = string
  default     = ""
}
```

- [ ] **Step 2: Create `examples/kubernetes-kind/main.tf`**

```hcl
terraform {
  required_version = ">= 1.7"
  required_providers {
    helm       = { source = "hashicorp/helm",       version = "~> 2.13" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
    http       = { source = "hashicorp/http",       version = ">= 3.4" }
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context != "" ? var.kube_context : null
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context != "" ? var.kube_context : null
  }
}

module "publisher" {
  source = "../../modules/kubernetes"

  name_prefix = "demo-k8s"
  replicas    = 1

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  namespace = "netskope"
}

output "publishers" {
  value     = module.publisher.publishers
  sensitive = true
}
```

- [ ] **Step 3: Create `examples/kubernetes-kind/terraform.tfvars.example`**

```hcl
netskope_tenant_url = "https://tenant.goskope.com"
netskope_api_token  = "..."
kubeconfig_path     = "~/.kube/config"
kube_context        = "kind-netskope-demo"
```

- [ ] **Step 4: Create `examples/kubernetes-kind/README.md`**

```markdown
# Example: Kubernetes on Kind (local)

Spins up a local [Kind](https://kind.sigs.k8s.io/) cluster and deploys
the Netskope publisher Helm chart via Terraform.

## Prerequisites

- `kind` installed (`brew install kind` on macOS).
- `kubectl` installed.
- `helm` (optional, for manual chart inspection).

## Bring up the cluster

```bash
kind create cluster --name netskope-demo
```

## Run

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars (set tenant URL + API token + kube_context)
terraform init
terraform apply
```

The module installs the chart at `oci://ghcr.io/johnneerdael/charts/kubernetes-netskope-publisher`
into the `netskope` namespace. The pod will register with your tenant
within ~1 minute.

## Tear down

```bash
terraform destroy
kind delete cluster --name netskope-demo
```
```

- [ ] **Step 5: Validate the example**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher
terraform fmt -recursive
( cd examples/kubernetes-kind && rm -rf .terraform .terraform.lock.hcl && terraform init -backend=false 2>&1 | tail -3 && terraform validate 2>&1 | grep -o "Success\|Error" | head -1 )
```

Expected: `Success`.

- [ ] **Step 6: Commit**

```bash
git add examples/kubernetes-kind
git commit -m "feat(examples): kubernetes-kind example"
git push
```

---

## Task 9: Module — Docs site platform page + indexes

**Files:**
- Create: `site/source/admin/module/platforms/kubernetes.md`
- Modify: `site/source/admin/module/index.md`
- Modify: `site/source/admin/index.md`
- Modify: `site/source/admin/module/platforms/index.md`
- Modify: `site/source/admin/module/common-inputs.md`

- [ ] **Step 1: Create `site/source/admin/module/platforms/kubernetes.md`**

```markdown
---
title: Kubernetes platform inputs
date: 2026-05-19
toc: true
---

> ⚠️ The publisher Pods need outbound TCP/443 to your Netskope tenant.
> See [Connectivity requirements → Kubernetes](/terraform-netskope-publisher/admin/concepts/connectivity/)
> for NetworkPolicy, egress proxy, and image-pull notes.

## Inputs

The `kubernetes` submodule accepts:

| Name | Type | Default | Description |
|---|---|---|---|
| `namespace` | string | `"netskope"` | Created if it does not exist. |
| `enrollment_mode` | string | `"token"` | `"token"` (Terraform owns the publisher record) or `"api"` (chart self-registers). |
| `chart_version` | string | `"~> 1.4"` | Helm chart version constraint. |
| `chart_repository` | string | `"oci://ghcr.io/johnneerdael/charts"` | Helm chart repository URL. |
| `chart_values` | any | `{}` | Free-form values merged into the Helm release last (escape hatch). |
| `workload_type` | string | `"daemonset"` | `"daemonset"` or `"statefulset"`. `"statefulset"` is required for HPA. |
| `hpa_enabled` | bool | `false` | Enable HorizontalPodAutoscaler. Only meaningful with `workload_type = "statefulset"`. |
| `hpa_min_replicas` | number | `2` | HPA minimum. |
| `hpa_max_replicas` | number | `6` | HPA maximum. |
| `image_repository` | string | `null` | Override the publisher container image (e.g. private mirror). |
| `image_tag` | string | `null` | Override the image tag. |

The `wizard_path` common input is **not** used here — the chart's
container image already has the wizard at its canonical location.

## Minimal example (token mode, BYO cluster)

```hcl
provider "kubernetes" { config_path = "~/.kube/config" }
provider "helm" {
  kubernetes { config_path = "~/.kube/config" }
}

module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/kubernetes"
  version = "~> 2.2"

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  namespace = "netskope"
}
```

## Full example (api mode, HPA, StatefulSet)

```hcl
module "publisher" {
  source  = "johnneerdael/publisher/netskope//modules/kubernetes"
  version = "~> 2.2"

  name_prefix = "pub-k8s"
  replicas    = 1
  tags        = { team = "platform", env = "prod" }

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  namespace          = "netskope"
  enrollment_mode    = "api"
  workload_type      = "statefulset"
  hpa_enabled        = true
  hpa_min_replicas   = 3
  hpa_max_replicas   = 10
}
```

## Platform-specific outputs

| Output | Type | Description |
|---|---|---|
| `helm_release_names` | list(string) | Names of Helm releases created by this module. |
| `publishers` | map (sensitive) | Per-publisher data (token mode populates `publisher_id` + `registration_token`; api mode leaves both `null`). |

## Enrollment modes — when to pick which

| | `token` (default) | `api` |
|---|---|---|
| Registration owner | Terraform (via `npa_publisher` resources) | Chart container on Pod start |
| Replicas | One Helm release per name; each consumes one token | One Helm release; HPA / StatefulSet scales internally |
| Drift on rename | Detected by `npa_publisher` Terraform state | Not detected |
| `terraform destroy` removes publisher record | Yes | Only when `enrollment.api.cleanupOnDelete = true` AND no Private Apps attached |
| Recommended for | One-publisher-per-Pod, mirrors the VM submodule UX | HPA / StatefulSet autoscaling |

## Caveats

- **Chart pull from Internet.** The default repository is the public OCI
  artifact at `ghcr.io/johnneerdael/charts`. Air-gapped clusters need to
  mirror it; set `chart_repository` to point at the mirror.
- **Image pull from Docker Hub.** The chart pulls
  `netskopeprivateaccess/publisher_u22` from Docker Hub by default.
  Mirror via `image_repository` if your cluster cannot reach Docker Hub.
- **HPA only valid with StatefulSet.** If you set `hpa_enabled = true`
  without `workload_type = "statefulset"`, the module renders the HPA
  block but Kubernetes will not autoscale a DaemonSet.
- **`api`-mode publisher deletion** has known constraints — see the
  chart's [DELETE-cannot-remove-attached-apps note](https://github.com/johnneerdael/kubernetes-netskope-publisher#enrollmentapicleanupondelete).
```

- [ ] **Step 2: Update `site/source/admin/module/index.md`**

Append to the platforms list:

```markdown
- [Kubernetes](/terraform-netskope-publisher/admin/module/platforms/kubernetes/)
```

- [ ] **Step 3: Update `site/source/admin/index.md`**

Append to the same per-platform list:

```markdown
  - [Kubernetes](/terraform-netskope-publisher/admin/module/platforms/kubernetes/)
```

- [ ] **Step 4: Update `site/source/admin/module/platforms/index.md`**

Append:

```markdown
- [Kubernetes](/terraform-netskope-publisher/admin/module/platforms/kubernetes/)
```

- [ ] **Step 5: Update `site/source/admin/module/common-inputs.md`**

Find the `wizard_path` row in the Optional table and add a note at the end of its description:

```markdown
Not used by `modules/kubernetes` (the chart's container image already has the wizard at its canonical location).
```

- [ ] **Step 6: Build and commit**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher/site
./node_modules/.bin/hexo generate 2>&1 | tail -3
cd ..
git add site/source/admin/module site/source/admin/index.md
git commit -m "docs(site/admin): add Kubernetes platform page and link from indexes"
git push
```

---

## Task 10: Module — Docs site Concepts + Reference

**Files:**
- Modify: `site/source/admin/concepts/architecture-overview.md`
- Modify: `site/source/admin/concepts/connectivity.md`
- Modify: `site/source/reference/provider-matrix.md`
- Modify: `site/source/reference/roadmap.md`

- [ ] **Step 1: Architecture overview — add Kubernetes row**

In `site/source/admin/concepts/architecture-overview.md`, add to the "What lives where" table (after the Hyper-V row):

```markdown
| `modules/kubernetes` | Helm chart install + per-mode Kubernetes Secrets (token / api) | `hashicorp/helm`, `hashicorp/kubernetes` |
```

- [ ] **Step 2: Connectivity — add Kubernetes section**

In `site/source/admin/concepts/connectivity.md`, insert before the `## Hyper-V` section (or wherever in alphabetic / logical order fits the file's structure):

```markdown
## Kubernetes

`modules/kubernetes` installs the publisher chart into whatever cluster
the caller's `helm` + `kubernetes` providers point at. The Pods need
outbound TCP/443 to:

- Your Netskope tenant URL (registration in api mode; ongoing publisher↔gateway traffic always).
- Docker Hub at `index.docker.io` for the
  `netskopeprivateaccess/publisher_u22` image — override
  `image_repository` to point at a private mirror if Docker Hub is
  unreachable.

### NetworkPolicies

If the namespace has a default-deny egress NetworkPolicy, add an
explicit allow for TCP/443 from the publisher Pods (selectors per the
chart's standard labels).

### Egress through an HTTP proxy

The chart accepts `HTTPS_PROXY` / `HTTP_PROXY` / `NO_PROXY` env vars on
the publisher container via the `extraEnv` values key. Wire those into
`chart_values` if your cluster's egress is proxied.

### Chart pull

`oci://ghcr.io/johnneerdael/charts/kubernetes-netskope-publisher` is
publicly readable. Air-gapped clusters need to mirror the OCI artifact
and set `chart_repository` to point at the mirror.
```

- [ ] **Step 3: Provider matrix — add Kubernetes row**

In `site/source/reference/provider-matrix.md`, add to the "Required per platform" table:

```markdown
| `modules/kubernetes` | `helm`, `kubernetes` | `hashicorp/helm`, `hashicorp/kubernetes` | `~> 2.13`, `~> 2.30` |
```

- [ ] **Step 4: Roadmap — clean up**

In `site/source/reference/roadmap.md`, find the "Additional platforms"
section. Remove the `OpenShift Virtualization (KubeVirt)` bullet (the
new Kubernetes submodule covers OpenShift's K8s API generically). Add
this single new bullet:

```markdown
- **Per-platform Kubernetes wrappers** (`modules/eks-publisher`,
  `modules/aks-publisher`, `modules/gke-publisher`,
  `modules/openshift-publisher`) — thin shims that do cluster lookup
  via the platform's provider and then call `modules/kubernetes`.
  Possible v3 work driven by user demand.
```

- [ ] **Step 5: Build and commit**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher/site
./node_modules/.bin/hexo generate 2>&1 | tail -3
cd ..
git add site/source/admin/concepts site/source/reference
git commit -m "docs(site): Kubernetes additions to architecture, connectivity, provider matrix, roadmap"
git push
```

---

## Task 11: Module — README, CHANGELOG, tag `v2.2.0`

**Files:**
- Modify: `README.md`
- Modify: `site/source/index.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Update `README.md` intro paragraph**

Find:

```markdown
Provision Netskope Private Access Publishers on **AWS**, **Azure**, **GCP**,
**vSphere**, or **Hyper-V** via the Netskope NPA API and cloud-init.
```

Replace with:

```markdown
Provision Netskope Private Access Publishers on **AWS**, **Azure**, **GCP**,
**vSphere**, **Hyper-V**, or **Kubernetes** via the Netskope NPA API,
cloud-init (VM platforms), or Helm (Kubernetes).
```

- [ ] **Step 2: Update `README.md` "other platforms" line**

Find:

```markdown
For other platforms, source the matching submodule:
`//modules/azure`, `//modules/gcp`, `//modules/vsphere`, `//modules/hyperv`.
```

Replace with:

```markdown
For other platforms, source the matching submodule:
`//modules/azure`, `//modules/gcp`, `//modules/vsphere`, `//modules/hyperv`,
`//modules/kubernetes`.
```

- [ ] **Step 3: Update `site/source/index.md` supported-platforms line**

Find:

```markdown
Provision Netskope Private Access Publishers on **AWS**, **Azure**, **GCP**,
**vSphere**, or **Hyper-V** from a single Terraform module.
```

Replace with:

```markdown
Provision Netskope Private Access Publishers on **AWS**, **Azure**, **GCP**,
**vSphere**, **Hyper-V**, or **Kubernetes** from a single Terraform module.
```

- [ ] **Step 4: Add v2.2.0 to `CHANGELOG.md`**

Insert under `## [Unreleased]`:

```markdown
## [2.2.0] - 2026-05-19

### Added
- New `modules/kubernetes` submodule installs the
  [`kubernetes-netskope-publisher`](https://github.com/johnneerdael/kubernetes-netskope-publisher)
  Helm chart from `oci://ghcr.io/johnneerdael/charts` on any K8s
  cluster (EKS / AKS / GKE / OpenShift / vanilla / Kind).
- Two enrollment modes:
  - `token` (default): Terraform owns the publisher record via
    `npa_publisher` + `npa_publisher_token` from our provider, feeds the
    token to the chart through a per-publisher Kubernetes Secret.
  - `api`: chart's container self-registers via the Netskope API on Pod
    start. Suited to HPA / StatefulSet autoscaling.
- DX parity with the other submodules: `name_prefix`, `replicas`,
  `names`, `publisher_names` output.
- `examples/kubernetes-kind/` runnable example targeting a local Kind
  cluster.
- Docs site: new Kubernetes platform page, connectivity section,
  provider matrix entry, architecture row, roadmap update.

### Notes
- `wizard_path` common input is not consumed by `modules/kubernetes`
  (chart image carries the wizard).
- Plan-time test omitted (same `helm`/`kubernetes` provider eager-config
  trap as `azurerm`/`google`/`vsphere`/`hyperv`); covered by
  `terraform validate` + the runnable example.
```

- [ ] **Step 5: Tag and push**

```bash
cd /Users/jneerdael/Scripts/terraform-netskope-publisher
terraform fmt -recursive
git add README.md site/source/index.md CHANGELOG.md
git commit -m "docs: README + CHANGELOG for v2.2.0 (Kubernetes submodule)"
git tag -a v2.2.0 -m "v2.2.0 — Kubernetes support via Helm"
git push && git push --tags
```

---

## Task 12: Verify Registry indexing

**Files:** none.

- [ ] **Step 1: Wait for the Terraform Registry to index v2.2.0**

```bash
until curl -s https://registry.terraform.io/v1/modules/johnneerdael/publisher/netskope | grep -q '"2.2.0"'; do sleep 15; done
echo "registry indexed v2.2.0"
```

Expected: completes within ~5 min after `git push --tags`.

- [ ] **Step 2: Verify the Kubernetes submodule page resolves**

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://registry.terraform.io/modules/johnneerdael/publisher/netskope/2.2.0/submodules/kubernetes
```

Expected: `200`.

- [ ] **Step 3: Probe the docs site (after Pages deploy)**

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://johnneerdael.github.io/terraform-netskope-publisher/admin/module/platforms/kubernetes/
curl -s -o /dev/null -w "%{http_code}\n" https://johnneerdael.github.io/terraform-netskope-publisher/admin/concepts/connectivity/
```

Expected: both `200`.

---

## Self-review notes

**Spec coverage (every spec section → at least one task):**
- §3 Architecture (single submodule, both modes) → Task 5
- §4 Provider impact (none) → confirmed, no tasks needed
- §5 Chart distribution (workflow + OCI + visibility) → Tasks 1, 2, 3
- §6 Repo layout → Tasks 4, 5, 6, 7, 8
- §7 Module inputs → Task 4
- §8 Module outputs → Task 6
- §9 Helm chart prerequisites (already met) → no action needed
- §10 Testing strategy → Tasks 5, 6, 8 (validate); chart linted in Task 1
- §11 Documentation additions → Tasks 9, 10, 11
- §12 Rollout order → Tasks 1 → 12 in stated order
- §13 Risks/fallbacks → Task 3 (visibility), Task 5 (provider name v1/no-v1)

**Intentional omissions:**
- No `terraform test` for the K8s submodule (per spec §10 — same eager-config trap as Azure/GCP/vSphere/Hyper-V).
- No per-platform K8s wrappers (per spec §2 non-goals — explicitly deferred to v3).
- Module's home-page banner already mentions Registry; doesn't need a Kubernetes-specific badge — the supported-platforms line update (Task 11 Step 3) is enough.
