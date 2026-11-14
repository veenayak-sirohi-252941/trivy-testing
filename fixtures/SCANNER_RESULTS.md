# Scanner execution results

Executed on 2026-11-14 with the three locally available Docker images. All scans used filesystem mode; no scanner was run against Git history because `secret-scan-fixtures` is not yet an independent Git repository. No credentials were verified.

## Scanner information

| Scanner | Version | Execution Status |
|---|---|---|
| Gitleaks | v8.30.1 (`zricethezav/gitleaks:latest`) | COMPLETED; findings returned exit 1 |
| TruffleHog | 3.99.9 (`trufflesecurity/trufflehog:latest`) | COMPLETED; exit 0 |
| Trivy | 0.76.2 (`aquasec/trivy:latest`) | COMPLETED; exit 0 |

The image tags were already present locally; commands used `--pull=never`. TruffleHog ran with `--no-verification`; its report counted zero verified and five unverified results.

## Detection summary

| Measure | Result |
|---|---:|
| Positive fixture IDs | 71 |
| Negative fixture files | 2 |
| Gitleaks raw findings | 90 |
| Gitleaks positive fixture IDs mapped | 65 |
| Gitleaks custom rule IDs triggered | 17 of 17 |
| TruffleHog raw findings | 5 unverified; 0 verified |
| TruffleHog positive fixture IDs mapped | 4 |
| Trivy raw secret findings | 16 |
| Trivy positive fixture IDs mapped | 10 |
| Negative fixture findings | 0 for all three scanners |

Gitleaks produced 81 findings from custom rules and 9 from built-in rules (the total includes overlapping detections). All 17 custom rule IDs triggered, including the fine-grained GitHub PAT rule. No scanner reported a finding in either negative fixture file.

“Mapped” means an actual report location and line mapped to the nearest nearby fixture ID. A scanner can detect a credential without being mapped by this lightweight fixture-ID validator, so raw finding counts and mapped ID counts are reported separately. `EXPECTED_FINDINGS.md` records actual mapped status for each fixture.

## Commands used

Run from the workspace parent directory; reports were written outside the fixture tree to avoid scanning generated reports:

```sh
mkdir -p /tmp/secret-scan-reports
docker run --pull=never --rm -v "$PWD/secret-scan-fixtures:/repo:ro" -v /tmp/secret-scan-reports:/reports zricethezav/gitleaks:latest detect --source /repo --config /repo/.gitleaks.toml --report-format json --report-path /reports/gitleaks.json --no-git
docker run --pull=never --rm -v "$PWD/secret-scan-fixtures:/repo:ro" trufflesecurity/trufflehog:latest filesystem --no-verification --json /repo > /tmp/secret-scan-reports/trufflehog.jsonl
docker run --pull=never --rm -v "$PWD/secret-scan-fixtures:/repo:ro" -v /tmp/secret-scan-reports:/reports aquasec/trivy:latest fs --scanners secret --format json --output /reports/trivy.json /repo
python3 secret-scan-fixtures/scripts/validate_findings.py /tmp/secret-scan-reports/gitleaks.json /tmp/secret-scan-reports/trufflehog.jsonl /tmp/secret-scan-reports/trivy.json
```

Gitleaks exited 1 because findings were present. Its exit status can also represent an execution/configuration error, so review its report and log. The other tools completed with exit 0 while still producing findings. Report files remain in `/tmp/secret-scan-reports` in this workspace.

## Findings and limitations

- Gitleaks did not detect/map GITHUB-004 (fine-grained PAT), API-005/007/011/012, JWT-003, K8S-003, PASS-004/006/009. It detected/mapped 61 other fixture IDs. The 84 raw findings include built-in and custom rules.
- TruffleHog’s five results were JDBC, PostgreSQL, and MongoDB detector findings. Four fixture IDs mapped; broad generic assignments and provider-shaped values were not reported by this run. Verification remained disabled.
- Trivy reported 16 findings, including AWS, GitHub, JWT, Slack, Stripe, and Terraform-shaped patterns. Ten fixture IDs mapped; the other positive fixtures were not detected in this run.
- The malformed key fixtures were detected by Gitleaks’ custom header rule; this does not demonstrate that all scanners parse invalid key material.
- These are results for the installed image versions and filesystem scan only. Behavior may differ with other versions, filesystem conditions, or detector configuration.
