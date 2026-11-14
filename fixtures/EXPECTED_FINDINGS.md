# Fixture detection matrix (actual scan status)

Statuses are from the local Docker image runs recorded in `SCANNER_RESULTS.md`. `DETECTED` means a report finding was mapped to the fixture line. `NOT DETECTED` is an observed result, not a support guarantee. Negative fixtures are reported separately.

| Fixture ID | Credential Type | File Location | Gitleaks | TruffleHog | Trivy | Purpose |
|---|---|---|---|---|---|---|
| AWS-001 | AWS access key | `.env.example` | DETECTED | NOT DETECTED | NOT DETECTED | AWS access key |
| AWS-002 | AWS access key | `aws/credentials.env` | DETECTED | NOT DETECTED | DETECTED | AWS access key |
| AWS-003 | AWS credentials | `aws/aws-config.json` | DETECTED | NOT DETECTED | DETECTED | AWS credentials |
| AWS-004 | AWS access key | `src/config/db.py` | DETECTED | NOT DETECTED | DETECTED | AWS access key |
| AWS-005 | AWS secret key | `aws/credentials.env` | DETECTED | NOT DETECTED | NOT DETECTED | AWS secret key |
| GITHUB-001 | classic token shape | `github/github.env` | DETECTED | NOT DETECTED | NOT DETECTED | classic token shape |
| GITHUB-002 | OAuth token shape | `github/github.env` | DETECTED | NOT DETECTED | DETECTED | OAuth token shape |
| GITHUB-003 | npm token shape | `github/.npmrc` | DETECTED | NOT DETECTED | DETECTED | npm token shape |
| GITHUB-004 | fine grained token shape | `.env.staging.example` | DETECTED | NOT DETECTED | NOT DETECTED | fine grained token shape |
| DB-001 | PostgreSQL URI | `docker-compose.yml` | DETECTED | DETECTED | NOT DETECTED | PostgreSQL URI |
| DB-002 | Postgres password | `docker-compose.yml` | DETECTED | NOT DETECTED | NOT DETECTED | Postgres password |
| DB-003 | PostgreSQL URI | `config/application.yaml` | DETECTED | NOT DETECTED | NOT DETECTED | PostgreSQL URI |
| DB-004 | Postgres password | `database/postgres.env` | DETECTED | NOT DETECTED | NOT DETECTED | Postgres password |
| DB-005 | MongoDB URI | `src/config/db.py` | DETECTED | DETECTED | NOT DETECTED | MongoDB URI |
| DB-006 | database password | `src/config/db.py` | DETECTED | NOT DETECTED | NOT DETECTED | database password |
| DB-007 | PostgreSQL URI | `database/postgres.env` | DETECTED | NOT DETECTED | NOT DETECTED | PostgreSQL URI |
| DB-008 | MySQL password | `database/mysql.env` | DETECTED | NOT DETECTED | NOT DETECTED | MySQL password |
| DB-009 | MySQL URI | `database/mysql.env` | DETECTED | NOT DETECTED | NOT DETECTED | MySQL URI |
| DB-010 | Postgres YAML password | `database/database.yml` | DETECTED | NOT DETECTED | NOT DETECTED | Postgres YAML password |
| DB-011 | Postgres properties password | `database/connection.properties` | DETECTED | DETECTED | NOT DETECTED | Postgres properties password |
| DB-012 | database password | `k8s/prod/secrets.yaml` | DETECTED | NOT DETECTED | NOT DETECTED | database password |
| PASS-001 | Python password | `src/services/auth_service.py` | DETECTED | NOT DETECTED | NOT DETECTED | Python password |
| PASS-002 | YAML password | `config/application.yaml` | DETECTED | NOT DETECTED | NOT DETECTED | YAML password |
| PASS-003 | JSON password | `config/config.json` | DETECTED | DETECTED | NOT DETECTED | JSON password |
| PASS-004 | Compose password | `docker-compose.yml` | DETECTED | NOT DETECTED | NOT DETECTED | Compose password |
| API-001 | API key | `src/utils/api_client.py` | DETECTED | NOT DETECTED | NOT DETECTED | API key |
| API-002 | third party key | `src/utils/api_client.py` | DETECTED | NOT DETECTED | NOT DETECTED | third party key |
| API-003 | API secret | `src/utils/api_client.py` | DETECTED | NOT DETECTED | NOT DETECTED | API secret |
| API-004 | Stripe test-shaped key | `src/utils/api_client.py` | DETECTED | NOT DETECTED | NOT DETECTED | Stripe test-shaped key |
| API-005 | Slack token shape | `src/utils/api_client.py` | NOT DETECTED | NOT DETECTED | DETECTED | Slack token shape |
| API-006 | Bearer token | `src/utils/api_client.py` | DETECTED | NOT DETECTED | NOT DETECTED | Bearer token |
| API-007 | service auth token | `src/services/auth_service.py` | NOT DETECTED | NOT DETECTED | NOT DETECTED | service auth token |
| API-008 | client secret | `config/application.yaml` | DETECTED | NOT DETECTED | NOT DETECTED | client secret |
| API-009 | API key | `api/api-keys.env` | DETECTED | NOT DETECTED | NOT DETECTED | API key |
| API-010 | service API key | `api/api-keys.env` | DETECTED | NOT DETECTED | NOT DETECTED | service API key |
| API-011 | auth token | `api/api-keys.env` | NOT DETECTED | NOT DETECTED | NOT DETECTED | auth token |
| API-012 | access token | `api/api-keys.env` | NOT DETECTED | NOT DETECTED | NOT DETECTED | access token |
| API-013 | client secret | `api/api-keys.env` | DETECTED | NOT DETECTED | NOT DETECTED | client secret |
| API-014 | Authorization bearer | `api/authorization-example.sh` | DETECTED | NOT DETECTED | NOT DETECTED | Authorization bearer |
| API-015 | client secret | `k8s/prod/secrets.yaml` | DETECTED | NOT DETECTED | NOT DETECTED | client secret |
| SSH-001 | malformed OpenSSH block | `scripts/provision_infrastructure.sh` | DETECTED | NOT DETECTED | NOT DETECTED | malformed OpenSSH block |
| SSH-002 | malformed RSA block | `scripts/provision_infrastructure.sh` | DETECTED | NOT DETECTED | NOT DETECTED | malformed RSA block |
| SSH-003 | malformed PGP block | `scripts/provision_infrastructure.sh` | DETECTED | NOT DETECTED | NOT DETECTED | malformed PGP block |
| JWT-001 | JWT shape | `api/request.json` | DETECTED | NOT DETECTED | DETECTED | JWT shape |
| JWT-002 | JWT shape | `src/services/auth_service.py` | DETECTED | NOT DETECTED | DETECTED | JWT shape |
| JWT-003 | auth token | `config/application.yaml` | NOT DETECTED | NOT DETECTED | NOT DETECTED | auth token |
| JWT-004 | JWT bearer shape | `.env.staging.example` | DETECTED | NOT DETECTED | NOT DETECTED | JWT bearer shape |
| TF-001 | database password | `infra/terraform/variables.tfvars` | DETECTED | NOT DETECTED | NOT DETECTED | database password |
| TF-002 | API key | `infra/terraform/variables.tfvars` | DETECTED | NOT DETECTED | NOT DETECTED | API key |
| TF-003 | registry password | `infra/terraform/variables.tfvars` | DETECTED | NOT DETECTED | NOT DETECTED | registry password |
| TF-004 | deployment token | `infra/terraform/variables.tfvars` | DETECTED | NOT DETECTED | NOT DETECTED | deployment token |
| TF-005 | infrastructure API secret | `infra/terraform/variables.tfvars` | DETECTED | NOT DETECTED | NOT DETECTED | infrastructure API secret |
| TF-006 | AWS access key | `infra/terraform/variables.tfvars` | DETECTED | NOT DETECTED | DETECTED | AWS access key |
| K8S-001 | dev password | `k8s/dev/secrets.yaml` | DETECTED | NOT DETECTED | NOT DETECTED | dev password |
| K8S-002 | staging password | `k8s/staging/secrets.yaml` | DETECTED | NOT DETECTED | NOT DETECTED | staging password |
| K8S-003 | staging API token | `k8s/staging/secrets.yaml` | NOT DETECTED | NOT DETECTED | NOT DETECTED | staging API token |
| GITHUB-005 | GitHub PAT documentation example | `docs/setup-runbook.md` | DETECTED | NOT DETECTED | NOT DETECTED | GitHub PAT documentation example |
| PASS-005 | DB_PASSWORD assignment | `src/services/auth_service.py` | DETECTED | NOT DETECTED | NOT DETECTED | DB_PASSWORD assignment |
| PASS-006 | ADMIN_PASSWORD assignment | `src/services/auth_service.py` | DETECTED | NOT DETECTED | NOT DETECTED | ADMIN_PASSWORD assignment |
| PASS-007 | SECRET assignment | `src/services/auth_service.py` | DETECTED | NOT DETECTED | NOT DETECTED | SECRET assignment |
| PASS-008 | DATABASE_PASSWORD assignment | `src/services/auth_service.py` | DETECTED | NOT DETECTED | NOT DETECTED | DATABASE_PASSWORD assignment |
| PASS-009 | lowercase admin_password assignment | `src/services/auth_service.py` | DETECTED | NOT DETECTED | NOT DETECTED | lowercase admin_password assignment |
| PASS-010 | CLIENT_SECRET assignment | `src/services/auth_service.py` | DETECTED | NOT DETECTED | NOT DETECTED | CLIENT_SECRET assignment |
| PASS-011 | lowercase secret assignment | `src/services/auth_service.py` | DETECTED | NOT DETECTED | NOT DETECTED | lowercase secret assignment |
| PASS-012 | shell client_secret assignment | `scripts/deploy.sh` | DETECTED | NOT DETECTED | NOT DETECTED | shell client_secret assignment |
| PASS-013 | documented properties password | `docs/setup-runbook.md` | DETECTED | NOT DETECTED | NOT DETECTED | documented properties password |
| PASS-014 | admin_password assignment | `config/application.properties` | DETECTED | NOT DETECTED | NOT DETECTED | admin_password assignment |
| PASS-015 | DATABASE_PASSWORD assignment | `config/application.properties` | DETECTED | NOT DETECTED | NOT DETECTED | DATABASE_PASSWORD assignment |
| API-016 | workflow API key fixture | `.github/workflows/build.yml` | DETECTED | NOT DETECTED | NOT DETECTED | workflow API key fixture |
| JWT-005 | workflow JWT-shaped value | `.github/workflows/build.yml` | DETECTED | NOT DETECTED | DETECTED | workflow JWT-shaped value |
| AWS-006 | AWS secret access key | `src/config/db.py` | DETECTED | NOT DETECTED | NOT DETECTED | AWS secret access key |
| NEG-001 | Environment references and obvious placeholders | `tests/fixtures/negative/placeholders.env` | NOT DETECTED | NOT DETECTED | NOT DETECTED | Negative false-positive check |
| NEG-002 | YAML environment references | `tests/fixtures/negative/placeholders.yaml` | NOT DETECTED | NOT DETECTED | NOT DETECTED | Negative false-positive check |
