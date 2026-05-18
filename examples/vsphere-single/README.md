# Example: vSphere, single publisher

Clones a Netskope publisher template VM and bootstraps it via cloud-init's
VMware datasource (`guestinfo.userdata`). The template must contain
cloud-init (the official Netskope OVA does).
