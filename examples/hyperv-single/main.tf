terraform {
  required_version = ">= 1.7"
  required_providers {
    hyperv    = { source = "taliesins/hyperv", version = "~> 1.2" }
    http      = { source = "hashicorp/http", version = ">= 3.4" }
    cloudinit = { source = "hashicorp/cloudinit", version = ">= 2.3" }
  }
}

provider "hyperv" {
  host        = var.hyperv_host
  user        = var.hyperv_user
  password    = var.hyperv_password
  port        = 5986
  https       = true
  insecure    = true # lab default; configure WinRM HTTPS properly for production
  use_ntlm    = true
  script_path = "C:/Temp/terraform_%RAND%.cmd"
  timeout     = "30s"
}

module "publisher" {
  source = "../../modules/hyperv"

  name_prefix = "demo-hv"
  replicas    = 1

  tenant_url = var.netskope_tenant_url
  api_token  = var.netskope_api_token

  vswitch_name = var.vswitch_name

  hyperv_winrm_config = {
    host     = var.hyperv_host
    user     = var.hyperv_user
    password = var.hyperv_password
    port     = 5986
    https    = true
    insecure = true
    use_ntlm = true
  }
}

output "publishers" {
  value     = module.publisher.publishers
  sensitive = true
}
