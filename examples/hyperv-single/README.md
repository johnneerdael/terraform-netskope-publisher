# Example: Hyper-V, single publisher

Provisions one Netskope Private Access Publisher VM on a Hyper-V host
over WinRM. The Hyper-V host downloads the master VHDX from S3 on
first apply (subsequent applies reuse the cached copy).

## Prerequisites on the Hyper-V host

- Windows Server 2016+ with the Hyper-V role.
- WinRM enabled (HTTPS preferred). Quick HTTPS bootstrap:
  ```powershell
  winrm quickconfig
  $cert = New-SelfSignedCertificate -CertStoreLocation cert:\LocalMachine\My `
            -DnsName $env:COMPUTERNAME
  New-Item -Path WSMan:\localhost\Listener -Transport HTTPS `
           -Address * -CertificateThumbPrint $cert.Thumbprint -Force
  New-NetFirewallRule -DisplayName "WinRM-HTTPS" -Direction Inbound `
                      -LocalPort 5986 -Protocol TCP -Action Allow
  ```
- An existing virtual switch (external type, with outbound internet
  access). `Get-VMSwitch` to list.
- Outbound HTTPS reachable from the host to
  `s3-us-west-2.amazonaws.com` and your Netskope tenant.

## Run

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars
terraform init
terraform apply
```

First apply downloads ~3 GiB (the master VHDX). Subsequent applies for
additional replicas reuse the cached VHDX.
