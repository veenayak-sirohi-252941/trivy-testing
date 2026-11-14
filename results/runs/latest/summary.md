# Scanner comparison

Run: `latest`

| Metric | Gitleaks | TruffleHog | Trivy |
|---|---:|---:|---:|
| Raw findings | 174 | 10 | 18 |
| Unique positive fixtures mapped | 35 | 3 | 6 |
| Expected positive fixtures missed | 44 | 76 | 73 |
| Negative cases reported | 8 | 1 | 1 |
| Unmatched findings | 73 | 3 | 2 |
| Inconclusive mappings | 21 | 0 | 8 |
| Execution errors | 0 | 0 | 0 |

## Execution status

- gitleaks: COMPLETED; raw findings 174
- trufflehog: COMPLETED; raw findings 10
- trivy: COMPLETED; raw findings 18

## Missed positive fixtures

- gitleaks: API-001, API-002, API-003, API-006, API-007, API-009, API-010, API-011, API-013, API-015, API-046, API-047, API-048, AWS-002, AWS-003, AWS-004, AWS-005, AWS-006, DB-003, DB-004, DB-006, DB-007, DB-008, DB-009, DB-010, DB-011, DB-012, GITHUB-001, GITHUB-002, GITHUB-004, JWT-002, JWT-004, K8S-002, K8S-003, MYSQL-001, PASS-003, PASS-004, PASS-006, PASS-007, PASS-013, PASS-015, TF-001, TF-002, TF-003
- trufflehog: API-001, API-002, API-003, API-004, API-005, API-006, API-007, API-008, API-009, API-010, API-011, API-012, API-013, API-014, API-015, API-016, API-046, API-047, API-048, API-049, AWS-001, AWS-002, AWS-003, AWS-004, AWS-005, AWS-006, AWS-012, DB-002, DB-003, DB-004, DB-005, DB-006, DB-007, DB-008, DB-009, DB-010, DB-011, DB-012, GITHUB-001, GITHUB-002, GITHUB-003, GITHUB-004, GITHUB-005, JWT-001, JWT-002, JWT-003, JWT-004, JWT-005, K8S-001, K8S-002, K8S-003, MYSQL-001, PASS-001, PASS-002, PASS-003, PASS-004, PASS-005, PASS-006, PASS-007, PASS-008, PASS-009, PASS-010, PASS-011, PASS-012, PASS-013, PASS-014, PASS-015, SSH-001, SSH-002, SSH-003, TF-001, TF-002, TF-003, TF-004, TF-005, TF-006
- trivy: API-001, API-002, API-003, API-004, API-005, API-007, API-008, API-009, API-010, API-011, API-012, API-013, API-014, API-015, API-016, API-046, API-047, API-048, API-049, AWS-001, AWS-002, AWS-003, AWS-004, AWS-005, AWS-006, AWS-012, DB-001, DB-002, DB-003, DB-004, DB-006, DB-007, DB-008, DB-009, DB-010, DB-011, DB-012, GITHUB-001, GITHUB-002, GITHUB-004, GITHUB-005, GITHUB-007, JWT-002, JWT-003, JWT-004, K8S-001, K8S-002, K8S-003, MYSQL-001, PASS-001, PASS-002, PASS-003, PASS-004, PASS-005, PASS-006, PASS-007, PASS-008, PASS-009, PASS-010, PASS-011, PASS-012, PASS-013, PASS-014, PASS-015, SSH-001, SSH-002, SSH-003, TF-001, TF-002, TF-003, TF-004, TF-005, TF-006

## Negative cases flagged

- gitleaks: API-050, AWS-011, DOCKER-003, MONGO-001, MYSQL-002, PASS-030, PASS-031, PASS-032
- trufflehog: MONGO-001
- trivy: AWS-011

## Shared and unique detections

- All three: GITHUB-006
- Gitleaks only: API-004, API-005, API-008, API-012, API-014, API-016, API-049, AWS-001, AWS-012, DB-002, GITHUB-005, JWT-003, K8S-001, PASS-001, PASS-002, PASS-005, PASS-008, PASS-009, PASS-010, PASS-011, PASS-012, PASS-014, SSH-001, SSH-002, SSH-003, TF-004, TF-005, TF-006
- TruffleHog only: none
- Trivy only: API-006
- Missed by all: API-001, API-002, API-003, API-007, API-009, API-010, API-011, API-013, API-015, API-046, API-047, API-048, AWS-002, AWS-003, AWS-004, AWS-005, AWS-006, DB-003, DB-004, DB-006, DB-007, DB-008, DB-009, DB-010, DB-011, DB-012, GITHUB-001, GITHUB-002, GITHUB-004, JWT-002, JWT-004, K8S-002, K8S-003, MYSQL-001, PASS-003, PASS-004, PASS-006, PASS-007, PASS-013, PASS-015, TF-001, TF-002, TF-003

## Git history scans

- gitleaks: 218 raw; 17 fixture IDs mapped; 79 unmatched; 0 inconclusive
- trufflehog: 28 raw; 4 fixture IDs mapped; 13 unmatched; 0 inconclusive
- trivy: 0 raw; 0 fixture IDs mapped; 0 unmatched; 0 inconclusive

## Findings requiring review

- Potentially real catalog entries: 61
- Unclassified catalog entries: 0
Values are withheld from this report. Review those source locations with their owners before treating them as fixtures.
