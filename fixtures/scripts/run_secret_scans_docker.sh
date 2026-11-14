#!/usr/bin/env bash
# Run the locally cached scanner images without pulling or verifying credentials.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORTS="/tmp/secret-scan-fixtures-reports"
mkdir -p "$REPORTS"
if ! command -v docker >/dev/null 2>&1; then
  echo "NOT RUN: Docker CLI unavailable"
  exit 2
fi
images=(zricethezav/gitleaks:latest trufflesecurity/trufflehog:latest aquasec/trivy:latest)
for image in "${images[@]}"; do
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    echo "NOT RUN: local image missing: $image (script will not pull images)"
    exit 2
  fi
done

echo '=== Gitleaks ==='
docker run --pull=never --rm zricethezav/gitleaks:latest version
docker run --pull=never --rm -v "$ROOT:/repo:ro" -v "$REPORTS:/reports" zricethezav/gitleaks:latest detect --source /repo --config /repo/.gitleaks.toml --report-format json --report-path /reports/gitleaks.json --no-git
echo "Gitleaks exit=$? (1 commonly indicates findings; inspect report and logs)"

echo '=== TruffleHog (verification disabled) ==='
docker run --pull=never --rm trufflesecurity/trufflehog:latest --version
docker run --pull=never --rm -v "$ROOT:/repo:ro" trufflesecurity/trufflehog:latest filesystem --no-verification --json /repo > "$REPORTS/trufflehog.jsonl"
echo "TruffleHog exit=$?"

echo '=== Trivy secret scanner ==='
docker run --pull=never --rm aquasec/trivy:latest --version
docker run --pull=never --rm -v "$ROOT:/repo:ro" -v "$REPORTS:/reports" aquasec/trivy:latest fs --scanners secret --format json --output /reports/trivy.json /repo
echo "Trivy exit=$?"

echo '=== Fixture comparison ==='
python3 "$ROOT/scripts/validate_findings.py" "$REPORTS/gitleaks.json" "$REPORTS/trufflehog.jsonl" "$REPORTS/trivy.json"
echo "Reports: $REPORTS"
