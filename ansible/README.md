# Ansible

The playbook configures the ops runner and the private app VMs. Run it **on the
ops runner**, not from a laptop, unless you have a network path to the private
subnet.

## Install

```bash
python3 -m pip install --user "ansible-core>=2.16" docker
ansible-galaxy collection install -r requirements.yml
```

`community.docker` needs the Docker SDK for Python (`docker`), which is why it is
installed alongside Ansible.

## Inventory

Static example:

```bash
cp inventory/hosts.ini.example inventory/hosts.ini
```

Generate from OCI tags (requires `OCI_COMPARTMENT_OCID` and either a local API key
or instance principal):

```bash
OCI_AUTH_MODE=instance_principal ../scripts/oci-inventory.sh inventory/hosts.ini
```

The script selects running instances tagged `Role=app` and resolves their private
IPs. It never needs Terraform state.

## Run

```bash
ansible-playbook site.yml -i inventory/hosts.ini --syntax-check
ansible-playbook site.yml -i inventory/hosts.ini
```

Useful tags: `common`, `hardening`, `docker`, `nginx`, `app`, `oci-agent`,
`k8s-tools`, `gh-runner`.

## Roles

| Role | Target | Purpose |
|---|---|---|
| `common` | all | Packages, timezone, chrony, journal limits, `/etc/motd` |
| `hardening` | all | SELinux check, firewalld, fail2ban, sysctl, SSH posture |
| `docker` | app | Docker Engine from the OL9 repository, daemon limits |
| `nginx` | app | Reverse proxy on 80 to 127.0.0.1:8080 |
| `app-deploy` | app | OCIR login, pull, systemd unit, restart |
| `oci-agent` | all | Oracle Cloud Agent, required for Bastion sessions |
| `k8s-tools` | ops | kubectl, helm, kustomize |
| `gh-runner` | ops | Self-hosted GitHub Actions runner |

## Variables

Set in `group_vars/all.yml` or as environment variables consumed by the playbook:

- `OCIR_REGISTRY`, `OCIR_USERNAME`, `OCIR_AUTH_TOKEN`, `OCIR_IMAGE`
- `ADMIN_CIDR` for firewalld rich rules
- `GH_RUNNER_TOKEN`, `GH_RUNNER_REPO` (or `GH_RUNNER_ORG`) for the runner role

Do not commit real values. The GitHub workflow injects them as secrets.

## Safety

The playbook is idempotent. It refuses to run against a host that has not finished
cloud-init (marker `/var/log/platform-cloud-init.done`). It does not reboot hosts
automatically; kernel changes are applied on the next maintenance window.
