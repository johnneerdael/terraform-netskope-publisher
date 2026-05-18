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
