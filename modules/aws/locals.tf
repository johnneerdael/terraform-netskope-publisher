locals {
  publisher_names = var.names != null ? var.names : [
    for i in range(var.replicas) :
    format("%s-%d", var.name_prefix, i + 1)
  ]
}
