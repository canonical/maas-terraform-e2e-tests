#!/usr/bin/env python3

import logging
import subprocess
from typing import Any

import pytest
import hcl2

from maas.client import connect
from maas.client.enum import NodeStatus


DEFAULT_TERRAFORM_TIMEOUT=300 # allow up to 5 minutes for Terraform to spin things up
DEFAULT_TERRAFORM_CONFIG = "./terraform_test.tf"


class MAASTerraformEndToEnd:
    def __init__(self):
        self._hcl_file = os.environ.get("MAAS_TERRAFORM_TEST_HCL", DEFAULT_TERRAFORM_CONFIG)
        self._tf_timeout = int(os.environ.get("MAAS_TERRAFORM_TIMEOUT", DEFAULT_TERRAFORM_TIMEOUT))

        # reusing Terraform variables to ensure same connection
        self._maas = connect(os.environ["TF_VAR_maas_url"], apikey=os.environ["TF_VAR_apikey"])

    def setup(self, log: logging.Logger) -> None:
        cmd = ["terraform","apply"]
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

        try:
            out, err = proc.communicate(timeout=self._tf_timeout)
        except TimeoutExpired:
            proc.kill()
            log.error("Terraform execution timed out, stdout and stderr are as follows:")
            log.error(f"stdout:\n{out}")
            log.error("----------------------------------------------------------------")
            log.error(f"stderr:\n{out}")
        except Exception as e:
            proc.kill()
            log.error(f"Terraform execution encountered an error, {e},\n stdout and stderr are as follows:")
            log.error(f"stdout:\n{out}")
            log.error("----------------------------------------------------------------")
            log.error(f"stderr:\n{out}")
        else:
            log.info("Terraform succeeded, stdout and stderr are as follows:")
            log.info(f"stdout:\n{out}")
            log.info("----------------------------------------------------------------")
            log.info(f"stderr:\n{out}")

    def check_maas_fabric(self, cfg: dict[str, Any]):
        fabrics = self._maas.fabrics.list()
        assert cfg["name"] in [ fabric.name for fabric in fabrics ]

    def check_maas_space(self, cfg: dict[str, Any]):
        spaces = self._maas.spaces.list()
        assert cfg["name"] in [ space.name for space in spaces ]

    def check_maas_vlan(self, cfg: dict[str, Any]):
        vlans = self._maas.vlans.list()
        found = False
        for vlan in vlans:
            if cfg["name"] == vlan.name:
                found = True
                for key, value in cfg.items:
                    result = getattr(vlan, key)
                    assert value == result
        assert found

    def check_maas_subnet(self, cfg: dict[str, Any]):
        subnet = self._maas.subnets.get(cfg["cidr"])
        assert subnet is not None
        for key, value in cfg.items():
            result = getattr(subnet, key)
            assert value == result

    def check_maas_dns_domain(self, cfg: dict[str, Any]):
        domain = self._maas.domains.get(cfg["name"])
        assert domain is not None

    def check_maas_dns_record(self, cfg: dict[str, Any]):
        record = self._maas.dnsresources.get(cfg["fqdn"])
        assert record is not None
        assert cfg["data"] == record.data

    def check_maas_machine(self, cfg: dict[str, Any]):
        machine = self._maas.machines.get(mac_address=cfg["pxe_mac_address"])
        assert machine is not None

    def check_maas_instance(self, cfg: dict[str, Any]):
        machine = self._maas.machine.get(hostname=cfg["allocation_params"]["hostname"])
        assert machine is not None
        assert machine.status == NodeStatus.Deployed

    def check_results(self) -> None:
        with open(self._hcl_file) as f:
            tf_config = hcl2.load(f)
        for resource in tf_config["resources"]:
            for resource_type, cfg in resource.items():
                if hasattr(self, f"check_{resource_type}"):
                    fn = getattr(self, f"check_{resource_type}")
                    fn(cfg)

    def teardown(self):
        cmd = ["terraform", "destroy"]
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

        try:
            out, err = proc.communicate(timeout=self._tf_timeout)
        except TimeoutExpired:
            proc.kill()
            log.error("Teardown execution timed out, stdout and stderr are as follows:")
            log.error(f"stdout:\n{out}")
            log.error("----------------------------------------------------------------")
            log.error(f"stderr:\n{out}")
        except Exception as e:
            proc.kill()
            log.error(f"Teardown execution encountered an error, {e},\n stdout and stderr are as follows:")
            log.error(f"stdout:\n{out}")
            log.error("----------------------------------------------------------------")
            log.error(f"stderr:\n{out}")
        else:
            log.info("Teardown succeeded, stdout and stderr are as follows:")
            log.info(f"stdout:\n{out}")
            log.info("----------------------------------------------------------------")
            log.info(f"stderr:\n{out}")


def test_maas_terraform_provider(log: logging.Logger):
    tester = MAASTerraformEndToEnd()
    try:
        tester.setup(log)
        tester.check_results()
    except Exception as e:
        tester.teardown()
        raise
    else:
        tester.teardown()


if __name__ == "__main__":
    pytest.main(args=["-v", "--junitxml=junit.xml"])
