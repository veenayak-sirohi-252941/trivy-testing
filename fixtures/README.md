# Secret Scan Fixtures

> **WARNING: This repository intentionally contains fake credentials for secret-scanner testing. It is not a production project. Never deploy, authenticate, or reuse any of these values.**

This standalone corpus compares Gitleaks, TruffleHog, and Trivy against synthetic fixtures across code, application settings, cloud config, containers, Terraform, Kubernetes, shell, and workflows. Each planted case has a unique ID in `EXPECTED_FINDINGS.md` and the fixture catalog. No value is for authentication. No verifier is permitted.

Secret scanning finds exposed-looking values in files and history. Installation provides a scanner binary; execution runs it against a chosen source. Built-in rules ship with tools; custom rules are in `.gitleaks.toml`. Detection is pattern inspection. Credential verification attempts authentication and is disabled here. Negative cases test false positives.

## Layout and use

`src/` is illustrative Python; `config/`, `database/`, `aws/`, and `github/` hold application settings; `infra/terraform/`, `k8s/`, Docker files, and scripts cover infrastructure; `docs/` explains setup. These are examples only. Never deploy them.

Install tools only by following their official instructions: [Gitleaks](https://github.com/gitleaks/gitleaks), [TruffleHog](https://github.com/trufflesecurity/trufflehog), [Trivy](https://github.com/aquasecurity/trivy). Check `gitleaks version`, `trufflehog --version`, and `trivy --version`. No software is installed by this project.

The three images can be run without pulling them. From this directory:

```sh
./scripts/run_secret_scans_docker.sh
```

This checks the local image tags, runs each scanner independently with `--pull=never`, saves reports under `/tmp/secret-scan-fixtures-reports`, and compares report locations to fixture IDs. TruffleHog runs with `--no-verification`. Gitleaks' exit code 1 can indicate findings; review the report and log. The individual `docker run` commands and actual image versions/results are recorded in `SCANNER_RESULTS.md`. For host-installed binaries instead, `scripts/run_secret_scans.sh` is also available.

## Workflows and limitations

`build.yml` checks syntax and tests. `deploy.yml` is a manual no-op. `secret-scan-test.yml` runs three isolated read-only jobs with minimal permissions and no repository credentials. TruffleHog verification is disabled. Current actual mapped results are in `EXPECTED_FINDINGS.md`; `SCANNER_RESULTS.md` explains the raw counts, missed patterns, and limitations for these image versions. Invalid key bodies may not satisfy parsers; provider token detectors may reject synthetic token shapes; generic password support varies.

To add cases, use nonfunctional values, give each a unique ID, update the catalog and expected matrix, and add obvious placeholders under `tests/fixtures/negative/`. Never add real credentials. To push, create an empty remote then run `git init -b main`, `git add .`, review, commit, `git remote add origin <new-repo-url>`, and `git push -u origin main` from this directory. This project has not been pushed.
