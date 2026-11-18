# Architecture

## Design intent

The platform demonstrates four things at once:

1. **Infrastructure as code** — every OCI resource is declared in Terraform, with
   modules that have explicit provider constraints and no console-created snowflakes.
2. **Configuration management** — the VM tier is reconciled by Ansible over SSH from
   an in-VCN ops runner; app VMs have no public address.
3. **Container delivery** — the same Go service is built once, pushed to OCIR, and
   deployed to OKE with probes, HPA, PDB, and a NetworkPolicy.
4. **Operability** — secrets in Vault, flow logs, alarms, a bastion, budget alerts,
   and an evidence-capture script that produces a reviewable pack.

## Topology

```text
Region: us-ashburn-1 (iad)
Compartment: <project>-<environment> (optional)

VCN 10.20.0.0/16
├── public   10.20.0.0/24   IGW, load balancer, OKE API endpoint, ops runner
├── app      10.20.10.0/24  private app VMs, OCI Bastion target
├── db       10.20.20.0/24  Autonomous Database private endpoint
└── oke      10.20.30.0/24  OKE worker nodes

Gateways: Internet Gateway (public), NAT Gateway (private egress),
          Service Gateway (OCI services: Object Storage, OCIR, Vault, Monitoring)
```

Prod uses `10.30.0.0/16` with the same subdivision, so the two environments can
exist in one tenancy without overlap.

## Request paths

### VM path

```text
client :80
  → OCI flexible LB (public subnet, NSG lb)
  → app VM :80 (NSG app, source = NSG lb)
  → nginx :80
  → 127.0.0.1:8080 Go service
```

The LB health check is `GET /` on port 80 with return code 200. The Go service
returns 200 on `/`, `/health`, and `/ready`; `/metrics` exposes Prometheus text.

### Container path

```text
client :80
  → OKE service type LoadBalancer (public subnet, OCI cloud provider)
  → platform-api pods :8080 (NSG nodes, intra-VCN)
```

The OKE service is annotated for an OCI flexible LB. Pods pull from OCIR using the
`ocir-secret` docker-registry secret. The deployment runs two replicas with
topology spread, a PDB, and an HPA on CPU.

### Management path

```text
operator workstation
  ├── OCI API (Terraform, CLI) over the internet, API-key signed
  ├── SSH :22 → ops runner (NSG ops, source = admin_cidr)
  │              └── SSH :22 → app VMs (NSG app, source = NSG ops)
  └── OCI Bastion session → app VM :22 (no inbound internet)
```

GitHub Actions authenticates to OCI with a repository secret, runs Terraform, and
optionally deploys to OKE. The Ansible workflow runs on the self-hosted runner
hosted by the ops instance.

## Components and boundaries

### Network

Each subnet has a security list as a coarse boundary and NSGs as the workload
boundary. OCI evaluates security lists and NSGs additively, so the security lists
stay narrow and NSGs carry the specific allows. The public security list still
opens `6443` to `0.0.0.0/0` for the OKE API; the OKE API NSG repeats that rule.
Tightening this to `admin_cidr` is a documented production change, but it breaks
GitHub-hosted runners unless they use a private endpoint or a fixed egress range.

Flow logs are enabled on the VCN and delivered to an OCI Logging log group.

### Identity

- `admins` group: `manage all-resources` in the platform compartment.
- `readers` group: `read all-resources` for auditors.
- `instances` dynamic group: instance principals can read secret bundles, objects,
  metrics, repos, instances, and VNICs. The last two let the ops runner build an
  Ansible inventory without Terraform state.
- The deploying user is separate and is not created by Terraform. It needs
  permission to create the resources in the target compartment.

### Compute

App VMs and the ops runner use the same module with different inputs, on
`VM.Standard.E5.Flex` — the flexible family this tenancy has capacity for. Cloud-init
creates the `deploy` user, installs Python, firewalld, chrony, and basic tooling,
and leaves hardening, Docker, nginx, and the app to Ansible. Ansible re-checks
SELinux and firewalld rather than trusting cloud-init.

On the app tier only, cloud-init also installs nginx and serves a static
`/health`, so the load balancer can gate the tier in the apply pipeline before
Ansible has run. Ansible replaces that placeholder site with the real app.

### Data and secrets

ADB is OLTP on the ECPU compute model (2 ECPUs, 20 GB), private endpoint,
NSG-restricted to app and OKE node subnets on 1521. The ADMIN password is passed as a sensitive variable, written to
Vault as a base64 secret, and is therefore present in Terraform state; protect the
state accordingly.

Object Storage buckets are encrypted with the Vault master key. The evidence
bucket is intended to hold exported documents and, optionally, Terraform state
once the S3-compatible backend is enabled.

### Observability

- ONS email topic with a confirmed subscription.
- Alarms: compute CPU, unhealthy LB backends, ADB storage (when ADB is enabled).
- VCN flow logs and a platform log group.
- Budget: monthly actual-spend thresholds. Add forecast rules if the account
  supports them; the module currently alerts on actuals only.

## Failure modes

| Failure | Detection | Response |
|---|---|---|
| App process dies | LB health check fails, `UnHealthyBackendCount` alarm | `systemctl status platform-api`, `journalctl -u platform-api` |
| Bad deploy | LB returns 502, readiness fails | roll back image tag, rerun Ansible `app-deploy` |
| Ops runner lost | SSH fails, Ansible workflow offline | recreate with Terraform, rerun playbook |
| ADB unavailable | app errors, ADB alarm | check ADB lifecycle state, private endpoint, NSG 1521 |
| OKE node not ready | `kubectl get nodes` NotReady | inspect node pool, NSG, image shape compatibility |
| Secret rotation | app auth failures | update Vault secret version, restart app |
| Credit exhausted | budget alerts, resources stopped | destroy non-essential environments |

## Deliberate limitations

- HTTP-only LB unless `lb_certificate_id` is supplied.
- Public OKE API endpoint.
- Local state in dev; prod has a remote-state example but it is not enabled by
  default.
- Single region and single AD.
- The sample app is intentionally small; the platform is the deliverable.
