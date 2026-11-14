#!/usr/bin/env bash
# Manual Trivy filesystem secret scan.
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_TARGET="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="${1:-$DEFAULT_TARGET}"
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Scan target directory not found: $TARGET_DIR" >&2
  exit 2
fi
TARGET_DIR="$(cd -- "$TARGET_DIR" && pwd)"

echo "=== Trivy: filesystem scan with custom config (trivy.yaml) ==="
docker run --rm --network none \
  -v "$TARGET_DIR:/repo:ro" \
  -v "$SCRIPT_DIR/trivy.yaml:/config/trivy.yaml:ro" \
  aquasec/trivy:latest \
  fs --scanners secret --secret-config /config/trivy.yaml --format table \
  --skip-dirs .git --skip-dirs results /repo

echo "=== Trivy: filesystem scan without custom config ==="
docker run --rm --network none \
  -v "$TARGET_DIR:/repo:ro" \
  aquasec/trivy:latest \
  fs --scanners secret --format table \
  --skip-dirs .git --skip-dirs results /repo
