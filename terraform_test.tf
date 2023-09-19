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

terraform {
    required_providers {
        maas = {
            source = "terraform.maas.io/maas/maas"
        }
    }
}

provider "maas" {
    api_version = "2.0"
    api_key = "${var.apikey}"
    api_url = "${var.maas_url}"
}

resource "maas_space" "tf_test_space" {
    name = "tf_test_space"
}

resource "maas_fabric" "tf_test_fabric" {
    name = "tf_test_fabric"
}

resource "maas_vlan" "tf_test_vlan" {
    name = "tf_test_vlan"
    fabric = maas_fabric.tf_test_fabric.id
    vid = 2
    depends_on = [maas_fabric.tf_test_fabric]
}

resource "maas_subnet" "tf_test_subnet" {
    name = "tf_test_subnet"
    fabric = maas_fabric.tf_test_fabric.id
    vlan = maas_vlan.tf_test_vlan.id
    cidr = "10.10.10.0/24"
    gateway_ip = "10.10.10.1"
    dns_servers = ["1.1.1.1"]
    ip_ranges {
        type = "reserved"
        start_ip = "10.10.10.1"
        end_ip = "10.10.10.12"
    }
    ip_ranges {
        type = "dynamic"
        start_ip = "10.10.10.24"
        end_ip = "10.10.10.56"
    }
    depends_on = [maas_vlan.tf_test_vlan]
}

data "maas_fabric" "fabric_0" {
    name = "fabric-0"
}

data "maas_vlan" "vlan_0" {
    fabric = data.maas_fabric.fabric_0.id
    vlan = 0
}

data "maas_subnet" "pxe" {
    cidr = "10.245.136.0/21"
}

resource "maas_dns_domain" "tf_test_domain" {
    name = "tftest"
    ttl = 3600
    authoritative = true
}

resource "maas_instance" "tf_test_host_instance" {
    allocate_params {
        hostname =  "${var.test_machine_hostname}"
    }
    deploy_params {
        distro_series = "ubuntu/jammy"
    }
}
