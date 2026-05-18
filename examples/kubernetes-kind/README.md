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
