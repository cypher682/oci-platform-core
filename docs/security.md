# Security posture

## Controls implemented

| Area | Control |
|---|---|
| Identity | Separate admin/reader groups; compartment-scoped policies; no shared human account in code |
| Workload identity | Instance principals for Vault, Object Storage, Monitoring, OCIR, and inventory reads |
| Network | Private app/db/OKE subnets; no public IP on app VMs; NSG-to-NSG allows; SSH only from `admin_cidr` to the ops runner |
| Ingress | LB exposes 80 and optional 443; backend accepts HTTP only from the LB NSG |
| Data | ADB private endpoint on 1521 from app/OKE NSGs only; buckets encrypted with a Vault key |
| Secrets | ADB password in Vault; API keys and OCIR tokens are environment/GitHub secrets; no secrets in git |
| Host | SELinux enforcing, firewalld, fail2ban, unattended security updates, journal limits |
| Containers | Non-root UID 65532, read-only root filesystem, no privilege escalation, all capabilities dropped, seccomp RuntimeDefault |
| Kubernetes | Dedicated namespace, service account with no token automount, NetworkPolicy, PDB, resource limits, probes |
| Supply chain | Minimal scratch image, pinned Go version, CI builds from source, no long-lived registry password in manifests |
| Cost safety | Budget alerts at multiple actual-spend thresholds |
| Audit | VCN flow logs, OCI Audit (tenant-level), evidence bundle |

## Residual risks

These are known and deliberate for a portfolio sprint. Each has a production fix.

### 1. Public Kubernetes API endpoint

`6443` is open to `0.0.0.0/0`. Authentication is still required, but the endpoint
is internet-reachable. Production fix: private API endpoint plus a bastion or VPN,
or restrict the NSG to fixed CI egress ranges.

### 2. HTTP-only load balancer

Without `lb_certificate_id`, traffic to the VM tier is plaintext. Production fix:
issue an OCI Certificates certificate, pass its OCID, and redirect 80 to 443.

### 3. Local Terraform state in dev

State contains resource IDs and the ADB password (through the Vault secret
content). It is gitignored but lives on the workstation. Production fix: enable the
S3-compatible Object Storage backend, restrict the bucket, enable versioning, and
use a dedicated state compartment.

### 4. Software-protected Vault key

`protection_mode = "SOFTWARE"` is used to keep the sprint cheap. Production fix:
HSM-protected key and a break-glass procedure.

### 5. Broad egress from private subnets

App, OKE, and DB egress is `0.0.0.0/0` through NAT/service gateway. Production fix:
allow only OCI service CIDRs, OCIR, and required update endpoints; add an egress
firewall or OCI Network Firewall.

### 6. SSH trust chain

The ops runner holds the private key for every app VM. Compromise of the runner
compromises the tier. Production fix: short-lived SSH certificates, OCI Bastion
only, and no long-lived key on the runner.

### 7. GitHub Actions use tag-pinned actions

Actions are referenced by major version tags (`@v4`), not commit SHAs. Production
fix: pin every action to a SHA and enable Dependabot for updates.

### 8. Sample app has no authentication

The Go service exposes `/`, `/health`, `/ready`, and `/metrics` without auth.
Production fix: terminate auth at the LB or an API gateway; keep `/metrics` on a
private listener.

### 9. No WAF or DDoS posture beyond OCI defaults

Production fix: add a WAF policy in front of the LB and rate limiting at the edge.

## Secret handling rules

- `terraform.tfvars` is gitignored; only `.example` files are committed.
- `TF_VAR_db_admin_password` is exported in the shell or injected by CI.
- `OCI_CLI_KEY_CONTENT`, `OCI_SSH_PRIVATE_KEY`, `OCIR_AUTH_TOKEN`, and
  `DB_ADMIN_PASSWORD` are GitHub secrets; they are never echoed.
- Evidence capture lists secret metadata, never `secret_content`.
- The state file and plan files are gitignored.
- Rotate the API key and OCIR token after the sprint.

## Verification commands

```bash
tflint --recursive
checkov -d . --framework terraform
terraform -chdir=environments/dev validate
git secrets --scan 2>/dev/null || true
```

Checkov is configured with `soft_fail: true` in CI so a new OCI policy does not
block a plan. Read its findings; do not treat the green check as proof.
