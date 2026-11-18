# Credentials and values you must supply

`oracle-server-info.txt` describes a running instance. It does **not** contain the
credentials Terraform needs. This page is the complete list, in the order to collect
them.

If you only do one thing: create the API key, capture the tenancy OCID, and run
`make preflight` until it is green.

---

## 1. Tenancy OCID

Console → profile menu → **Tenancy: <name>** → copy **OCID**.

Format: `ocid1.tenancy.oc1..aaaa...`

This is both `tenancy_ocid` and, for a personal tenancy, a valid
`compartment_ocid`.

## 2. User OCID and API signing key

Console → profile menu → **My profile** → **API keys** → **Add API key** →
**Generate API key pair** → download the private key → **Add**.

Copy:

- **User OCID**: `ocid1.user.oc1..aaaa...`
- **Fingerprint**: `aa:bb:cc:...`
- **Private key**: `oci_api_key.pem` (downloaded once; OCI cannot show it again)
- **Region identifier**: `us-ashburn-1` (from the region selector; the short key is `iad`)

The config preview should look like:

```ini
[DEFAULT]
user=ocid1.user.oc1..aaaa...
fingerprint=aa:bb:cc:dd:...
tenancy=ocid1.tenancy.oc1..aaaa...
region=us-ashburn-1
key_file=~/.oci/oci_api_key.pem
```

Store it at `~/.oci/config`, `chmod 600` both files. Do not put this file in the
repository; `.oci/` is gitignored.

If you use a session token instead of an API key, the values are the same but the
token expires; CI should use an API key.

## 3. Compartment OCID

Console → **Identity & Security** → **Compartments**.

- `create_compartments = false`: use the compartment where resources should live
  (the tenancy OCID is valid for the root compartment).
- `create_compartments = true`: use the **parent** compartment; Terraform creates
  `<project>-<environment>` beneath it.

Format: `ocid1.compartment.oc1..aaaa...`

## 4. Object Storage namespace

Console → **Storage** → **Object Storage** → **Buckets**; the namespace is shown in
the page header. Or, once the CLI is configured:

```bash
oci os ns get
```

You do not pass this to Terraform (it is read by a data source), but OCIR login and
the S3 backend need it.

## 5. SSH key pair

Terraform injects the **public** key into the app VMs and ops runner.

```bash
ssh-keygen -t ed25519 -C "oci-platform-core" -f ~/.ssh/oci_platform
```

- `ssh_public_key` / `OCI_SSH_PUBLIC_KEY`: contents of `~/.ssh/oci_platform.pub`
- `OCI_SSH_PRIVATE_KEY`: contents of `~/.ssh/oci_platform` (GitHub secret only)

The existing instance in `oracle-server-info.txt` has its own `authorized_keys`.
It is not reused by this stack; Terraform builds a new VCN and new instances.

## 6. Autonomous Database ADMIN password

Used as `TF_VAR_db_admin_password`. ADB requires 12–30 characters, at least one
uppercase, one lowercase, and one number; it must not contain the username `admin`.

Generate one and keep it in a password manager:

```bash
openssl rand -base64 24
```

The value is also written to OCI Vault by `modules/vault`; do not place it in
`terraform.tfvars`.

## 7. Alert email

`alert_email` receives ONS subscription confirmation, CPU/DB alarms, and budget
alerts. Confirm the ONS subscription email after the first apply or no alerts are
delivered.

## 8. OCIR username and auth token

Console → **Identity & Security** → **Users** → your user → **Auth tokens** →
**Generate token**.

- `OCIR_USERNAME`: `<namespace>/<email>` (for example
  `axxxxxxxxxxx/you@example.com`)
- `OCIR_AUTH_TOKEN`: the generated token (shown once)
- `OCIR_IMAGE`: `iad.ocir.io/<namespace>/platform-api` after the first apply; the
  Terraform output `ocir_image` prints the exact value
- `OCI_OKE_CLUSTER_ID`: Terraform output `oke_cluster_id` (optional; the app
  workflow skips deployment when it is empty)

Docker login uses the token, not your console password.

## 9. Operator CIDR

`admin_cidr` limits SSH to the ops runner and the Bastion. Get your current public
IP:

```bash
curl -s https://ifconfig.me
```

Use `<ip>/32`. Do not use `0.0.0.0/0`; the security model assumes this value is
narrow.

## 10. Terraform state bucket and S3-compatible key

The pipeline stores state in OCI Object Storage. OCI exposes an S3-compatible
endpoint, so Terraform uses its `s3` backend and the `AWS_ACCESS_KEY_ID` /
`AWS_SECRET_ACCESS_KEY` variable names. Those values are **OCI Customer Secret
Keys**, and the endpoint is `*.compat.objectstorage.*.oraclecloud.com`. There is
no AWS account or AWS resource in this design.

One-time bootstrap (requires the OCI CLI and `OCI_CLI_USER`):

```bash
export OCI_COMPARTMENT_OCID='ocid1.compartment...'
export OCI_CLI_USER='ocid1.user...'
bash scripts/bootstrap-state.sh
```

The script creates a private, versioned bucket, creates a Customer Secret Key, and
prints the four values to add as repository secrets. The secret key is shown once.

## 11. GitHub repository secrets

Settings → Secrets and variables → Actions → **New repository secret**.

| Secret | Value |
|---|---|
| `OCI_CLI_USER` | User OCID |
| `OCI_CLI_TENANCY` | Tenancy OCID |
| `OCI_CLI_FINGERPRINT` | API key fingerprint |
| `OCI_CLI_REGION` | `us-ashburn-1` |
| `OCI_CLI_KEY_CONTENT` | Full PEM contents of `oci_api_key.pem` |
| `OCI_COMPARTMENT_OCID` | Compartment OCID |
| `OCI_ADMIN_CIDR` | `<your-ip>/32` |
| `OCI_SSH_PUBLIC_KEY` | Contents of `oci_platform.pub` |
| `OCI_SSH_PRIVATE_KEY` | Contents of `oci_platform` (Ansible workflow) |
| `DB_ADMIN_PASSWORD` | ADB ADMIN password |
| `ALERT_EMAIL` | Alert inbox |
| `OCIR_USERNAME` | `<namespace>/<email>` |
| `OCIR_AUTH_TOKEN` | OCIR auth token |
| `OCIR_IMAGE` | `iad.ocir.io/<namespace>/platform-api` |
| `OCI_OKE_CLUSTER_ID` | Output `oke_cluster_id` (optional) |
| `OCI_NAMESPACE` | Object Storage namespace (state bucket endpoint) |
| `OCI_TFSTATE_BUCKET` | State bucket name from `bootstrap-state.sh` |
| `OCI_S3_ACCESS_KEY` | OCI Customer Secret Key ID (S3-compatible state) |
| `OCI_S3_SECRET_KEY` | OCI Customer Secret Key secret (S3-compatible state) |

Repository variables (Settings → Variables → Actions), optional:

| Variable | Value |
|---|---|
| `ENABLE_OKE` | `true` to keep container deployment enabled |

## 12. IAM permissions for the deploying user

The simplest personal-tenancy setup is a tenancy administrator. If you want a
scoped CI user instead, grant it a policy in the target compartment:

```text
Allow group <ci-group> to manage all-resources in compartment <platform-compartment>
Allow group <ci-group> to read tenancy in tenancy
```

Creating a new compartment (`create_compartments = true`) additionally requires
`manage compartments` at tenancy scope:

```text
Allow group <ci-group> to manage compartments in tenancy
```

The Terraform code creates its own admin, reader, and instance-principal policies.
The deploying identity is separate from those runtime identities.

## 13. Local CLI check

```bash
oci iam region list
oci os ns get
terraform -chdir=environments/dev init
make preflight
```

`make preflight` requires only the database password in the local environment and
a usable OCI authentication method. The other `TF_VAR_*` values are reported as
`skip` locally because the pipeline supplies them from GitHub secrets. Missing
optional tools are warnings, not failures.

The primary deployment path is GitHub Actions. You do not need a fully configured
laptop; you need the repository secrets above and a successful `Terraform Apply`
run.

## What is deliberately not needed

- No OCI console password is stored anywhere.
- No SSH private key is committed; only the public key is a Terraform variable.
- No database password is committed; it is an environment variable and a Vault
  secret.
- No state file is committed; local state is gitignored.
