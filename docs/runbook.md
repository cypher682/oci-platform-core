# Runbook

## 0. First-time setup

1. Collect the values in [credentials.md](credentials.md).
2. Configure the OCI CLI:

```bash
mkdir -p ~/.oci
# paste the config from the console, save the PEM next to it
chmod 600 ~/.oci/config ~/.oci/oci_api_key.pem
oci iam region list
```

3. Create the tfvars file:

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
# edit OCIDs, admin_cidr, ssh_public_key, alert_email
export TF_VAR_db_admin_password='...'
```

4. Verify:

```bash
../../scripts/preflight.sh
terraform init
terraform validate
terraform plan -out=tfplan
```

## 1. Apply

```bash
terraform apply tfplan
```

Expected order: IAM → network → Vault → buckets → compute → LB → OCIR → OKE →
ADB → observability → bastion → budget. OKE and ADB take the longest.

Capture the outputs:

```bash
terraform output
terraform output -raw health_url
terraform output -raw ops_runner_public_ip
terraform output -raw ocir_image
```

Confirm the ONS email subscription. Until it is confirmed, alarms have no
recipient.

## 2. Access the ops runner

```bash
ssh -i ~/.ssh/oci_platform deploy@$(terraform output -raw ops_runner_public_ip)
```

The ops runner is the only host with public SSH. It can reach the private app VMs
on 22 because its NSG is the source in the app NSG rule.

From the runner:

```bash
cd ~/oci-platform-core/ansible
ansible-playbook site.yml -i inventory/hosts.ini
```

If the repository is not on the runner yet, clone it there. The inventory must
list private app IPs; `make inventory` on the workstation writes the file, and
`scripts/oci-inventory.sh` builds it from OCI tags on the runner.

## 3. Deploy the application to the VM tier

The `app-deploy` role pulls the OCIR image and runs it on `127.0.0.1:8080`.
Prerequisites on the runner/targets: `OCIR_REGISTRY`, `OCIR_USERNAME`,
`OCIR_AUTH_TOKEN`, `OCIR_IMAGE` available as environment variables or extra vars.

```bash
ansible-playbook site.yml -i inventory/hosts.ini --tags app
```

Nginx proxies port 80 to 8080. The LB checks port 80.

## 4. Deploy to OKE

```bash
make kubeconfig
KUBECONFIG=~/.kube/config-oci-platform kubectl get nodes
```

Build and push:

```bash
export OCIR_USERNAME='<namespace>/<email>'
export OCIR_AUTH_TOKEN='...'
export IMAGE="$(terraform -chdir=environments/dev output -raw ocir_image)"
make ocir-login
make build-push
```

Deploy:

```bash
make deploy-k8s IMAGE="$IMAGE"
KUBECONFIG=~/.kube/config-oci-platform kubectl -n platform get pods,svc
```

The service is type LoadBalancer; OCI provisions a second load balancer. Wait for
`EXTERNAL-IP`, then `curl http://<ip>/health`.

## 5. Evidence

```bash
make evidence ENV=dev
```

This writes text evidence under `docs/evidence/<timestamp>/`. Add console
screenshots using the checklist in [evidence/README.md](evidence/README.md).
Do not capture secret values; capture secret metadata only.

## 6. Remote state

The pipeline stores state in OCI Object Storage. OCI is S3-compatible, so the
Terraform backend is named `s3` and the environment variables are `AWS_*`; the
credentials are OCI Customer Secret Keys. This is not an AWS dependency.

One-time bootstrap:

```bash
export OCI_COMPARTMENT_OCID='ocid1.compartment...'
export OCI_CLI_USER='ocid1.user...'
bash scripts/bootstrap-state.sh
```

Copy the four printed values into GitHub repository secrets (`OCI_NAMESPACE`,
`OCI_TFSTATE_BUCKET`, `OCI_S3_ACCESS_KEY`, `OCI_S3_SECRET_KEY`). The workflows run
`scripts/ci-backend.sh`, which writes a gitignored `backend.tf` in the environment
directory and runs `terraform init -reconfigure`.

For local remote state, copy the relevant `backend.tf.example` and run
`terraform init -migrate-state`.

The backend needs `skip_region_validation`, `skip_credentials_validation`,
`skip_metadata_api_check`, `skip_requesting_account_id`, `skip_s3_checksum`, and
`force_path_style`. Endpoint:
`https://<namespace>.compat.objectstorage.<region>.oraclecloud.com`.

## 7. Rotate credentials

### OCI API key

1. Add a second API key in the console.
2. Update `~/.oci/config` and the GitHub secret `OCI_CLI_KEY_CONTENT`.
3. Run `terraform plan` to prove the new key works.
4. Delete the old key.

### OCIR auth token

1. Generate a new token.
2. Update `OCIR_AUTH_TOKEN` in GitHub and on the ops runner.
3. Update the `ocir-secret` in the `platform` namespace.
4. Revoke the old token.

### ADB password

1. Change the password in OCI (or via `oci db autonomous-database update`).
2. Update `TF_VAR_db_admin_password` in the secret store and GitHub.
3. Create a new Vault secret version (`terraform apply` with the new value).
4. Restart consumers.

## 8. Teardown

```bash
make destroy ENV=dev
```

The target prompts for `destroy-dev`. Order is handled by Terraform dependencies:
OKE node pool and cluster, LB, compute, ADB, Vault secret and key, buckets, VCN.
Vault deletion can be slow; wait for it to finish before deleting the vault.

If a bucket is non-empty, Terraform fails. Empty it first or set the lifecycle
policy; do not add `force_destroy` to production buckets.

## 9. Troubleshooting

| Symptom | Check | Fix |
|---|---|---|
| `terraform init` hangs downloading `oracle/oci` | registry connectivity/proxy | retry; or use a local plugin cache with `-plugin-dir` |
| `401`/`404` from OCI | config fingerprint, key path, region | `oci iam region list`; recheck `~/.oci/config` |
| `NotAuthorizedOrNotFound` | compartment OCID or policy | verify compartment and `manage all-resources` scope |
| App VM unreachable from ops | NSG app allows source NSG ops on 22; SSH key | check NSGs, `ssh -vvv` |
| LB 502 | nginx/app on 80/8080, app health | `curl 127.0.0.1/health` on the VM |
| OKE node `NotReady` | node pool shape vs image arch, NSG, subnet route | use an x86 E5 shape from the cluster's node option list; check node logs |
| ADB create fails | OCPU model rejected, or below the 2 ECPU / 20 GB minimum | set `compute_model = "ECPU"`, or `enable_adb=false` |
| `400-LimitExceeded` on instances | the shape has no quota (`standard-e4-core-count` is 0 in this tenancy) | use `VM.Standard.E5.Flex` or `VM.Standard.A1.Flex` |
| `404-NotAuthorizedOrFoundKmsKey` on buckets | the Object Storage KMS policy is still propagating | re-run the apply; check the `objectstorage-<region>` policy statement |
| `ocir-secret` pull errors | token, username format | `namespace/email`; re-create secret |
| Budget alarm fires immediately | existing spend in compartment | raise `budget_amount` or scope budget to a new compartment |

## 10. Provider lock file

The lock file is intentionally not committed. It was generated on Windows against
a local plugin cache, and a lock with only `windows_amd64` checksums makes Linux CI
fail. Each environment generates its own lock on first `terraform init`.

For a reproducible production pipeline, run this on a machine with normal registry
access and commit the result:

```bash
terraform providers lock -platform=linux_amd64 -platform=windows_amd64
```

Then remove `.terraform.lock.hcl` from `.gitignore`.

## 11. Useful commands

```bash
terraform -chdir=environments/dev state list
terraform -chdir=environments/dev output -json
oci compute instance list --compartment-id "$CID" --output table
oci lb backend-health get --load-balancer-id "$LB" --backend-set-name app-backend-set --backend-name "$IP:80"
kubectl -n platform logs deploy/platform-api --tail=100
kubectl -n platform describe hpa platform-api
```
