# Example: AWS, single publisher

Provisions one EC2 publisher in AWS using the latest Netskope-published AMI.
Copy `terraform.tfvars.example` to `terraform.tfvars`, fill in values, then:

```bash
terraform init
terraform apply
```

The publisher is registered with your tenant via cloud-init on first boot.
