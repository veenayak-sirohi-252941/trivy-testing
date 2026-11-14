#!/usr/bin/env bash
# Manual TruffleHog filesystem and Git history scans.
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_TARGET="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="${1:-$DEFAULT_TARGET}"
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Scan target directory not found: $TARGET_DIR" >&2
  exit 2
fi
TARGET_DIR="$(cd -- "$TARGET_DIR" && pwd)"

# Filesystem scan with the custom regex detector.
echo "=== TruffleHog: filesystem scan with custom config (trufflehog.yaml) ==="
docker run --rm --network none \
  -v "$TARGET_DIR:/repo:ro" \
  -v "$SCRIPT_DIR/trufflehog.yaml:/config/trufflehog.yaml:ro" \
  trufflesecurity/trufflehog:latest \
  --no-update filesystem --no-verification --no-color --json /repo \
  --config=/config/trufflehog.yaml

echo "=== TruffleHog: filesystem scan without custom config ==="
docker run --rm --network none \
  -v "$TARGET_DIR:/repo:ro" \
  trufflesecurity/trufflehog:latest \
  --no-update filesystem --no-verification --no-color --json /repo

# Git history scan with the custom regex detector.
echo "=== TruffleHog: Git history scan with custom config (trufflehog.yaml) ==="
docker run --rm --network none \
  -v "$TARGET_DIR:/repo:ro" \
  -v "$SCRIPT_DIR/trufflehog.yaml:/config/trufflehog.yaml:ro" \
  trufflesecurity/trufflehog:latest \
  --no-update git file:///repo --no-verification --no-color --json \
  --config=/config/trufflehog.yaml

echo "=== TruffleHog: Git history scan without custom config ==="
docker run --rm --network none \
  -v "$TARGET_DIR:/repo:ro" \
  trufflesecurity/trufflehog:latest \
  --no-update git file:///repo --no-verification --no-color --json
