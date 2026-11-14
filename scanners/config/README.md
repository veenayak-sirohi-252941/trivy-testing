# Scanner configuration

The Gitleaks runner explicitly loads the preserved configuration at `fixtures/.gitleaks.toml`; it is not copied or rewritten. Trivy secret-config autoload is disabled for repeatability, so the verified image's built-in secret rules run. TruffleHog uses built-in detectors and always receives `--no-verification`.

The runner pins the existing local image IDs by default and refuses a different local ID or configured override unless `ALLOW_IMAGE_OVERRIDE=1` is explicitly set. Containers use `--network none`, a read-only source bind mount, and a separate writable report mount.
