---
title: Module reference
date: 2026-05-18
---

Each platform is its own submodule. Source the one you need:

```hcl
module "publisher" {
  source = "github.com/johnneerdael/terraform-netskope-publisher//modules/aws?ref=v2.0.0"
  # …
}
```

Substitute `aws` with `azure`, `gcp`, or `vsphere`.

## Common interface (every submodule)

- [Common inputs](/terraform-netskope-publisher/admin/module/common-inputs/)
- [Common outputs](/terraform-netskope-publisher/admin/module/common-outputs/)

## Platform-specific inputs

- [AWS](/terraform-netskope-publisher/admin/module/platforms/aws/)
- [Azure](/terraform-netskope-publisher/admin/module/platforms/azure/)
- [GCP](/terraform-netskope-publisher/admin/module/platforms/gcp/)
- [vSphere](/terraform-netskope-publisher/admin/module/platforms/vsphere/)
- [Hyper-V](/terraform-netskope-publisher/admin/module/platforms/hyperv/)
