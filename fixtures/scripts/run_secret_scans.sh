#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/reports"
mkdir -p "$OUT"
overall=0
run() {
  local label="$1" bin="$2"; shift 2
  echo "=== $label ==="
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "NOT RUN: $bin unavailable"
    if [ "$overall" -eq 0 ]; then overall=2; fi
    return
  fi
  "$bin" --version 2>&1 | head -n 2 || true
  echo "Command: $*"
  local code
  if [ "$label" = "TruffleHog" ]; then
    "$@" > "$OUT/trufflehog.jsonl"
    code=$?
    cat "$OUT/trufflehog.jsonl"
  else
    "$@" 2>&1 | tee "$OUT/${label,,}.log"
    code=$?
  fi
  echo "$label exit status: $code (findings and execution errors require report review)"
  if [ "$code" -ne 0 ]; then overall=1; fi
}
run Gitleaks gitleaks gitleaks detect --source "$ROOT" --config "$ROOT/.gitleaks.toml" --report-format json --report-path "$OUT/gitleaks.json" --no-git
if command -v gitleaks >/dev/null 2>&1 && [ -d "$ROOT/.git" ]; then
  run Gitleaks-history gitleaks gitleaks detect --source "$ROOT" --config "$ROOT/.gitleaks.toml" --report-format json --report-path "$OUT/gitleaks-history.json"
else
  echo "Gitleaks history: NOT RUN (fixture directory is not an independent Git repository yet)"
fi
run TruffleHog trufflehog trufflehog filesystem --no-verification --json "$ROOT"
run Trivy trivy trivy fs --scanners secret --format json --output "$OUT/trivy.json" "$ROOT"
echo "Reports and logs: $OUT"
exit "$overall"
