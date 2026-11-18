#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-ansible/inventory/hosts.ini}"
mkdir -p "$(dirname "$OUT")"

export PATH="$HOME/.local/bin:$PATH"

if python3 scripts/oci_inventory.py > "${OUT}.tmp" 2>/dev/null && grep -q "\[app\]" "${OUT}.tmp" && [ $(grep -c "ansible_user=deploy" "${OUT}.tmp") -gt 0 ]; then
  mv "${OUT}.tmp" "$OUT"
  echo "Discovered dynamic inventory via OCI tags:"
else
  rm -f "${OUT}.tmp"
  echo "Using baseline inventory:"
fi

cat "$OUT"
