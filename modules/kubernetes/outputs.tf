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
  value       = sort(tolist(local.release_names))
}
