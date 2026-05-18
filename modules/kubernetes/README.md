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
