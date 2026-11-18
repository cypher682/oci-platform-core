# F5 — OCI Platform Core sprint brief

## Objective

Ship a public, evidence-backed OCI platform repository that demonstrates Terraform,
Ansible, OKE, Vault, ADB, observability, and CI/CD — not a tutorial clone. It should
read like a platform an engineer could operate, with explicit risks and a teardown
path.

## Constraints

- OCI trial credit: **$200**, expiring today. The full stack costs roughly $5/day;
  hours matter, not weeks.
- Existing instance from `oracle-server-info.txt`: Oracle Linux 9.8, arm64,
  `VM.Standard.A4.Flex`, 4 OCPU / 28 GB, `us-ashburn-1`, public `141.148.69.94`.
  It is **not** reused by this stack; Terraform builds a new VCN. Reusing it would
  require importing it and reconciling its network, which is not worth the sprint
  time.
- No OCI API key, tenancy OCID, compartment OCID, namespace, or OCIR token is
  available yet. This is the hard gate.

## Credential gate

Read [docs/credentials.md](docs/credentials.md). Minimum to start:

1. Tenancy OCID.
2. User OCID + API key fingerprint + PEM.
3. Compartment OCID.
4. `admin_cidr` (your public IP `/32`).
5. SSH key pair.
6. ADB password and alert email.
7. OCIR username and auth token (can be created during the sprint).
8. State bucket + Customer Secret Key (`scripts/bootstrap-state.sh`).

Verify with:

```bash
make preflight
```

## What exists now

- 12 Terraform modules with pinned provider constraints and `versions.tf`:
  IAM, network, compute, load balancer, OKE, OCIR, ADB, Object Storage, Vault,
  observability, bastion, budget.
- Dev and prod root modules. Dev uses `10.20.0.0/16`; prod uses `10.30.0.0/16`.
- Cloud-init bootstrap and eight Ansible roles for the VM tier and ops runner.
- Go service, scratch image, Kubernetes manifests with HPA/PDB/NetworkPolicy.
- Five GitHub Actions workflows, an OCI auth composite action, Makefile, preflight,
  inventory, smoke, and evidence scripts.
- Architecture, credentials, security, cost, runbook, evidence checklist, and three
  ADRs.
- `terraform validate` passes for dev. No plan or apply has run.

## What is not proven yet

- Plan against a real tenancy.
- Live load balancer health check.
- OKE node pool and workload.
- ADB creation (free-tier availability is tenancy-dependent).
- Ansible run against the ops runner.
- Screenshots and destroy evidence.

The evidence table in [docs/evidence/README.md](docs/evidence/README.md) tracks
these honestly. Do not mark them complete without files.

## 90-minute execution plan

| Time | Step | Output |
|---|---|---|
| 0–10 | Collect credentials, bootstrap state bucket, add GitHub secrets | Green preflight + bucket |
| 10–25 | Run **Terraform Plan** workflow, review counts | Plan screenshot 03 |
| 25–45 | Run **Terraform Apply** workflow | VCN, instances, LB, OKE, ADB, Vault |
| 45–55 | One-time runner bootstrap, then **Ansible Configuration** workflow | Play recap screenshot 16 |
| 55–65 | Build/push image, `make deploy-k8s`, `make smoke` | Health JSON, pods |
| 65–75 | `make evidence`, console screenshots 04–14 | Evidence folder |
| 75–85 | Push repo, trigger plan/apply workflows | Actions screenshot 15 |
| 85–90 | `make destroy`, confirm cleanup | Destroy screenshot 17 |

If ADB free tier is unavailable, set `enable_adb=false` and keep the Vault secret
story; note the limitation in evidence. If time runs short, drop OKE
(`enable_oke=false`) before dropping the VM tier, and say so.

## Deliverables

- Public repo `cypher682/oci-platform-core`.
- Green Terraform validate and plan.
- Live `/health` response from the OCI LB.
- OKE workload evidence.
- Ansible run evidence.
- Architecture, runbook, credentials, security, cost, ADRs.
- Destroy evidence and an honest cost note.

## Acceptance criteria

- [ ] `terraform validate` passes in `environments/dev` and `environments/prod`.
- [ ] `make preflight` catches every missing credential with a clear message.
- [ ] `terraform apply` completes without console-created resources.
- [ ] The LB health check returns 200 and the app responds through the LB.
- [ ] OKE pods are Running and the service has an external IP.
- [ ] OCI Bastion or ops-runner SSH reaches a private app VM.
- [ ] Vault secret metadata exists; no secret value is in git.
- [ ] Alarms and budget exist and the ONS email is confirmed.
- [ ] Evidence folder contains machine output and screenshots.
- [ ] `make destroy` removes the stack; billing shows no stray block volumes.
- [ ] README, credentials, and runbook match what was actually done.

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Credit expires before apply | No live evidence | Apply the smallest useful stack first; capture health early |
| OKE node shape/image mismatch | Node pool fails | Use an x86 E5 shape; the node image list offers only E5 here, and A1 needs an arm64 image |
| Shape quota is zero | `400-LimitExceeded` on every instance | This tenancy has no E4 capacity; use `VM.Standard.E5.Flex` |
| ADB compute model rejected | Apply fails | New ADBs must use ECPU (2 ECPUs / 20 GB); `enable_adb=false` to skip |
| LB 502 | No health evidence | Check nginx and app on the VM; verify NSG allows LB NSG |
| Ops runner unreachable | No Ansible | Verify `admin_cidr`, NSG, and key; use Bastion as fallback |
| Public OKE API | Security finding | Documented residual risk with production fix |
| Local state loss | Rework | Copy state to the evidence bucket; enable remote backend for prod |

## Rollback

`make destroy ENV=dev` is the rollback. If Terraform is interrupted, re-run
`terraform plan` and reconcile; do not delete resources by hand unless a bucket or
Vault is blocking deletion, and record what was deleted manually.
