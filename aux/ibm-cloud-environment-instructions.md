Instructions for VMware Cloud Public Cloud Open Environment (IBM)
Messages
You can access your bastion via SSH:
ssh lab-user@bastion-g2lvh.g2lvh.dynamic.redhatworkshops.io
SSH password generated:
dySxGJsHCyoL


Your VCenter information is:

VCenter URL: https://vcsnsx-vc.infra.demo.redhat.com/ui/app/search?query=bastion&searchType=simple

Username: sandbox-g2lvh@demo

Password: t3N88sBx_ZG0

Subnet CIDR: 192.168.23.0/24 (Network segment-sandbox-g2lvh)

IMPORTANT: All the VMs needs to be stored on the folder Workloads/sandbox-g2lvh to be visible for you


API DNS api.g2lvh.dynamic.redhatworkshops.io points to NAT IP to 192.168.23.201

Wildcard DNS *.apps.g2lvh.dynamic.redhatworkshops.io points to NAT IP to 192.168.23.202

You need to specify the folder /SDDC-Datacenter/vm/Workloads/sandbox-g2lvh on the install-config.yaml

Follow the official documentation to add the vCenter root CA to your system trust


----------------------------WARNING—-WARNING—-WARNING----------------------------

We monitor usage and we will be charging back to your cost center.

Reports from the cloud provider of misuse or account compromise will result

in immediate deletion of this entire account without any warning to you.

Do not post your credentials in github/email/web pages/etc.

NOTE: Most account compromises occur by checking credentials into github.

----------------------------WARNING—-WARNING—-WARNING----------------------------

Data
bastion_public_hostname: bastion-g2lvh.g2lvh.dynamic.redhatworkshops.io
bastion_ssh_password: dySxGJsHCyoL
bastion_ssh_user_name: lab-user
vcenter_password: t3N88sBx_ZG0
vcenter_subnet_cidr: 192.168.23.0/24 (Network segment-sandbox-g2lvh)
vcenter_url: >-
  https://vcsnsx-vc.infra.demo.redhat.com/ui/app/search?query=bastion&searchType=simple
vcenter_user_name: sandbox-g2lvh@infra
vcenter_vm_folder: Workloads/sandbox-g2lvh