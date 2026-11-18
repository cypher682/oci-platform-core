# oci-platform-core

Production-shaped Oracle Cloud Infrastructure platform built with Terraform and Ansible:
a private VM tier behind an OCI load balancer, an OKE cluster, Autonomous Database,
Vault-managed secrets, encrypted Object Storage, monitoring, a bastion, budget
guardrails, and GitHub Actions delivery.

The repository is a working platform, not a diagram. Everything below is expressed
as code and validated with `terraform validate`; the deployment status is tracked
in [docs/evidence/README.md](docs/evidence/README.md).

## What is in the stack

| Layer | Resources | Code |
|---|---|---|
| Identity | Compartment, admin/reader groups, scoped policies, instance-principal dynamic group | `modules/iam` |
| Network | VCN `10.20.0.0/16`, public/app/db/OKE subnets, NSGs, flow logs | `modules/network` |
| Compute | 2 private app VMs + 1 public ops runner, OL9 cloud-init bootstrap | `modules/compute` |
| Ingress | Flexible OCI load balancer, HTTP health checks, optional TLS certificate | `modules/loadbalancer` |
| Containers | Basic OKE cluster + managed node pool, private worker subnet | `modules/oke` |
| Registry | Private OCIR repository | `modules/ocir` |
| Data | Always-free Autonomous Database, private endpoint | `modules/database` |
| Secrets | Vault key + database secret bundle | `modules/vault` |
| Storage | Encrypted evidence and state buckets | `modules/objectstorage` |
| Operations | ONS topic, CPU/DB alarms, OCI Bastion, budget + forecast alarms | `modules/observability`, `modules/bastion`, `modules/budget` |
| Configuration | Hardening, Docker, nginx, app deploy, OCI agent, self-hosted runner | `ansible/roles` |
| Delivery | Plan, apply, destroy, app build/deploy, Ansible workflows | `.github/workflows` |

## Architecture

```text
                          Internet
                             │
                    ┌────────┴────────┐
                    │  OCI Load       │  public subnet 10.20.0.0/24
                    │  Balancer :80   │
                    └────────┬────────┘
                             │ health check /
              ┌──────────────┴──────────────┐
              │                             │
     ┌────────┴────────┐          ┌─────────┴───────┐
     │ app VM 1        │          │ app VM 2        │  app subnet 10.20.10.0/24
     │ nginx + Go app  │          │ nginx + Go app  │  no public IP
     └────────┬────────┘          └─────────┬───────┘
              └──────────────┬──────────────┘
                             │
                    ┌────────┴─────────┐
                    │ Autonomous DB    │  db subnet 10.20.20.0/24
                    │ private endpoint │
                    └──────────────────┘

  ops runner (public subnet, admin CIDR only) ── Ansible/SSH ──► app VMs
  GitHub Actions ── OCI API ──► Terraform, OCIR, OKE
  OKE workers ── private subnet 10.20.30.0/24 ──► OCIR pull, OCI LB service
```

Two compute planes are deliberate: the VM tier proves configuration management and
traditional operations; OKE proves container delivery. Both consume the same image
from OCIR and expose the same `/health` contract.

## Deploy from the pipeline

The primary path is GitHub Actions, not a local workstation. One-time setup:

```bash
bash scripts/bootstrap-state.sh   # creates the OCI state bucket + S3-compatible key
```

Then add the repository secrets listed in [docs/credentials.md](docs/credentials.md)
and:

1. **Actions → Terraform Plan** — validates, lints, scans, and plans on a PR or
   manual run.
2. **Actions → Terraform Apply** — choose `dev`, type `APPLY`. Terraform creates
   the stack, deploys the workload to OKE, and smoke-tests the VM load balancer.
3. **Actions → Ansible Configuration** — runs on the self-hosted ops runner and
   reconciles the app VMs.
4. **Actions → Build and Deploy Application** — builds the Go image, pushes to
   OCIR, and rolls out the new tag.

The workflows authenticate by writing `~/.oci/config` from secrets; no credential
is committed and no local OCI CLI profile is required.

Local commands remain available for validation and debugging:

```bash
make preflight      # checks the DB password + OCI auth; optional vars are skipped
make init
make validate
make plan           # needs terraform.tfvars or TF_VAR_* exports
```

Ansible runs **on the ops runner**, because the app VMs have no public IP:

```bash
ssh -i ~/.ssh/oci_platform deploy@$(terraform -chdir=environments/dev output -raw ops_runner_public_ip)
cd oci-platform-core/ansible
ansible-playbook site.yml -i inventory/hosts.ini
```

The ops runner is the intended host for the self-hosted GitHub Actions runner
(`ansible/roles/gh-runner`), which is why the Ansible workflow targets
`[self-hosted, linux, x64, oci-platform]`.

## Repository layout

```text
environments/dev|prod     Root modules, tfvars examples, backend example
modules/                  Twelve Terraform modules, each with versions.tf
ansible/                  Playbook, roles, static and OCI dynamic inventory
app/                      Go service, scratch Docker image, unit tests via HTTP
k8s/                      Namespace, deployment, service, HPA, PDB, NetworkPolicy
scripts/                  Preflight, inventory, smoke test, evidence capture
.github/                  OCI auth action and five delivery workflows
docs/                     Architecture, credentials, security, cost, runbook, ADRs
```

## Delivery model

- `tf-plan.yml` — format, validate, TFLint, Checkov, plan, PR comment.
- `tf-apply.yml` — manual, environment-gated apply; deploys the workload to OKE and
  smoke-tests the VM load balancer.
- `app-build-push.yml` — builds the Go image, pushes to OCIR, rolls out to OKE.
- `ansible.yml` — runs on the self-hosted ops runner and reconciles the VM tier.
- `destroy.yml` — manual teardown with a typed confirmation.

No credential is stored in the repository. CI writes `~/.oci/config` from GitHub
secrets in a composite action, and Terraform reads it the same way as a laptop.

## Cost and teardown

The stack is sized for a short portfolio sprint on a trial credit, not for an
always-on production budget. Load balancer hours, OKE worker hours, and block
volumes dominate the bill; ADB is on the always-free shape. See
[docs/cost.md](docs/cost.md) for the line items and the budget guardrail.

```bash
make destroy ENV=dev
```

Destroy the stack when evidence is captured. A running OKE node pool and load
balancer will consume credit continuously.

## Documentation

- [Pipeline setup — where every value comes from](docs/pipeline-setup.md)
- [Credentials you must supply](docs/credentials.md)
- [Architecture and failure modes](docs/architecture.md)
- [Runbook](docs/runbook.md)
- [Security posture and residual risk](docs/security.md)
- [Cost model](docs/cost.md)
- [Evidence checklist](docs/evidence/README.md)
- [ADRs](docs/adr/)
