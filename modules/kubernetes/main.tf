# Token-mode only: create per-replica publisher records + tokens via the
# shared registration submodule.
module "registration" {
  count = var.enrollment_mode == "token" ? 1 : 0

  source          = "../registration"
  tenant_url      = var.tenant_url
  api_token       = var.api_token
  publisher_names = local.publisher_names
}

# Namespace creation: idempotent. If the user created the namespace
# out-of-band, ignore metadata drift so we don't fight them.
resource "kubernetes_namespace_v1" "ns" {
  metadata {
    name = var.namespace
  }
  lifecycle {
    ignore_changes = [metadata]
  }
}

# Shared Secret for api-mode: chart reads NETSKOPE_API_TOKEN from this Secret.
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
  common_values = {
    workload = {
      type = var.workload_type
    }
    hpa = {
      enabled     = var.hpa_enabled && var.workload_type == "statefulset"
      minReplicas = var.hpa_min_replicas
      maxReplicas = var.hpa_max_replicas
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

  # Merge order: common -> mode-specific -> caller's chart_values (last wins).
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
