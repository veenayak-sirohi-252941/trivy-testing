#!/usr/bin/env bash
# Manual Gitleaks filesystem and Git history scans.
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_TARGET="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="${1:-$DEFAULT_TARGET}"
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Scan target directory not found: $TARGET_DIR" >&2
  exit 2
fi
TARGET_DIR="$(cd -- "$TARGET_DIR" && pwd)"

# Gitleaks returns exit code 1 when it finds leaks. Keep running later scans;
# inspect each report and command's exit status for the individual result.

# Filesystem scan without custom regex configuration.
echo "=== Gitleaks: filesystem scan without custom config ==="
docker run --rm --network none \
  -v "$TARGET_DIR:/repo:ro" \
  zricethezav/gitleaks:latest \
  detect --source /repo --report-format json \
  --report-path - \
  --redact --no-git

# Filesystem scan with the project's custom regex patterns.
echo "=== Gitleaks: filesystem scan with custom config (gitleaks.toml) ==="
docker run --rm --network none \
  -v "$TARGET_DIR:/repo:ro" \
  -v "$SCRIPT_DIR/gitleaks.toml:/config/gitleaks.toml:ro" \
  zricethezav/gitleaks:latest \
  detect --source /repo --config /config/gitleaks.toml \
  --report-format json --report-path - \
  --redact --no-git

# Git history scan without custom regex configuration.
echo "=== Gitleaks: Git history scan without custom config ==="
docker run --rm --network none \
  -v "$TARGET_DIR:/repo:ro" \
  zricethezav/gitleaks:latest \
  detect --source /repo --report-format json \
  --report-path - \
  --redact

# Git history scan with the project's custom regex patterns.
echo "=== Gitleaks: Git history scan with custom config (gitleaks.toml) ==="
docker run --rm --network none \
  -v "$TARGET_DIR:/repo:ro" \
  -v "$SCRIPT_DIR/gitleaks.toml:/config/gitleaks.toml:ro" \
  zricethezav/gitleaks:latest \
  detect --source /repo --config /config/gitleaks.toml \
  --report-format json --report-path - \
  --redact
