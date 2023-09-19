#!/usr/bin/env python3

import logging
import os
import subprocess
from typing import Any, List

import pytest
import hcl2

from maas.client import connect
from maas.client.enum import NodeStatus


DEFAULT_TERRAFORM_TIMEOUT = 600 # allow up to 10 minutes for Terraform to spin things up


class MAASTerraformEndToEnd:
    def __init__(self):
        self._tf_timeout = int(os.environ.get("MAAS_TERRAFORM_TIMEOUT", DEFAULT_TERRAFORM_TIMEOUT))

        # reusing Terraform variables to ensure same connection
        self._maas = connect(os.environ["TF_VAR_maas_url"], apikey=os.environ["TF_VAR_apikey"])

    def _get_and_log_proc_output(self, proc: subprocess.Popen, log: logging.Logger, is_err: bool = False) -> str:
        stdout = None
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
        return stdout

    def _run_and_check_tf(self, args: List[str], log: logging.Logger) -> str:
        proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        stdout, stderr = None, None
        try:
            ret_code = proc.wait(timeout=self._tf_timeout)
            assert ret_code == 0
        except subprocess.TimeoutExpired:
            proc.kill()
            log.error("Terraform execution timed out, stdout and stderr are as follows:")
            self._get_and_log_proc_output(proc, log, is_err=True)
            raise
        except Exception as e:
            proc.kill()
            log.error(f"Terraform execution encountered an error, {e},\n stdout and stderr are as follows:")
            self._get_and_log_proc_output(proc, log, is_err=True)
            raise
        else:
            log.info("Terraform succeeded, stdout and stderr are as follows:")
            return self._get_and_log_proc_output(proc, log)

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
                assert cfg["vid"] == vlan.vid
        assert found

    def check_maas_subnet(self, cfg: dict[str, Any]):
        subnet = self._maas.subnets.get(cfg["cidr"])
        assert subnet is not None

    def check_maas_dns_domain(self, cfg: dict[str, Any]):
        domain = self._maas.domains.get(cfg["name"])
        assert domain is not None

    def check_maas_machine(self, cfg: dict[str, Any]):
        machine = self._maas.machines.get(mac_address=cfg["pxe_mac_address"])
        assert machine is not None

    def check_maas_instance(self, cfg: dict[str, Any]):
        machine_hostname = cfg["allocate_params"][0]["hostname"]
        machines = self._maas.machines.list(hostnames=[machine_hostname])
        assert len(machines) == 1
        assert machines[0].hostname == machine_hostname
        assert machines[0].status == NodeStatus.DEPLOYED

    def check_results(self, log: logging.Logger) -> None:
        resolved_config = self._run_and_check_tf(["terraform", "show"], log)
        tf_config = hcl2.loads(resolved_config)
        print(tf_config)
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
        tester.check_results(log)
    except Exception as e:
        tester.teardown(log)
        raise
    else:
        tester.teardown(log)


if __name__ == "__main__":
    pytest.main(args=["-v", "--junitxml=junit.xml"])
