# Scanner configuration

Gitleaks loads `.gitleaks.toml` explicitly; built-ins remain enabled. TruffleHog filesystem mode must use `--no-verification`. Trivy uses `fs --scanners secret`; misconfiguration and vulnerability checks are separate. Provider token patterns, generic passwords, malformed keys, and file coverage vary by version. Record actual results only.
