# Evidence pack

The claim is not "I wrote Terraform." The claim is "this platform ran, here is the
proof, and here is how it was operated." Capture both machine output and console
screenshots.

## Automated capture

```bash
make evidence ENV=dev
```

Creates `docs/evidence/<UTC timestamp>/` with:

| File | What it proves |
|---|---|
| `terraform-outputs.json` | Resource IDs, IPs, endpoints, image path |
| `evidence-bundle.json` | Compact machine-readable summary |
| `compute-instances.txt` | Instances exist in the expected lifecycle state |
| `vncs.txt`, `subnets.txt` | Network was built by Terraform |
| `load-balancers.txt` | LB exists and is attached to the public subnet |
| `oke-clusters.txt` | OKE cluster exists |
| `autonomous-databases.txt` | ADB exists with a private endpoint |
| `ocir.txt` | Private repository exists |
| `vault-secrets.txt` | Secret metadata exists (never the value) |
| `alarms.txt`, `ons-topics.txt` | Alerting is configured |
| `bastions.txt` | Managed SSH entry point exists |
| `health.json` | The live LB answered the health check |
| `k8s-nodes.txt`, `k8s-workloads.txt` | OKE nodes and workload are healthy |
| `tooling.txt` | Terraform/OCI/kubectl/Ansible versions |

## Screenshot checklist

Save screenshots in the same timestamped folder using these names.

| # | File | Capture |
|---|---|---|
| 01 | `01-repo-tree.png` | `tree -L 2` or the GitHub repository file list |
| 02 | `02-terraform-validate.png` | `terraform validate` success |
| 03 | `03-terraform-plan.png` | Plan summary: `Plan: N to add, 0 to change, 0 to destroy` |
| 04 | `04-oci-compartment.png` | Compartment and VCN in the console |
| 05 | `05-subnets-nsgs.png` | Four subnets and NSG list |
| 06 | `06-instances.png` | App VMs (no public IP) and ops runner |
| 07 | `07-lb-backends.png` | LB backend set with both backends healthy |
| 08 | `08-health-curl.png` | `curl <health_url>` returning JSON |
| 09 | `09-oke-cluster.png` | OKE cluster and node pool active |
| 10 | `10-kubectl-pods.png` | `kubectl -n platform get pods,svc` with external IP |
| 11 | `11-adb.png` | ADB active, private endpoint, free tier |
| 12 | `12-vault.png` | Vault key and secret metadata, value hidden |
| 13 | `13-alarms.png` | ONS topic and alarm list |
| 14 | `14-budget.png` | Budget and alert rules |
| 15 | `15-github-actions.png` | Green plan/apply workflow run |
| 16 | `16-ansible-run.png` | Play recap with `failed=0` |
| 17 | `17-destroy.png` | `Destroy complete` (cleanup proof) |

## Rules

- Never screenshot a secret value, private key, auth token, or full `.oci/config`.
- Blur tenancy and user OCIDs if the repository is public. Resource OCIDs are not
  credentials, but they are identifiers; decide deliberately.
- Timestamp everything. A screenshot without a date is weak evidence.
- Keep the raw Terraform plan output for the applied change, not only the summary.
- Record the commit SHA in the evidence folder README (the script does this in
  `tooling.txt`).

## Current status

| Item | Status | Verification Detail |
|---|---|---|
| Terraform configuration validates | **Verified** | `terraform validate` passed in CI and local preflight |
| `terraform plan` against a real tenancy | **Verified** | Workflow run `44304735130` created plan in `us-ashburn-1` |
| Apply and live health check | **Verified Live** | `curl http://193.122.169.180/health` returns `200 OK` |
| Round-robin load balancing | **Verified Live** | Alternates between `10.20.10.161` and `10.20.10.254` |
| Ansible reconciliation & OS hardening | **Verified Live** | Play recap `failed=0`; SELinux Enforcing, fail2ban active, auditd rules applied |
| In-VCN self-hosted GitHub Actions runner | **Verified Live** | Runner `oci-platform-runner-01` active with OCI Instance Principal auth |
| Container build & OCIR delivery | **Verified Live** | Go microservice pulled from `iad.ocir.io/iddabu9qjxp9/platform-api:latest` |
| Prometheus telemetry exported | **Verified Live** | `/metrics` exports request counters and uptime gauges |
| OKE & Autonomous Database | **Scoped** | Manifests & Terraform modularized; compute sprint prioritized for credit window |
| Destroy and cost cleanup | **Ready** | `make destroy ENV=dev` executable at end of demonstration window |

## Live Verification Transcript (2026-11-18)

### 1. Load Balancer Live Response
```bash
$ curl -i http://193.122.169.180/health
HTTP/1.1 200 OK
Date: Wed, 18 Nov 2026 15:00:50 GMT
Content-Type: application/json
Content-Length: 122
Connection: keep-alive
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: no-referrer
Content-Security-Policy: default-src 'none'; frame-ancestors 'none'

{"status":"ok","service":"oci-platform-core","version":"aacaf19","hostname":"75d01cc7017c","time":"2026-11-18T15:00:50Z"}
```

### 2. Microservice Runtime & Telemetry
```bash
$ curl -s http://193.122.169.180/version
{"description":"OCI platform core sample workload","endpoints":["/health","/ready","/metrics"],"runtime":"go1.23.12","service":"oci-platform-core","version":"aacaf19"}

$ curl -s http://193.122.169.180/metrics
# HELP platform_http_requests_total Total HTTP requests handled
# TYPE platform_http_requests_total counter
platform_http_requests_total 39
# HELP platform_uptime_seconds Seconds since process start
# TYPE platform_uptime_seconds gauge
platform_uptime_seconds 1739
# HELP platform_build_info Build metadata
# TYPE platform_build_info gauge
platform_build_info{version="aacaf19",go="go1.23.12"} 1
```

### 3. Backend Instance Fleet
- **`app-1` (10.20.10.161):** Private Subnet, Oracle Linux 9.8 UEK kernel, Nginx proxy + non-root Go container.
- **`app-2` (10.20.10.254):** Private Subnet, Oracle Linux 9.8 UEK kernel, Nginx proxy + non-root Go container.
- **`ops-1` (143.47.120.250):** Public Subnet, self-hosted runner `oci-platform-runner-01` with Instance Principal IAM.

Update this table as items complete. Do not mark a row complete without the
corresponding file in the folder.
