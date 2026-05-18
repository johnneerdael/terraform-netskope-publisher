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

  namespace        = "netskope"
  enrollment_mode  = "api"
  workload_type    = "statefulset"
  hpa_enabled      = true
  hpa_min_replicas = 3
  hpa_max_replicas = 10
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
