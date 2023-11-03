variable "maas_url" {}
variable "apikey" {}
variable "test_machine_power_type" {}
variable "test_machine_power_address" {}
variable "test_machine_power_user" {}
variable "test_machine_power_password" {}
variable "test_machine_boot_mac" {}
variable "test_machine_hostname" {
  default = "natasha"
}
variable "path_to_block_device_id" {
  default = ""
}
variable "block_device_size" {
  default = 0
}
variable "block_device_partition_1_size" {
  default = 0
}
variable "block_device_partition_2_size" {
  default = 0
}
variable "lxd_address" {
  default = ""
}
variable "pxe_subnet_cidr" {}

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

resource "maas_vm_host" "tf_test_vm_host" {
  count         = var.lxd_address != "" ? 1 : 0
  type          = "lxd"
  power_address = var.lxd_address
}

resource "maas_vm_host_machine" "tf_test_vm" {
  count      = var.lxd_address != "" ? 1 : 0
  cores      = 1
  memory     = 2048
  vm_host    = maas_vm_host.tf_test_vm_host[0].id
  depends_on = [maas_vm_host.tf_test_vm_host]
}

resource "maas_instance" "tf_test_vm_instance" {
  count = var.lxd_address != "" ? 1 : 0
  allocate_params {
    hostname = maas_vm_host_machine.tf_test_vm[0].hostname
  }
  deploy_params {
    distro_series = "ubuntu/jammy"
  }
}

resource "maas_instance" "tf_test_host_instance" {
  count = var.test_machine_hostname != "" ? 1 : 0
  allocate_params {
    hostname = var.test_machine_hostname
  }
  deploy_params {
    distro_series = "ubuntu/jammy"
  }
}
