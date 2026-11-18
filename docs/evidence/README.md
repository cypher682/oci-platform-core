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

| Item | Status |
|---|---|
| Terraform configuration validates | yes |
| `terraform plan` against a real tenancy | pending credentials |
| Apply and live health check | pending credentials |
| OKE workload running | pending credentials |
| Ansible reconciliation | pending apply + ops runner |
| Screenshots | pending apply |
| Destroy and cost cleanup | pending apply |

Update this table as items complete. Do not mark a row complete without the
corresponding file in the folder.
