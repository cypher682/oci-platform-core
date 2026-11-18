#!/usr/bin/env bash
set -uo pipefail

ENV="${1:-dev}"
TF_DIR="environments/${ENV}"
STAMP="$(date -u +%Y%m%d-%H%M%SZ)"
OUT="docs/evidence/${STAMP}"
mkdir -p "$OUT"

echo "Capturing evidence into ${OUT}"

terraform -chdir="$TF_DIR" output -json > "${OUT}/terraform-outputs.json" 2>/dev/null || true
terraform -chdir="$TF_DIR" output -raw evidence_bundle > "${OUT}/evidence-bundle.json" 2>/dev/null || true

COMPARTMENT_ID="$(terraform -chdir="$TF_DIR" output -raw compartment_id 2>/dev/null || true)"
HEALTH_URL="$(terraform -chdir="$TF_DIR" output -raw health_url 2>/dev/null || true)"
CLUSTER_ID="$(terraform -chdir="$TF_DIR" output -raw oke_cluster_id 2>/dev/null || true)"

{
  echo "env=${ENV}"
  echo "captured_at=${STAMP}"
  echo "git_sha=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
  terraform version
  oci --version 2>/dev/null || true
  kubectl version --client 2>/dev/null || true
  ansible --version 2>/dev/null | head -3 || true
} > "${OUT}/tooling.txt" 2>&1

if command -v oci >/dev/null 2>&1 && [ -n "$COMPARTMENT_ID" ]; then
  oci compute instance list --compartment-id "$COMPARTMENT_ID" --all --output table > "${OUT}/compute-instances.txt" 2>&1 || true
  oci network vcn list --compartment-id "$COMPARTMENT_ID" --output table > "${OUT}/vncs.txt" 2>&1 || true
  oci network subnet list --compartment-id "$COMPARTMENT_ID" --all --output table > "${OUT}/subnets.txt" 2>&1 || true
  oci lb load-balancer list --compartment-id "$COMPARTMENT_ID" --all --output table > "${OUT}/load-balancers.txt" 2>&1 || true
  oci ce cluster list --compartment-id "$COMPARTMENT_ID" --all --output table > "${OUT}/oke-clusters.txt" 2>&1 || true
  oci db autonomous-database list --compartment-id "$COMPARTMENT_ID" --all --output table > "${OUT}/autonomous-databases.txt" 2>&1 || true
  oci artifacts container repository list --compartment-id "$COMPARTMENT_ID" --all --output table > "${OUT}/ocir.txt" 2>&1 || true
  oci vault secret list --compartment-id "$COMPARTMENT_ID" --all --output table > "${OUT}/vault-secrets.txt" 2>&1 || true
  oci monitoring alarm list --compartment-id "$COMPARTMENT_ID" --all --output table > "${OUT}/alarms.txt" 2>&1 || true
  oci ons topic list --compartment-id "$COMPARTMENT_ID" --all --output table > "${OUT}/ons-topics.txt" 2>&1 || true
  oci bastion bastion list --compartment-id "$COMPARTMENT_ID" --all --output table > "${OUT}/bastions.txt" 2>&1 || true
fi

if [ -n "$HEALTH_URL" ]; then
  curl -fsS --max-time 10 "$HEALTH_URL" > "${OUT}/health.json" 2>&1 || true
fi

if command -v kubectl >/dev/null 2>&1 && [ -n "${KUBECONFIG:-}" ] && [ -n "$CLUSTER_ID" ] && [ "$CLUSTER_ID" != "null" ]; then
  kubectl get nodes -o wide > "${OUT}/k8s-nodes.txt" 2>&1 || true
  kubectl -n platform get pods,svc,deploy,hpa -o wide > "${OUT}/k8s-workloads.txt" 2>&1 || true
  kubectl -n platform describe svc platform-api > "${OUT}/k8s-service.txt" 2>&1 || true
fi

cat > "${OUT}/README.md" <<EOF
# Evidence — ${STAMP}

Environment: \`${ENV}\`

This directory was produced by \`make evidence ENV=${ENV}\`. It contains the
text evidence that pairs with the screenshots listed in
[docs/evidence/README.md](../README.md).

Add screenshots here using the numbering in that checklist (01-... to 12-...).
EOF

echo "Done. Add console screenshots to ${OUT}/ using docs/evidence/README.md."
