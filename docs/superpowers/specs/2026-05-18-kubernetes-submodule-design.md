# Kubernetes Submodule (`modules/kubernetes`) — Design

**Status:** Draft — pending implementation
**Date:** 2026-05-18
**Owner:** John Neerdael
**Target release:**
- `terraform-netskope-publisher` → `v2.2.0`
- `kubernetes-netskope-publisher` (Helm chart) → `v1.4.0`
- `terraform-provider-netskope-publisher` → no release (untouched)

## 1. Goal

Provision Netskope Private Access Publishers on **Kubernetes** by
installing the existing `kubernetes-netskope-publisher` Helm chart via
Terraform's `helm_release`. The submodule slots into the existing v2
per-platform-submodule architecture alongside AWS / Azure / GCP /
vSphere / Hyper-V.

## 2. Non-goals (v1 of this submodule)

- Per-platform K8s wrappers (`modules/eks-publisher`, `modules/aks-publisher`,
  `modules/gke-publisher`, `modules/openshift-publisher`). Stays
  documented as a possible v3 effort driven by user demand.
- KubeVirt / OpenShift Virtualization (VM-on-K8s) — deferred to a
  separate `modules/kubevirt` if/when there's demand.
- ArgoCD / Flux GitOps deployment of the chart.
- Multi-cluster fan-out — callers do that with `for_each` over their
  cluster list; module is single-cluster.
- A `helm chart_repository` Terraform data source on the provider — not
  needed; `helm_release.repository` accepts the OCI URL directly.

## 3. Architecture

**Single shared submodule, BYO cluster context.** `modules/kubernetes`
takes pre-configured `helm` and `kubernetes` providers from the caller.
Works identically on EKS, AKS, GKE, OpenShift, vanilla K8s, Kind, etc.
The submodule pulls in only `helm`, `kubernetes`, and `http`
(transitively, for the `modules/registration` call in `token` mode).

Two enrollment modes supported, exposed as
`enrollment_mode = "token" | "api"` (default `"token"`):

| | `token` (default) | `api` |
|---|---|---|
| Registration owner | Terraform (via `modules/registration`) | Chart container (Netskope API on pod start) |
| Replicas | One Helm release per name (each consumes one token) | One Helm release; HPA / StatefulSet scales internally |
| Drift on publisher rename | Detected by `npa_publisher` Terraform state | Not detected (chart owns the record) |
| `terraform destroy` removes publisher | Yes (via `npa_publisher` delete) | Only when `enrollment.api.cleanupOnDelete = true` AND no Private Apps attached |
| Recommended for | One-publisher-per-pod patterns; matches VM submodule UX | HPA / StatefulSet autoscaling |

## 4. Provider impact

**None on `terraform-provider-netskope-publisher`.** `npa_publisher` and
`npa_publisher_token` (v0.1.1) already cover what `token`-mode requires;
`api`-mode uses no provider resources at all.

## 5. Chart distribution

The chart needs to be reachable from `helm_release`. We add an OCI
publishing workflow to the chart repo.

### 5.1 New file in `kubernetes-netskope-publisher`

`.github/workflows/release-chart.yml`:

- Trigger: `push: tags: v*`
- Permissions: `contents: read`, `packages: write`
- Steps:
  1. `actions/checkout@v4`
  2. `azure/setup-helm@v4` (latest stable)
  3. `helm lint .` — fail-fast on chart errors
  4. `helm package . --version "${TAG#v}" --app-version "${TAG#v}"`
  5. `echo "$GITHUB_TOKEN" | helm registry login ghcr.io -u "$GITHUB_ACTOR" --password-stdin`
  6. `helm push kubernetes-netskope-publisher-*.tgz oci://ghcr.io/johnneerdael/charts`

### 5.2 One-time manual GHCR setup

After the first successful workflow run, go to
GitHub → Packages → `kubernetes-netskope-publisher` →
**Package settings → Change visibility → Public**. Otherwise
`helm_release` from Terraform can't pull without registry credentials.

### 5.3 Chart README addition

Short "Install via Terraform" section pointing at
`johnneerdael/publisher/netskope//modules/kubernetes`.

### 5.4 Chart version semantics

Module input `chart_version` defaults to `"~> 1.4"`. Any `1.4.x` patch
publish is picked up automatically. Breaking chart changes require a
coordinated module bump.

## 6. Repo layout (additions to `terraform-netskope-publisher`)

```
modules/kubernetes/
├── README.md
├── versions.tf            # required_providers: helm ~> 2.13, kubernetes ~> 2.30, http >= 3.4
├── variables.tf
├── locals.tf              # derives publisher_names from name_prefix+replicas+names
├── main.tf                # registration submodule call + helm_release
├── outputs.tf
└── examples-values/
    └── minimal.yaml       # reference Helm values doc (for users adapting their own)

examples/kubernetes-kind/
├── README.md
├── main.tf
├── variables.tf
└── terraform.tfvars.example
```

## 7. Module inputs

### 7.1 Common (parity with other submodules)

| Name | Type | Default | Description |
|---|---|---|---|
| `name_prefix` | string | `"npa-publisher"` | Used to derive names when `names` is null. |
| `names` | list(string) | `null` | Explicit publisher names; overrides `name_prefix` + `replicas`. |
| `replicas` | number | `1` | Number of publishers (one Helm release each in `token` mode; one release scaled by HPA in `api` mode). |
| `tenant_url` | string | required | Netskope tenant URL. |
| `api_token` | string (sensitive) | required | NPA API token. |
| `tags` | map(string) | `{}` | Translated to chart values via `commonLabels`. |

`wizard_path` is **omitted** — the chart's container image already has
the wizard at its canonical location; no on-VM cloud-init.

### 7.2 Kubernetes-specific

| Name | Type | Default | Description |
|---|---|---|---|
| `namespace` | string | `"netskope"` | Created if it doesn't exist; one shared namespace for all replicas. |
| `enrollment_mode` | string | `"token"` | `"token"` or `"api"`. See Section 3 for trade-offs. |
| `chart_version` | string | `"~> 1.4"` | Helm chart version constraint. |
| `chart_repository` | string | `"oci://ghcr.io/johnneerdael/charts"` | Chart repo URL. Override for private mirrors. |
| `chart_values` | any | `{}` | Free-form object merged into the Helm `values` last (escape hatch). |
| `workload_type` | string | `"daemonset"` | Pass-through to `workload.type` in chart values. `"statefulset"` enables HPA. |
| `hpa_enabled` | bool | `false` | Only meaningful with `workload_type = "statefulset"`. |
| `hpa_min_replicas` | number | `2` | HPA minimum. |
| `hpa_max_replicas` | number | `6` | HPA maximum. |
| `image_repository` | string | `null` | Override the publisher container image (e.g. private mirror). |
| `image_tag` | string | `null` | Override image tag. |

## 8. Module outputs

```hcl
output "publishers" {
  sensitive = true
  # Map keyed by publisher name:
  #   { publisher_id, registration_token (token mode only), helm_release_name, namespace, status }
  # vm_id / private_ip / public_ip = null (not applicable to K8s).
}

output "publisher_names" {
  # Derived list.
}

output "helm_release_names" {
  # List of release names in cluster, useful for downstream `helm` operations.
}
```

## 9. Helm chart prerequisites (already met)

`kubernetes-netskope-publisher` already supports both enrollment modes
(`enrollment.mode = "token"` and `"api"`) per the current `values.yaml`.
Specifically:

- `token` mode: chart consumes a pre-supplied token from a Secret
  (`registrationToken.value` or `registrationToken.existingSecret`).
- `api` mode: chart's main container talks to the Netskope API on pod
  start (`enrollment.api.baseUrl` + `enrollment.api.existingSecret`).

No chart changes required beyond the publishing workflow.

## 10. Testing strategy

- **No `terraform test` for the K8s submodule.** The `helm` provider
  doesn't have a clean `mock_provider` story for `command = plan` (same
  trap as `azurerm`/`google`/`vsphere`). Coverage:
  - `terraform validate` on `modules/kubernetes` (catches schema and
    reference bugs)
  - `terraform validate` on the example
  - Runnable example `examples/kubernetes-kind/` for end-to-end
    integration against a local Kind cluster
- **Chart pre-flight:** `helm lint` step in the publish workflow.
- **Existing module tests stay green:** the `cloudinit`, `registration`,
  and `aws_plan` tests are untouched.

## 11. Documentation additions

- New: `site/source/admin/module/platforms/kubernetes.md` —
  inputs table, minimal + full example, both enrollment modes, Caveats
  (chart pre-flight, image pull from internet, HPA only valid with
  StatefulSet, chart version pinning).
- Modify: `site/source/admin/concepts/architecture-overview.md` — add
  `modules/kubernetes` row to "What lives where".
- Modify: `site/source/admin/concepts/connectivity.md` — new
  "Kubernetes" section (pod egress to TCP/443, NetworkPolicies, image
  pull from Docker Hub).
- Modify: `site/source/admin/module/index.md` and `index.md` (admin
  landing) — add Kubernetes link.
- Modify: `site/source/admin/module/platforms/index.md` — add row.
- Modify: `site/source/admin/module/common-inputs.md` — note that
  `wizard_path` doesn't apply to the K8s submodule.
- Modify: `site/source/reference/provider-matrix.md` — new row
  `modules/kubernetes` → `helm ~> 2.13`, `kubernetes ~> 2.30`.
- Modify: `site/source/reference/roadmap.md` — remove "OpenShift
  Virtualization (KubeVirt)" from Additional platforms (Kubernetes
  covers OpenShift's K8s API generically); add a single line:
  "Per-platform Kubernetes wrappers (EKS/AKS/GKE/OpenShift-specific
  cluster lookups) — possible v3 work driven by user demand."
- Modify: `README.md` (repo) and `site/source/index.md` — add
  Kubernetes to the supported-platforms line and the `//modules/...`
  list.

## 12. Rollout order

1. Chart repo: add `.github/workflows/release-chart.yml`. Tag `v1.4.0`
   → GH Action publishes to `ghcr.io/johnneerdael/charts/kubernetes-netskope-publisher:1.4.0`.
2. Manual one-time: GHCR package visibility → **Public**.
3. Smoke-test:
   ```bash
   helm show chart oci://ghcr.io/johnneerdael/charts/kubernetes-netskope-publisher --version 1.4.0
   ```
   Should print the chart metadata.
4. Module repo: land `modules/kubernetes/` + docs + example. Run
   `terraform validate` end-to-end.
5. Tag module `v2.2.0` → docs site auto-deploys via the existing GH
   Actions Pages workflow.
6. Verify Terraform Registry indexes v2.2.0 within ~5 min at
   `https://registry.terraform.io/modules/johnneerdael/publisher/netskope/2.2.0`.

## 13. Risks and fallbacks

### Risk: `helm_release` chart pull fails on first apply

Cause: GHCR package still **private**. Fix: flip visibility to Public
in the GitHub Package settings page (one-click).

### Risk: Module pulls in `helm` + `kubernetes` providers in all roots

Like every other v2 submodule, the providers are only declared in
`modules/kubernetes/versions.tf`. Callers using other platforms never
touch them. No regression to other submodules.

### Risk: Chart breaking change without coordinated module bump

The `chart_version = "~> 1.4"` default allows any `1.4.x` patch.
Breaking changes ship as `1.5.0` and we bump the module default in the
same commit.

## 14. Out of scope (recap)

- Per-platform K8s wrappers (EKS/AKS/GKE/OpenShift).
- KubeVirt / OpenShift Virtualization.
- ArgoCD / Flux GitOps deployment.
- Multi-cluster fan-out (caller's responsibility).
- Helm chart_repository data source on the provider.
