# ADR 0001 — Run a VM tier and OKE in one platform

- Status: accepted
- Date: 2026-11-18

## Context

The portfolio needs to demonstrate both configuration management and container
delivery. A single compute plane would force a choice: Ansible on VMs, or
Kubernetes manifests, but not both. The OCI trial credit is finite.

## Decision

Provision both:

- Two private Oracle Linux VMs behind a Terraform-managed OCI load balancer,
  configured by Ansible.
- A basic OKE cluster with a managed node pool, running the same image from OCIR.

They share a VCN, IAM compartment, OCIR repository, Vault, observability, and CI.

## Consequences

Positive:

- One repository shows infrastructure, configuration management, and containers.
- The same `/health` contract is exercised on both planes.
- Failure modes and operating procedures differ, which makes the runbook real.

Negative:

- Roughly doubles the compute cost versus one plane.
- Two ingress paths (Terraform LB and OKE service LB) must be explained.
- More moving parts to tear down.

## Alternatives considered

- **OKE only** — cheaper and simpler, but loses the Ansible/VM story.
- **VM only** — loses Kubernetes, HPA, PDB, and NetworkPolicy evidence.
- **Two repositories** — clearer separation, but weaker as a single platform
  narrative and more CI duplication.
