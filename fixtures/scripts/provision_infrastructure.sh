#!/usr/bin/env bash
set -euo pipefail
echo "No infrastructure action is implemented."
# SSH-001 intentionally invalid key fixture
cat <<'KEY'
-----BEGIN OPENSSH PRIVATE KEY-----
not-a-valid-private-key-fixture
-----END OPENSSH PRIVATE KEY-----
KEY
# SSH-002
cat <<'KEY'
-----BEGIN RSA PRIVATE KEY-----
invalid fixture body
-----END RSA PRIVATE KEY-----
KEY
# SSH-003
cat <<'KEY'
-----BEGIN PGP PRIVATE KEY BLOCK-----
invalid PGP fixture
-----END PGP PRIVATE KEY BLOCK-----
KEY
