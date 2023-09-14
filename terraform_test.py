#!/usr/bin/env python3

import logging
import os
import subprocess
from typing import Any, List

import pytest
import hcl2

from maas.client import connect
from maas.client.enum import NodeStatus


DEFAULT_TERRAFORM_TIMEOUT=600 # allow up to 10 minutes for Terraform to spin things up
DEFAULT_TERRAFORM_CONFIG = "./terraform_test.tf"


class MAASTerraformEndToEnd:
    def __init__(self):
        self._hcl_file = os.environ.get("MAAS_TERRAFORM_TEST_HCL", DEFAULT_TERRAFORM_CONFIG)
        self._tf_timeout = int(os.environ.get("MAAS_TERRAFORM_TIMEOUT", DEFAULT_TERRAFORM_TIMEOUT))

        # reusing Terraform variables to ensure same connection
        self._maas = connect(os.environ["TF_VAR_maas_url"], apikey=os.environ["TF_VAR_apikey"])

    def _log_proc_output(self, proc: subprocess.Popen, log: logging.Logger, is_err: bool = False):
        logfn = log.info
        if is_err:
            logfn = log.error
        
        if proc.stdout:
            stdout = proc.stdout.read().decode("utf-8")
            logfn(f"stdout:\n{stdout}")
        
        logfn("----------------------------------------------------------------")
        
        if proc.stderr:
            stderr = proc.stderr.read().decode("utf-8")
            logfn(f"stderr:\n{stderr}")

    def _run_and_check_tf(self, args: List[str], log: logging.Logger):
        proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        stdout, stderr = None, None
        try:
            ret_code = proc.wait(timeout=self._tf_timeout)
            assert ret_code == 0
        except subprocess.TimeoutExpired:
            proc.kill()
            log.error("Terraform execution timed out, stdout and stderr are as follows:")
            self._log_proc_output(proc, log, is_err=True)
            raise
        except Exception as e:
            proc.kill()
            log.error(f"Terraform execution encountered an error, {e},\n stdout and stderr are as follows:")
            self._log_proc_output(proc, log, is_err=True)
            raise
        else:
            log.info("Terraform succeeded, stdout and stderr are as follows:")
            self._log_proc_output(proc, log)

    def setup(self, log: logging.Logger) -> None:
        init = ["terraform", "init"]
        self._run_and_check_tf(init, log)
        cmd = ["terraform","apply", "-auto-approve", "-input=false"]
        self._run_and_check_tf(cmd, log)

    def check_maas_fabric(self, cfg: dict[str, Any]):
        fabrics = self._maas.fabrics.list()
        assert len(fabrics) > 0
        assert cfg["name"] in [ fabric.name for fabric in fabrics ]

    def check_maas_space(self, cfg: dict[str, Any]):
        spaces = self._maas.spaces.list()
        assert len(spaces) > 0
        assert cfg["name"] in [ space.name for space in spaces ]

    def check_maas_vlan(self, cfg: dict[str, Any]):
        fabrics = self._maas.fabrics.list()
        vlans = [vlan for fabric in fabrics for vlan in fabric.vlans ]

        found = False
        assert len(vlans) > 0
        for vlan in vlans:
            if cfg["name"] == vlan.name:
                found = True
                for key, value in cfg.items():
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
        for resource in tf_config["resource"]:
            for resource_type, cfg in resource.items():
                if hasattr(self, f"check_{resource_type}"):
                    fn = getattr(self, f"check_{resource_type}")
                    fn(list(cfg.values())[0]) # cfg tends to be in the shape of {<name>: {"name": <name>}}

    def teardown(self, log):
        cmd = ["terraform", "destroy", "-auto-approve", "-input=false"]
        self._run_and_check_tf(cmd, log)


def test_maas_terraform_provider():
    tester = MAASTerraformEndToEnd()
    log = logging.getLogger()
    try:
        tester.setup(log)
        tester.check_results()
    except Exception as e:
        tester.teardown(log)
        raise
    else:
        tester.teardown()


if __name__ == "__main__":
    pytest.main(args=["-v", "--junitxml=junit.xml"])
