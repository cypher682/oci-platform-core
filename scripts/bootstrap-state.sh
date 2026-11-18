#!/usr/bin/env bash
set -euo pipefail

: "${OCI_COMPARTMENT_OCID:?Export OCI_COMPARTMENT_OCID}"
: "${OCI_CLI_USER:?Export OCI_CLI_USER (needed to create the S3 customer secret key)}"

BUCKET="${1:-oci-platform-core-tfstate}"

echo "Namespace and bucket"
NAMESPACE="$(oci os ns get --query data --raw-output)"
echo "namespace=${NAMESPACE}"

if oci os bucket get --namespace "$NAMESPACE" --name "$BUCKET" >/dev/null 2>&1; then
  echo "Bucket ${BUCKET} already exists"
else
  oci os bucket create \
    --compartment-id "$OCI_COMPARTMENT_OCID" \
    --name "$BUCKET" \
    --storage-tier Standard \
    --public-access-type NoPublicAccess \
    --versioning Enabled \
    --query 'data.name' --raw-output
fi

oci os bucket update \
  --namespace "$NAMESPACE" \
  --name "$BUCKET" \
  --versioning Enabled >/dev/null

echo
echo "Creating an S3 customer secret key for Terraform state"
KEY_JSON="$(oci iam customer-secret-key create \
  --user-id "$OCI_CLI_USER" \
  --display-name "terraform-state-$(date -u +%Y%m%d%H%M%S)" \
  --output json)"

KEY_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])' <<<"$KEY_JSON")"
SECRET="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["secret-key"])' <<<"$KEY_JSON")"

cat <<EOF

Add these GitHub repository secrets:

OCI_NAMESPACE=${NAMESPACE}
OCI_TFSTATE_BUCKET=${BUCKET}
OCI_S3_ACCESS_KEY=${KEY_ID}
OCI_S3_SECRET_KEY=${SECRET}

The secret key is shown once. Store it now.
EOF
