terraform {
    required_providers {
        maas = {
            source = "terraform.maas.io/maas/maas"
        }
    }
}

provider "maas" {
    api_version = "2.0"
    api_key = "${apikey}"
    api_url = "${maas_url}"
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
}

resource "maas_subnet" "tf_test_subnet" {
    name = "tf_test_subnet"
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

resource "maas_machine" "tf_test_machine" {
    power_type = "${test_machine_power_type}"
    power_parameters = {
        power_address = "${test_machine_power_address}"
        power_id =  "tf_test_machine"
        power_user = "${test_machine_power_user}"
        power_password = "${test_machine_power_password}"
    }
    pxe_mac_address = "${test_machine_boot_mac}"
}

resource "maas_network_interface_physical" "tf_test_iface" {
    machine = maas_machine.tf_test_machine.id
    mac_address = "${test_machine_boot_mac}"
    name = "eth0"
    vlan = maas_vlan.tf_test_vlan.id
}

resource "maas_network_interface_link" "tf_test_link" {
    machine = maas_machine.tf_test_machine.id
    network_interface = maas_network_interface_physical.tf_test_iface.id
    subnet = maas_subnet.tf_test_subnet.id
    mode = "AUTO-ASSIGN"
}

resource "maas_block_device" "tf_test_block_device" {
    machine = maas_machine.tf_test_machine.id
    name = "vdb"
    id_path = "${path_to_block_device_id}"
    size_gigabytes = "${block_device_size}"
    
    partitions {
        size_gigabytes = "${block_device_partition_1_size}"
        fs_type = "etx4"
        mount_point = "/mnt/test_mount_1"
    }

    partitions {
        size_gigabytes = "${block_device_partition_2_size}"
        fs_type = "etx4"
        mount_point = "/mnt/test_mount_2"
    }
}

resource "maas_vm_host" "tf_test_vm_host" {
    type = "lxd"
    power_address = "${lxd_address}"
}

resource "maas_vm_host_machine" "tf_test_vm" {
    cores = 1
    memory = 8192
}

resource "maas_instance" "tf_test_host_instance" {
    allocaton_params {
        hostname =  "${maas_machine.tf_test_machine.hostname}"
        machine = maas_machine.tf_test_machine.id
    }
    deploy_params {
        osystem = "ubuntu"
        distro_series = "jammy"
    }
}

resource "maas_instance" "tf_test_vm_instance" {
    allocaton_params {
        hostname =  "${maas_machine.tf_test_vm.hostname}"
        machine = maas_machine.tf_test_vm.id
    }
    deploy_params {
        osystem = "ubuntu"
        distro_series = "jammy"
    }

}
