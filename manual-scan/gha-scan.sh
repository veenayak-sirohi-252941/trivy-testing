#!/usr/bin/env bash
# Run one scan mode for the non-blocking GitHub Actions comparison matrix.
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RESULT_DIR="${RESULT_DIR:-${RUNNER_TEMP:-/tmp}/scan-result}"
SCAN_ID="${SCAN_ID:-}"
mkdir -p "$RESULT_DIR"

report="$RESULT_DIR/$SCAN_ID.json"
status_file="$RESULT_DIR/$SCAN_ID.status"
summary_file="$RESULT_DIR/$SCAN_ID.txt"

if [[ -z "$SCAN_ID" ]]; then
  echo "SCAN_ID is required" >&2
  exit 2
fi

run_scan() {
  case "$SCAN_ID" in
    trivy_fs_default)
      echo "=== Trivy filesystem scan: default config ==="
      docker run --rm --network none \
        -v "$REPO_ROOT:/repo:ro" -v "$RESULT_DIR:/out:rw" \
        aquasec/trivy:latest fs --scanners secret --format json \
        --output "/out/$SCAN_ID.json" --skip-dirs .git --skip-dirs results /repo
      ;;
    trivy_fs_custom)
      echo "=== Trivy filesystem scan: custom config (trivy.yaml) ==="
      docker run --rm --network none \
        -v "$REPO_ROOT:/repo:ro" \
        -v "$SCRIPT_DIR/trivy.yaml:/config/trivy.yaml:ro" \
        -v "$RESULT_DIR:/out:rw" \
        aquasec/trivy:latest fs --scanners secret --secret-config /config/trivy.yaml \
        --format json --output "/out/$SCAN_ID.json" \
        --skip-dirs .git --skip-dirs results /repo
      ;;
    trufflehog_fs_default)
      echo "=== TruffleHog filesystem scan: default config ==="
      docker run --rm --network none \
        -v "$REPO_ROOT:/repo:ro" \
        trufflesecurity/trufflehog:latest --no-update filesystem \
        --no-verification --no-color --json /repo > "$report"
      ;;
    trufflehog_fs_custom)
      echo "=== TruffleHog filesystem scan: custom config (trufflehog.yaml) ==="
      docker run --rm --network none \
        -v "$REPO_ROOT:/repo:ro" \
        -v "$SCRIPT_DIR/trufflehog.yaml:/config/trufflehog.yaml:ro" \
        trufflesecurity/trufflehog:latest --no-update filesystem \
        --no-verification --no-color --json /repo \
        --config=/config/trufflehog.yaml > "$report"
      ;;
    trufflehog_git_default)
      echo "=== TruffleHog Git history scan: default config ==="
      docker run --rm --network none \
        -v "$REPO_ROOT:/repo:ro" \
        trufflesecurity/trufflehog:latest --no-update git file:///repo \
        --no-verification --no-color --json > "$report"
      ;;
    trufflehog_git_custom)
      echo "=== TruffleHog Git history scan: custom config (trufflehog.yaml) ==="
      docker run --rm --network none \
        -v "$REPO_ROOT:/repo:ro" \
        -v "$SCRIPT_DIR/trufflehog.yaml:/config/trufflehog.yaml:ro" \
        trufflesecurity/trufflehog:latest --no-update git file:///repo \
        --no-verification --no-color --json \
        --config=/config/trufflehog.yaml > "$report"
      ;;
    gitleaks_fs_default|gitleaks_fs_custom)
      config_args=()
      if [[ "$SCAN_ID" == gitleaks_fs_custom ]]; then
        echo "=== Gitleaks filesystem scan: custom config (gitleaks.toml) ==="
        config_args=(--config /config/gitleaks.toml)
      else
        echo "=== Gitleaks filesystem scan: default config ==="
      fi
      docker_args=(--rm --network none -v "$REPO_ROOT:/repo:ro" -v "$RESULT_DIR:/out:rw")
      if [[ "$SCAN_ID" == gitleaks_fs_custom ]]; then
        docker_args+=(-v "$SCRIPT_DIR/gitleaks.toml:/config/gitleaks.toml:ro")
      fi
      docker run "${docker_args[@]}" ghcr.io/gitleaks/gitleaks:v8.24.3 \
        dir "${config_args[@]}" --redact=100 --report-format json \
        --report-path "/out/$SCAN_ID.json" --exit-code 0 /repo
      ;;
    gitleaks_git_default|gitleaks_git_custom)
      config_args=()
      if [[ "$SCAN_ID" == gitleaks_git_custom ]]; then
        echo "=== Gitleaks Git history scan: custom config (gitleaks.toml) ==="
        config_args=(--config /config/gitleaks.toml)
      else
        echo "=== Gitleaks Git history scan: default config ==="
      fi
      docker_args=(--rm --network none -v "$REPO_ROOT:/repo:ro" -v "$RESULT_DIR:/out:rw")
      if [[ "$SCAN_ID" == gitleaks_git_custom ]]; then
        docker_args+=(-v "$SCRIPT_DIR/gitleaks.toml:/config/gitleaks.toml:ro")
      fi
      docker run "${docker_args[@]}" --workdir /repo \
        ghcr.io/gitleaks/gitleaks:v8.24.3 git "${config_args[@]}" \
        --log-opts=--all --redact=100 --report-format json \
        --report-path "/out/$SCAN_ID.json" --exit-code 0 /repo
      ;;
    *)
      echo "Unknown scan ID: $SCAN_ID" >&2
      return 2
      ;;
  esac
}

if run_scan; then
  printf 'success\n' > "$status_file"
else
  scan_status=$?
  printf 'error:%s\n' "$scan_status" > "$status_file"
  echo "::warning::${SCAN_ID} scanner command exited with status ${scan_status}; workflow will continue."
fi

python3 - "$SCAN_ID" "$report" "$status_file" "$summary_file" <<'PY'
import json
import sys
from pathlib import Path

scan_id, report_name, status_name, summary_name = sys.argv[1:]
report_path = Path(report_name)
status = Path(status_name).read_text().strip()
items = []

def safe(value):
    return str(value or "unknown").replace("|", "\\|").replace("\n", " ")

try:
    if not report_path.is_file():
        raise ValueError("report was not created")
    if scan_id.startswith("trivy_"):
        data = json.loads(report_path.read_text())
        for result in data.get("Results") or []:
            for finding in result.get("Secrets") or []:
                items.append((
                    result.get("Target", "unknown"),
                    finding.get("RuleID", "secret"),
                    finding.get("StartLine", "?"),
                ))
    elif scan_id.startswith("gitleaks_"):
        data = json.loads(report_path.read_text())
        if not isinstance(data, list):
            raise ValueError("unexpected Gitleaks report format")
        for finding in data:
            items.append((finding.get("File", "unknown"), finding.get("RuleID", "secret"), finding.get("StartLine", "?")))
    else:
        for line in report_path.read_text().splitlines():
            if not line.strip():
                continue
            finding = json.loads(line)
            if not finding.get("DetectorName"):
                continue
            metadata = (finding.get("SourceMetadata") or {}).get("Data") or {}
            location = metadata.get("Git") or metadata.get("Filesystem") or {}
            items.append((location.get("file", "unknown"), finding.get("DetectorName", "secret"), location.get("line", "?")))
except (OSError, ValueError, json.JSONDecodeError) as error:
    print(f"::warning::{scan_id} report could not be parsed ({type(error).__name__}); contents suppressed.")
    status = "error:report"

print(f"Result: {len(items)} finding(s); scan status: {status}")
if items:
    print("Location | Detector | Line")
    for target, detector, line in items:
        print(f"{safe(target)} | {safe(detector)} | {safe(line)}")
else:
    print("No findings.")

Path(summary_name).write_text(str(len(items)) if status == "success" else f"ERROR ({status})")
PY

# Keep scanner or parsing errors visible in this matrix task without failing
# the overall GitHub Actions workflow.
