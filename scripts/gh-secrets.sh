#!/usr/bin/env bash
# Upload the OCI values the pipelines need to GitHub Actions secrets.
# It reads ~/.oci/config and the API private key, asks for anything that is not
# already in the environment, and calls `gh secret set` for each value.
#
# Usage:
#   bash scripts/gh-secrets.sh --dry-run
#   bash scripts/gh-secrets.sh
#
# Prerequisites:
#   oci setup config       # creates ~/.oci/config and ~/.oci/oci_api_key.pem
#   gh auth login          # authenticated as the repository owner
#   ssh-keygen -t ed25519 -f ~/.ssh/oci_platform
#
# Nothing is printed except secret names and lengths. Values go to gh on stdin.

set -euo pipefail

REPO="${REPO:-cypher682/oci-platform-core}"
PROFILE="${OCI_CLI_PROFILE:-DEFAULT}"
CONFIG="${OCI_CONFIG_FILE:-$HOME/.oci/config}"
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }

[ -f "$CONFIG" ] || die "missing $CONFIG. Run: oci setup config"

read_cfg() {
  local key="$1"
  awk -v key="$key" -v prof="$PROFILE" '
    /^\[/ { in_section = ($0 == "[" prof "]"); next }
    in_section && $0 ~ "^[ \t]*" key "[ \t]*=" {
      sub(/^[^=]*=[ \t]*/, ""); sub(/[ \t\r]+$/, ""); print; exit
    }
  ' "$CONFIG"
}

OCI_CLI_USER="${OCI_CLI_USER:-$(read_cfg user)}"
OCI_CLI_TENANCY="${OCI_CLI_TENANCY:-$(read_cfg tenancy)}"
OCI_CLI_FINGERPRINT="${OCI_CLI_FINGERPRINT:-$(read_cfg fingerprint)}"
OCI_CLI_REGION="${OCI_CLI_REGION:-$(read_cfg region)}"

KEY_FILE="${OCI_CLI_KEY_FILE:-$(read_cfg key_file)}"
KEY_FILE="${KEY_FILE/#\~/$HOME}"
if command -v cygpath >/dev/null 2>&1 && [[ "$KEY_FILE" =~ ^[A-Za-z]: ]]; then
  KEY_FILE="$(cygpath -u "$KEY_FILE")"
fi

[ -n "$OCI_CLI_USER" ] || die "user missing from $CONFIG"
[ -n "$OCI_CLI_TENANCY" ] || die "tenancy missing from $CONFIG"
[ -n "$OCI_CLI_FINGERPRINT" ] || die "fingerprint missing from $CONFIG"
[ -n "$OCI_CLI_REGION" ] || die "region missing from $CONFIG"
[ -f "$KEY_FILE" ] || die "API private key not found at $KEY_FILE"

OCI_CLI_KEY_CONTENT="$(cat "$KEY_FILE")"
OCI_COMPARTMENT_OCID="${OCI_COMPARTMENT_OCID:-$OCI_CLI_TENANCY}"

ask() {
  local var="$1" label="$2" default="${3-}" secret="${4-}"
  local value="${!var-}"
  if [ -n "$value" ]; then return; fi
  if [ "$secret" = "secret" ]; then
    read -r -s -p "$label: " value
    echo
  else
    read -r -p "$label${default:+ [$default]}: " value
  fi
  value="${value:-$default}"
  printf -v "$var" '%s' "$value"
}

if [ -z "${OCI_NAMESPACE-}" ] && command -v oci >/dev/null 2>&1; then
  OCI_NAMESPACE="$(oci os ns get --profile "$PROFILE" --query data --raw-output 2>/dev/null || true)"
fi
ask OCI_NAMESPACE "Object Storage namespace"
[ -n "$OCI_NAMESPACE" ] || die "namespace is required"

ask OCI_TFSTATE_BUCKET "Terraform state bucket" "oci-platform-core-tfstate"
ask OCI_S3_ACCESS_KEY "State Customer Secret Key access key"
ask OCI_S3_SECRET_KEY "State Customer Secret Key secret" "" secret

DETECTED_IP="$(curl -4 -fsS --max-time 5 https://ifconfig.me 2>/dev/null | tr -d '[:space:]' || true)"
ask OCI_ADMIN_CIDR "Operator CIDR" "${DETECTED_IP:+$DETECTED_IP/32}"
[[ "$OCI_ADMIN_CIDR" == *"/"* ]] || die "OCI_ADMIN_CIDR must include a prefix, for example 203.0.113.10/32"
[ "$OCI_ADMIN_CIDR" != "0.0.0.0/0" ] || die "refusing 0.0.0.0/0; use your public IP"

ask ALERT_EMAIL "Alert email"
ask DB_ADMIN_PASSWORD "ADB admin password (12-30 chars, upper/lower/number/special)" "" secret
if [ ${#DB_ADMIN_PASSWORD} -lt 12 ] || [ ${#DB_ADMIN_PASSWORD} -gt 30 ] \
   || [[ ! "$DB_ADMIN_PASSWORD" =~ [A-Z] ]] \
   || [[ ! "$DB_ADMIN_PASSWORD" =~ [a-z] ]] \
   || [[ ! "$DB_ADMIN_PASSWORD" =~ [0-9] ]] \
   || [[ ! "$DB_ADMIN_PASSWORD" =~ [^A-Za-z0-9] ]] \
   || [[ "$(printf '%s' "$DB_ADMIN_PASSWORD" | tr '[:upper:]' '[:lower:]')" == *admin* ]]; then
  die "ADB password does not meet the rules"
fi

SSH_PRIVATE_PATH="${OCI_SSH_PRIVATE_KEY_PATH:-$HOME/.ssh/oci_platform}"
SSH_PUBLIC_PATH="${OCI_SSH_PUBLIC_KEY_PATH:-$SSH_PRIVATE_PATH.pub}"
[ -f "$SSH_PRIVATE_PATH" ] || die "missing $SSH_PRIVATE_PATH; run: ssh-keygen -t ed25519 -f ~/.ssh/oci_platform"
[ -f "$SSH_PUBLIC_PATH" ] || die "missing $SSH_PUBLIC_PATH"
OCI_SSH_PRIVATE_KEY="$(cat "$SSH_PRIVATE_PATH")"
OCI_SSH_PUBLIC_KEY="$(cat "$SSH_PUBLIC_PATH")"

ask OCIR_USERNAME "OCIR username (namespace/email)"
ask OCIR_AUTH_TOKEN "OCIR auth token" "" secret
ask OCIR_IMAGE "OCIR image path" "iad.ocir.io/$OCI_NAMESPACE/platform-api"

OCI_OKE_CLUSTER_ID="${OCI_OKE_CLUSTER_ID-}"

if [ "$DRY_RUN" = 0 ]; then
  command -v gh >/dev/null 2>&1 || die "gh is not installed"
  gh auth status >/dev/null 2>&1 || die "gh is not authenticated. Run: gh auth login"
  gh repo view "$REPO" >/dev/null 2>&1 || die "cannot access $REPO"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
umask 077

set_secret() {
  local name="$1" value="$2"
  if [ "$DRY_RUN" = 1 ]; then
    printf 'would set %-24s (%s chars)\n' "$name" "${#value}"
    return
  fi
  printf '%s' "$value" > "$TMP/$name"
  gh secret set "$name" --repo "$REPO" < "$TMP/$name" >/dev/null
  printf 'set %s\n' "$name"
}

set_secret OCI_CLI_USER "$OCI_CLI_USER"
set_secret OCI_CLI_TENANCY "$OCI_CLI_TENANCY"
set_secret OCI_CLI_FINGERPRINT "$OCI_CLI_FINGERPRINT"
set_secret OCI_CLI_REGION "$OCI_CLI_REGION"
set_secret OCI_CLI_KEY_CONTENT "$OCI_CLI_KEY_CONTENT"
set_secret OCI_COMPARTMENT_OCID "$OCI_COMPARTMENT_OCID"
set_secret OCI_NAMESPACE "$OCI_NAMESPACE"
set_secret OCI_TFSTATE_BUCKET "$OCI_TFSTATE_BUCKET"
set_secret OCI_S3_ACCESS_KEY "$OCI_S3_ACCESS_KEY"
set_secret OCI_S3_SECRET_KEY "$OCI_S3_SECRET_KEY"
set_secret OCI_ADMIN_CIDR "$OCI_ADMIN_CIDR"
set_secret OCI_SSH_PUBLIC_KEY "$OCI_SSH_PUBLIC_KEY"
set_secret OCI_SSH_PRIVATE_KEY "$OCI_SSH_PRIVATE_KEY"
set_secret DB_ADMIN_PASSWORD "$DB_ADMIN_PASSWORD"
set_secret ALERT_EMAIL "$ALERT_EMAIL"
set_secret OCIR_USERNAME "$OCIR_USERNAME"
set_secret OCIR_AUTH_TOKEN "$OCIR_AUTH_TOKEN"
set_secret OCIR_IMAGE "$OCIR_IMAGE"

if [ -n "$OCI_OKE_CLUSTER_ID" ]; then
  set_secret OCI_OKE_CLUSTER_ID "$OCI_OKE_CLUSTER_ID"
else
  echo "skip OCI_OKE_CLUSTER_ID (add it after the first apply)"
fi

echo
if [ "$DRY_RUN" = 1 ]; then
  echo "dry run only; no secrets changed"
else
  echo "done: $REPO secrets updated"
  echo "next: Actions -> Terraform Plan -> Run workflow"
fi
