# Pipeline setup — where every value comes from

This is the click-by-click path from a fresh OCI tenancy to a running platform.
You need OCI tenancy administrator access and admin access to the GitHub
repository.

Console paths use the OCI Console at <https://cloud.oracle.com>. The region in
this repository is **US East (Ashburn)**, identifier `us-ashburn-1`.

---

## Step 1 — Collect the OCI API credentials

### 1.1 Tenancy OCID

1. Click the profile avatar, top right.
2. Click **Tenancy: <your tenancy name>**.
3. Copy **OCID** under Tenancy Information.

This is `OCI_CLI_TENANCY` and `TF_VAR_tenancy_ocid`. For a personal tenancy it is
also a valid root compartment OCID.

### 1.2 User OCID

1. Profile avatar → **My profile**.
2. Copy **OCID** under User Information.

This is `OCI_CLI_USER` and `TF_VAR_...` is not needed separately; Terraform uses
the API key config.

### 1.3 API signing key and fingerprint

1. Profile avatar → **My profile** → **API keys**.
2. **Add API key** → **Generate API key pair**.
3. **Download private key**. OCI shows it once; save it as
   `~/.oci/oci_api_key.pem`.
4. **Add**.
5. Copy the **Fingerprint** from the API keys table.

- Fingerprint → `OCI_CLI_FINGERPRINT`
- Private key contents → `OCI_CLI_KEY_CONTENT`

In OCI Cloud Shell or on a configured laptop, the same values are already in
`~/.oci/config`:

```bash
cat ~/.oci/config
cat ~/.oci/oci_api_key.pem
```

Do not paste the private key into a shell command that gets logged. Paste it
directly into the GitHub secret field.

### 1.4 Region

Use the region selector in the top bar. For Ashburn:

- Console name: **US East (Ashburn)**
- Identifier: `us-ashburn-1`
- OCIR key: `iad`

Set `OCI_CLI_REGION=us-ashburn-1`.

### 1.5 Compartment OCID

1. Hamburger menu → **Identity & Security** → **Compartments**.
2. Select the compartment that should own the platform, or stay at the root.
3. Copy its **OCID**.

This is `OCI_COMPARTMENT_OCID`. The dev stack defaults to
`create_compartments = false`, so resources land directly in this compartment.
The root compartment OCID is the tenancy OCID.

The deploying user needs permission to manage resources there. A tenancy
administrator already has it.

### 1.6 Object Storage namespace

1. Hamburger menu → **Storage** → **Object Storage** → **Buckets**.
2. The namespace appears in the page header / bucket details.

Or in Cloud Shell:

```bash
oci os ns get --query data --raw-output
```

This is `OCI_NAMESPACE`. It is also the first part of the OCIR username.

---

## Step 2 — Bootstrap the Terraform state bucket

The pipeline must not keep state on an ephemeral GitHub runner. The bootstrap
script creates a private, versioned Object Storage bucket and an S3-compatible
Customer Secret Key.

Run this in **OCI Cloud Shell** (top-right `>_` icon):

```bash
git clone https://github.com/cypher682/oci-platform-core.git
cd oci-platform-core

export OCI_CLI_USER='ocid1.user.oc1.....'
export OCI_COMPARTMENT_OCID='ocid1.compartment.oc1.....'   # or tenancy OCID

bash scripts/bootstrap-state.sh
```

If you do not know the user OCID, list users (use the tenancy OCID):

```bash
oci iam user list --compartment-id 'ocid1.tenancy.oc1.....' --all \
  --query 'data[].{name:"display-name",id:id}' --output table
```

The script prints four values. Copy them now:

```text
OCI_NAMESPACE=...
OCI_TFSTATE_BUCKET=oci-platform-core-tfstate
OCI_S3_ACCESS_KEY=...
OCI_S3_SECRET_KEY=...
```

The secret key is shown only once. If you lose it, create another Customer Secret
Key: profile avatar → **My profile** → **Customer secret keys** → **Generate
secret key**. The **access key** is the key ID; the **secret key** is the secret.

The bucket is private and versioned. Do not make it public.

---

## Step 3 — Generate the SSH key pair and database password

### SSH key

On the machine you will use to reach the ops runner:

```bash
ssh-keygen -t ed25519 -C "oci-platform-core" -f ~/.ssh/oci_platform
```

- `OCI_SSH_PUBLIC_KEY` = contents of `~/.ssh/oci_platform.pub`
- `OCI_SSH_PRIVATE_KEY` = contents of `~/.ssh/oci_platform`

Windows PowerShell:

```powershell
Get-Content -Raw $HOME\.ssh\oci_platform.pub | Set-Clipboard
Get-Content -Raw $HOME\.ssh\oci_platform     | Set-Clipboard
```

The public key is injected into the instances. The private key is used by the
Ansible workflow and by you when SSHing to the ops runner.

### ADB password

ADB requires 12–30 characters with uppercase, lowercase, number, and special
character, and it must not contain `admin`.

```bash
PW="$(openssl rand -base64 12 | tr -d '/+=')#A1"
echo "$PW"
```

Store it in a password manager. This is `DB_ADMIN_PASSWORD`; it is also written to
OCI Vault by Terraform.

### Alert email

Use an inbox you can check. This is `ALERT_EMAIL`. After the first apply, OCI
sends a subscription confirmation; alerts do not work until you confirm it.

### Operator CIDR

On your laptop, not Cloud Shell:

```bash
curl -4 https://ifconfig.me
```

Append `/32`. Example: `203.0.113.10/32`. This is `OCI_ADMIN_CIDR`; it gates SSH
to the ops runner and the Bastion.

---

## Step 4 — Create the OCIR credentials

### Auth token

1. Profile avatar → **My profile** → **Auth tokens**.
2. **Generate token**.
3. Copy it immediately.

This is `OCIR_AUTH_TOKEN`.

### Username

The OCIR username is the namespace plus your OCI username:

```text
<namespace>/<email>
```

Example: `axxxxxxxxxxx/you@example.com`.

If your tenancy is federated with Oracle Identity Cloud Service, use:

```text
<namespace>/oracleidentitycloudservice/<email>
```

This is `OCIR_USERNAME`. It is not your console password and not your API key.

### Image path

After the first apply, the repository exists:

```text
iad.ocir.io/<namespace>/platform-api
```

Set `OCIR_IMAGE` to that path **without a tag**.

---

## Step 5 — Add GitHub repository secrets

GitHub repository → **Settings** → **Secrets and variables** → **Actions** →
**New repository secret**.

| Secret | Where it comes from |
|---|---|
| `OCI_CLI_USER` | Step 1.2 |
| `OCI_CLI_TENANCY` | Step 1.1 |
| `OCI_CLI_FINGERPRINT` | Step 1.3 |
| `OCI_CLI_REGION` | `us-ashburn-1` |
| `OCI_CLI_KEY_CONTENT` | Step 1.3, full PEM contents |
| `OCI_COMPARTMENT_OCID` | Step 1.5 |
| `OCI_ADMIN_CIDR` | Step 3, your IP `/32` |
| `OCI_SSH_PUBLIC_KEY` | Step 3, `.pub` contents |
| `OCI_SSH_PRIVATE_KEY` | Step 3, private key contents |
| `DB_ADMIN_PASSWORD` | Step 3 |
| `ALERT_EMAIL` | Step 3 |
| `OCI_NAMESPACE` | Step 2 / 1.6 |
| `OCI_TFSTATE_BUCKET` | Step 2 |
| `OCI_S3_ACCESS_KEY` | Step 2, Customer Secret Key **ID** |
| `OCI_S3_SECRET_KEY` | Step 2, Customer Secret Key **secret** |
| `OCIR_USERNAME` | Step 4 |
| `OCIR_AUTH_TOKEN` | Step 4 |
| `OCIR_IMAGE` | `iad.ocir.io/<namespace>/platform-api` |
| `OCI_OKE_CLUSTER_ID` | After first apply; optional until then |

Create the GitHub environment used by the apply job:

**Settings** → **Environments** → **New environment** → `dev`. Do not add required
reviewers unless you want a second approval step. Create `prod` only when you
intend to deploy it.

Optional repository variables (**Settings** → **Secrets and variables** →
**Actions** → **Variables**):

| Variable | Default | Use |
|---|---|---|
| `ENABLE_OKE` | `true` | Set `false` to skip the cluster |
| `ENABLE_ADB` | `true` | Set `false` if the free ADB instance is already used |
| `CREATE_COMPARTMENTS` | `false` | Set `true` to create a child compartment |

---

## Step 6 — Run the pipeline

1. **Actions** → **Terraform Plan** → **Run workflow** → branch `main`.
2. Wait for green. Read the plan summary.
3. **Actions** → **Terraform Apply** → **Run workflow**:
   - environment: `dev`
   - confirm: `APPLY`
4. Wait. OKE and ADB take the longest; expect 20–40 minutes on a first run.
5. Open the run summary / `terraform-outputs-dev` artifact. Copy:
   - `health_url`
   - `ops_runner_public_ip`
   - `ocir_image`
   - `oke_cluster_id`

6. Add `OCI_OKE_CLUSTER_ID` to repository secrets so the application workflow can
   deploy to OKE.

7. Confirm the ONS email subscription.

If the apply fails because ADB free tier is unavailable, add repository variable
`ENABLE_ADB=false` and rerun. If OKE capacity is unavailable, add
`ENABLE_OKE=false`.

---

## Step 7 — Bootstrap the self-hosted Ansible runner

The Ansible workflow runs on `[self-hosted, linux, x64, oci-platform]`. That
runner does not exist until it is installed, so this is a one-time manual step.
Everything after it is pipeline-driven.

1. Get `ops_runner_public_ip` from the apply artifact.
2. SSH in:

```bash
ssh -i ~/.ssh/oci_platform deploy@<ops_runner_public_ip>
```

3. On the runner:

```bash
git clone https://github.com/cypher682/oci-platform-core.git
cd oci-platform-core

python3 -m pip install --user "ansible-core>=2.16" docker
export PATH="$HOME/.local/bin:$PATH"
ansible-galaxy collection install -r ansible/requirements.yml

export OCI_COMPARTMENT_OCID='ocid1.compartment...'
OCI_AUTH_MODE=instance_principal bash scripts/oci-inventory.sh ansible/inventory/hosts.ini

export ADMIN_CIDR='<your-ip>/32'
export OCIR_REGISTRY='iad.ocir.io'
export OCIR_USERNAME='<namespace>/<email>'
export OCIR_AUTH_TOKEN='...'
export OCIR_IMAGE='iad.ocir.io/<namespace>/platform-api'

cd ansible
ansible-playbook site.yml -i inventory/hosts.ini
```

4. The `gh-runner` role needs a registration token to install the runner. Get one
   from GitHub: repository → **Settings** → **Actions** → **Runners** → **New
   self-hosted runner**; copy the token, then on the runner:

```bash
export GH_RUNNER_TOKEN='<token>'
cd ~/oci-platform-core/ansible
ansible-playbook site.yml -i inventory/hosts.ini --tags gh-runner
```

5. The runner appears under **Settings → Actions → Runners** with labels
   `self-hosted`, `linux`, `x64`, `oci-platform`.
6. **Actions → Ansible Configuration → Run workflow**.

---

## Step 8 — Deploy the application

The first Terraform Apply can deploy the workload to OKE. Future changes:

1. Push a change under `app/`.
2. **Build and Deploy Application** runs automatically.
3. It builds the image, pushes to OCIR, updates the deployment, and smoke-tests the
   Kubernetes load balancer.

For the VM tier, rerun **Ansible Configuration**.

---

## Quick verification

```bash
# Locally, if you have the CLI configured
oci os bucket get --namespace "$OCI_NAMESPACE" --name "$OCI_TFSTATE_BUCKET"

# From the apply output
curl -fsS "<health_url>"
```

On GitHub:

- **Terraform Plan** green.
- **Terraform Apply** green.
- **Actions → Runners** shows the ops runner idle.
- **Ansible Configuration** green.
- **Build and Deploy Application** green.

## Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| `401` from OCI in Actions | fingerprint does not match the PEM | re-copy both from the same API key |
| `NotAuthorizedOrNotFound` | compartment wrong or user lacks policy | use tenancy admin or grant `manage all-resources` in the compartment |
| `terraform init` cannot reach bucket | wrong namespace/endpoint or customer secret key | rerun `bootstrap-state.sh`, update the four state secrets |
| OCIR `denied` | username format or expired token | use `<namespace>/<email>`; generate a new auth token |
| OKE deploy skipped | `OCI_OKE_CLUSTER_ID` unset | copy it from the apply output and add the secret |
| ADB create fails | free-tier instance already exists | set `ENABLE_ADB=false` |
| Ansible workflow never starts | self-hosted runner not registered | complete Step 7 |
