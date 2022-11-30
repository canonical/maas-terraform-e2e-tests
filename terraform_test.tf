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

resource "maas_dns_record" "tf_test_record" {
    type = "A/AAAA"
    data = "10.10.10.1"
    fqdn = "tftestrecord.${maas_dns_domain.tf_test_domain.name}"
}

/*resource "maas_machine" "tf_test_machine" {
    power_type = "${var.test_machine_power_type}"
    power_parameters = {
        power_address = "${var.test_machine_power_address}"
        power_user = "${var.test_machine_power_user}"
        power_password = "${var.test_machine_power_password}"
    }
    pxe_mac_address = "${var.test_machine_boot_mac}"
}

resource "maas_network_interface_physical" "tf_test_iface" {
    machine = maas_machine.tf_test_machine.id
    mac_address = "${var.test_machine_boot_mac}"
    name = "eth0"
    vlan = data.maas_vlan.vlan_0.id
}

resource "maas_network_interface_link" "tf_test_link" {
    machine = maas_machine.tf_test_machine.id
    network_interface = maas_network_interface_physical.tf_test_iface.id
    subnet = maas_subnet.tf_test_subnet.id
    mode = "AUTO"
}

resource "maas_block_device" "tf_test_block_device" {
    count = var.path_to_block_device_id != "" ? 1 : 0
    machine = maas_machine.tf_test_machine.id
    name = "vdb"
    id_path = "${var.path_to_block_device_id}"
    size_gigabytes = "${var.block_device_size}"
    
    partitions {
        size_gigabytes = "${var.block_device_partition_1_size}"
        fs_type = "etx4"
        mount_point = "/mnt/test_mount_1"
    }

    partitions {
        size_gigabytes = "${var.block_device_partition_2_size}"
        fs_type = "etx4"
        mount_point = "/mnt/test_mount_2"
    }
}*/

resource "maas_vm_host" "tf_test_vm_host" {
    count = var.lxd_address != ""? 1 : 0
    type = "lxd"
    power_address = "${var.lxd_address}"
}

resource "maas_vm_host_machine" "tf_test_vm" {
    count = var.lxd_address != "" ? 1 : 0
    cores = 1
    memory = 2048
    vm_host = "${maas_vm_host.tf_test_vm_host ? maas_vm_host.tf_test_vm_host[count.index].id : 0}"
}

resource "maas_instance" "tf_test_host_instance" {
    allocate_params {
        hostname =  "${var.test_machine_hostname}"
    }
    deploy_params {
        distro_series = "ubuntu/jammy"
    }
}

resource "maas_instance" "tf_test_vm_instance" {
    count = var.lxd_address != "" ? 1 : 0
    allocate_params {
        hostname =  "${maas_vm_host_machine.tf_test_vm[count.index].hostname}"
    }
    deploy_params {
        distro_series = "ubuntu/jammy"
    }

}
