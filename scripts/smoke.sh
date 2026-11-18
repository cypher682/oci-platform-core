#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-dev}"
URL="$(terraform -chdir="environments/${ENV}" output -raw health_url)"

echo "Smoke testing ${URL}"
for attempt in $(seq 1 12); do
  if body="$(curl -fsS --max-time 5 "$URL" 2>/dev/null)"; then
    echo "HTTP 200"
    echo "$body"
    exit 0
  fi
  echo "attempt ${attempt}/12 — not ready yet"
  sleep 5
done

echo "Health check failed after 60 seconds"
exit 1
