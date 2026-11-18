#!/usr/bin/env python3
"""Build an Ansible INI inventory from OCI instance tags.

Runs on the ops runner and uses either a local API key (~/.oci/config) or
the instance principal of the runner. No Terraform state required.
"""
import json
import os
import subprocess
import sys

COMPARTMENT = os.environ.get("OCI_COMPARTMENT_OCID")
AUTH_MODE = os.environ.get("OCI_AUTH_MODE", "api_key")

if not COMPARTMENT:
    sys.exit("OCI_COMPARTMENT_OCID is required")

auth = ["--auth", "instance_principal"] if AUTH_MODE == "instance_principal" else []


def oci_json(args):
    result = subprocess.run(
        ["oci", *args, *auth, "--output", "json"],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def private_ip(instance_id):
    try:
        payload = oci_json(
            [
                "compute",
                "instance",
                "list-vnics",
                "--instance-id",
                instance_id,
            ]
        )
        data = payload.get("data", [])
        if isinstance(data, list) and data:
            vnic = data[0]
            return vnic.get("private-ip") or vnic.get("private_ip")
        if isinstance(data, dict):
            return data.get("private-ip") or data.get("private_ip")
    except Exception:
        pass
    return None


instances = oci_json(
    [
        "compute",
        "instance",
        "list",
        "--compartment-id",
        COMPARTMENT,
        "--all",
    ]
).get("data", [])

app_hosts = []
for instance in instances:
    if instance.get("lifecycle-state") != "RUNNING":
        continue
    role = (
        instance.get("freeform-tags")
        or instance.get("freeform_tags")
        or {}
    ).get("Role", "")
    if role != "app":
        continue
    ip = private_ip(instance["id"])
    if ip:
        app_hosts.append(f"{ip} ansible_user=deploy hostname={instance['display-name']}")

print("[app]")
for host in app_hosts:
    print(host)
print()
print("[ops]")
print("localhost ansible_connection=local")
print()
print("[all:vars]")
print("ansible_python_interpreter=/usr/bin/python3")
