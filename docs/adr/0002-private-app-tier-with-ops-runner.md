# ADR 0002 — Private app tier, public ops runner

- Status: accepted
- Date: 2026-11-18

## Context

App VMs should not have public IPs. Ansible still needs SSH access to configure
them, and GitHub-hosted runners cannot reach a private VCN without additional
networking.

## Decision

Place app VMs in a private subnet with no public IP and no NAT ingress. Place one
small ops runner in the public subnet, reachable on 22 only from `admin_cidr`.
The app NSG accepts SSH only from the ops NSG. The ops runner is also the
self-hosted GitHub Actions runner for the Ansible workflow.

## Consequences

Positive:

- The app tier has no inbound internet path.
- Ansible has a stable execution point inside the VCN.
- CI can run Ansible without exposing the VCN.

Negative:

- The ops runner is a single point of failure and holds the app SSH key.
- It costs another instance.
- It must be patched and monitored like production.

## Alternatives considered

- **Public app VMs with `admin_cidr` SSH** — simpler, but weakens the network
  story and exposes every app host.
- **OCI Bastion for Ansible** — sessions are interactive and short-lived; not a
  good fit for unattended playbooks across multiple hosts.
- **GitHub-hosted runner + VPN** — more production-grade, more setup than a
  sprint allows.
