#!/usr/bin/env bash
set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

missing=0
warn=0

check_required() {
  local name="$1"
  if [ -n "${!name:-}" ]; then
    printf "${GREEN}[ok]${NC}   %s is set\n" "$name"
  else
    printf "${RED}[miss]${NC} %s is not set\n" "$name"
    missing=$((missing + 1))
  fi
}

check_optional() {
  local name="$1"
  if [ -n "${!name:-}" ]; then
    printf "${GREEN}[ok]${NC}   %s is set\n" "$name"
  else
    printf "${YELLOW}[skip]${NC} %s not in environment — CI supplies it from repository secrets\n" "$name"
  fi
}

check_cmd() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf "${GREEN}[ok]${NC}   %s found\n" "$name"
  else
    printf "${YELLOW}[warn]${NC} %s not found (not needed for the pipeline path)\n" "$name"
    warn=$((warn + 1))
  fi
}

echo "OCI platform core — credential preflight"
echo "----------------------------------------"

# The pipeline supplies every TF_VAR from GitHub secrets. Locally, only the
# database password must be in the environment because it is intentionally
# absent from terraform.tfvars.
check_required TF_VAR_db_admin_password

for var in TF_VAR_tenancy_ocid TF_VAR_compartment_ocid TF_VAR_admin_cidr \
           TF_VAR_ssh_public_key TF_VAR_alert_email; do
  check_optional "$var"
done

if [ -f "$HOME/.oci/config" ]; then
  printf "${GREEN}[ok]${NC}   ~/.oci/config exists\n"
elif [ -n "${OCI_CLI_USER:-}" ] && [ -n "${OCI_CLI_TENANCY:-}" ] && [ -n "${OCI_CLI_FINGERPRINT:-}" ]; then
  printf "${GREEN}[ok]${NC}   OCI_CLI_* environment authentication is set\n"
else
  printf "${RED}[miss]${NC} no ~/.oci/config and no OCI_CLI_* authentication\n"
  missing=$((missing + 1))
fi

check_cmd terraform
check_cmd oci
check_cmd kubectl
check_cmd ansible-playbook
check_cmd docker

echo "----------------------------------------"
if [ "$missing" -gt 0 ]; then
  printf "${RED}%d required item(s) missing.${NC} Read docs/credentials.md.\n" "$missing"
  exit 1
fi

printf "${GREEN}Preflight passed.${NC}"
[ "$warn" -gt 0 ] && printf " %d optional tool(s) missing." "$warn"
echo
echo "Pipeline path: push, then run Terraform Apply in GitHub Actions."
