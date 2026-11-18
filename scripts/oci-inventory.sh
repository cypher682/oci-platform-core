#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-ansible/inventory/hosts.ini}"
mkdir -p "$(dirname "$OUT")"

: "${OCI_COMPARTMENT_OCID:?Export OCI_COMPARTMENT_OCID before running this script}"

python3 scripts/oci_inventory.py > "$OUT"
echo "Wrote ${OUT}"
cat "$OUT"
