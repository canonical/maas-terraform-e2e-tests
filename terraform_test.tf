variable "maas_url" {}
variable "apikey" {}
variable "test_machine_power_type" {}
variable "test_machine_power_address" {}
variable "test_machine_power_user" {}
variable "test_machine_power_password" {}
variable "test_machine_power_driver" {}
variable "test_machine_power_boot_type" {}
variable "test_machine_mac_address" {}
variable "pxe_subnet_cidr" {}
variable "distro_series" {
  default = "ubuntu/jammy"
}

terraform {
  required_providers {
    maas = {
      source = "terraform.maas.io/maas/maas"
    }
  }
}

provider "maas" {
  api_version = "2.0"
  api_key     = var.apikey
  api_url     = var.maas_url
}

resource "maas_space" "tf_test_space" {
  name = "tf_test_space"
}

resource "maas_fabric" "tf_test_fabric" {
  name = "tf_test_fabric"
}

resource "maas_vlan" "tf_test_vlan" {
  name       = "tf_test_vlan"
  fabric     = maas_fabric.tf_test_fabric.id
  vid        = 2
  depends_on = [maas_fabric.tf_test_fabric]
}

resource "maas_subnet" "tf_test_subnet" {
  name        = "tf_test_subnet"
  fabric      = maas_fabric.tf_test_fabric.id
  vlan        = maas_vlan.tf_test_vlan.id
  cidr        = "10.10.10.0/24"
  gateway_ip  = "10.10.10.1"
  dns_servers = ["1.1.1.1"]
  ip_ranges {
    type     = "reserved"
    start_ip = "10.10.10.1"
    end_ip   = "10.10.10.12"
  }
  ip_ranges {
    type     = "dynamic"
    start_ip = "10.10.10.24"
    end_ip   = "10.10.10.56"
  }
  depends_on = [maas_vlan.tf_test_vlan]
}

data "maas_fabric" "fabric_0" {
  name = "fabric-0"
}

data "maas_vlan" "vlan_0" {
  fabric = data.maas_fabric.fabric_0.id
  vlan   = 0
}

data "maas_subnet" "pxe" {
  cidr = var.pxe_subnet_cidr
}

resource "maas_dns_domain" "tf_test_domain" {
  name          = "tftest"
  ttl           = 3600
  authoritative = true
}

# Re-enable when https://warthogs.atlassian.net/browse/MAASENG-2177 is ready
# resource "maas_dns_record" "tf_test_record" {
#     type = "A/AAAA"
#     data = "10.10.10.1"
#     fqdn = "tftestrecord.${maas_dns_domain.tf_test_domain.name}"
#     depends_on = [maas_dns_domain.tf_test_domain]
# }

resource "maas_machine" "tf_test_machine" {
  power_type = var.test_machine_power_type
  power_parameters = jsonencode({
    power_address   = var.test_machine_power_address
    power_user      = var.test_machine_power_user
    power_pass      = var.test_machine_power_password
    power_driver    = var.test_machine_power_driver
    power_boot_type = var.test_machine_power_boot_type
  })
  pxe_mac_address = var.test_machine_mac_address
}

resource "maas_vm_host" "tf_test_vm_host" {
  machine = maas_machine.tf_test_machine.id
  type    = "lxd"

  timeouts {
    create = "40m"
  }
}

resource "maas_vm_host_machine" "tf_test_vm" {
  vm_host = maas_vm_host.tf_test_vm_host.id
  cores   = 1
  memory  = 2048
}

resource "maas_instance" "tf_test_vm_instance" {
  allocate_params {
    hostname = maas_vm_host_machine.tf_test_vm.hostname
  }
  deploy_params {
    distro_series = var.distro_series
  }
}

resource "maas_vm_host_machine" "tf_test_vm_acceptance" {
  hostname = "acceptance-vm"
  vm_host  = maas_vm_host.tf_test_vm_host.id
  cores    = 1
  memory   = 2048
}
