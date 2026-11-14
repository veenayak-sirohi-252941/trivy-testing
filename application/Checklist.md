# DevSecOps Pipeline - Stage-wise Checklist

**Current Status: In Progress - Ready for Production Enhancement**
- Last Updated: July 25, 2026
- Project: AnzenOps (Pokemon Manager App)

Use this checklist to verify each stage of the pipeline is correctly implemented.

---

## Implemented Stages

### Stage 1: Trigger ✅
- GitHub Actions workflows configured to trigger on `git push` and `pull_request`
- Branches: sirohi, master, Dev

### Stage 2: Secrets Scanning (Pre-Build) ✅
- TruffleHog integrated in `build.yml` workflow
- Scans git history (full history via `fetch-depth: 0`)
- Results output in JSON format
- Not yet blocking on confirmed active secrets

### Stage 3: Build & Unit Test ✅ (Partial)
- Dependency installation: `npm ci` and `pip install`
- Build/compile step: `npm run build`
- Unit tests: Not yet implemented
- Code coverage threshold: Not yet set
- Pipeline BLOCKS: Not configured

### Stage 4: SAST ✅
- SonarQube integration in `build.yml` workflow
- Scan runs on every push/pull_request to sirohi/master/Dev branches
- Quality gate: Not yet configured
- Findings forwarded to DefectDojo: Not yet implemented

### Stage 5: SCA + SBOM ✅
- Trivy configured for dependency scanning
- SBOM generated in CycloneDX format
- SBOM stored as build artifact ✅
- Not yet blocking on Critical CVEs
- Findings forwarded to DefectDojo: Not yet implemented

### Stage 6: Build & Push Container Image ✅
- Multi-stage Dockerfiles for Frontend (Node) and Backend (Python)
- Images pushed to Docker Hub
- Images tagged with: `latest` only
- Image tagged with commit SHA: Not yet implemented
- Image signed with Cosign/Sigstore: Not yet implemented

### Stage 7: Container Image Scan ✅
- Trivy configured for image scanning
- Scans output in CycloneDX format
- Reports uploaded as build artifacts
- Not yet blocking on Critical CVEs with available fix
- Findings forwarded to DefectDojo: Not yet implemented

### Stage 8: IaC Scan ✅
- Trivy IaC scan integrated for Terraform scanning
- Scans for misconfigurations in Terraform code
- Not yet blocking on Critical misconfigurations
- Findings forwarded to DefectDojo: Not yet implemented

### Stage 9: Provision Infrastructure ✅
- ECR repositories configured (anzenops-backend, anzenops-frontend)
- SonarQube running on EC2
- EKS cluster infrastructure ready
- State management: Local only (no S3 backend)
- State locking: Not configured

### Stage 10: Deploy to Staging ✅
- Kubernetes manifests ready in `k8s/` directory
- Staging deployment via `deploy_k8s.sh`
- LoadBalancer service for frontend
- Cleanup via `destroy_k8s.sh`
- Health checks: Not yet configured
- Staging URL: Published via LoadBalancer

### Stage 11: DAST ✅ (Basic)
- OWASP ZAP scan in `build.yml` workflow
- Baseline scan against staging URL (LoadBalancer endpoint)
- Not yet blocking on Critical vulnerabilities
- Findings forwarded to DefectDojo: Not yet implemented

### Stage 12: Security Gates (OPA) ❌
- Not yet implemented (commented out in workflow)
- OPA policies: Not defined
- Aggregation gate: Not configured

### Stage 13: Deploy to Production ❌
- Not yet implemented (commented out in workflow)
- EKS/ECS deployment: Not configured
- Canary/blue-green strategy: Not defined
- SHA-256 digest verification: Not implemented
- Auto-rollback: Not configured

### Stage 14: Monitor & Manage ❌
- Not yet implemented (commented out in workflow)
- DefectDojo: Not configured
- ELK Stack: Not configured
- Prometheus/Grafana: Configured in EKS via Helm kube-prometheus-stack

### Infrastructure ✅
- ECR repositories configured (anzenops-backend, anzenops-frontend)
- SonarQube running on EC2 (t3.large)
- Kubernetes manifests ready in `k8s/` and `Deploy/` directories
- Budget alert configured for $15/month

### Not Yet Implemented
- Pipeline blocking gates (all stages)
- DefectDojo integration (all stages)
- OPA security gates
- Production deployment (EKS/ECS)
- Image signing (Cosign/Sigstore)
- Image tagging with commit SHA
- Scheduled cron runs
- PR-only workflow triggers
- Remote state in S3
- State locking via DynamoDB

## 1. Trigger

- [x] GitHub Actions workflow configured to trigger on `git push`
- [x] GitHub Actions workflow configured to trigger on Pull Request
- [ ] Scheduled cron run configured (if required)
- [ ] Argo CD watching correct repo/branch

## 2. Secrets Scanning (Pre-Build)

- [x] TruffleHog integrated as first pipeline step
- [ ] GitHub Secret Scanning enabled on repo
- [ ] Pipeline configured to BLOCK on any confirmed active secret
- [ ] Process defined to rotate/revoke secret immediately on detection
- [ ] Findings forwarded to DefectDojo
- [x] Confirmed: git history also covered (not just latest commit)

## 3. Build & Unit Test

- [x] Dependency installation step configured (npm ci, pip install)
- [x] Build/compile step configured (npm run build)
- [ ] Unit tests run automatically
- [ ] Code coverage threshold set to >= 80%
- [ ] Pipeline BLOCKS if coverage < 80%
- [ ] Failure notifications configured

## 4. SAST - Static Application Security Testing

- [x] SonarQube / SonarCloud integrated with CI
- [ ] Quality gate configured (Critical/High = block)
- [ ] Findings forwarded to DefectDojo
- [x] Scan runs on every push/PR

## 5. SCA + SBOM

- [x] Trivy configured for dependency scanning
- [x] SBOM generated (CycloneDX format)
- [x] SBOM stored/archived as build artifact
- [ ] Pipeline BLOCKS on Critical CVEs
- [ ] Findings forwarded to DefectDojo

## 6. Build & Push Container Image

- [x] Multi-stage Dockerfile in place (Frontend & Backend)
- [ ] Image tagged with commit SHA
- [x] Image pushed to Docker Hub (or registry)
- [ ] Image signed using Cosign/Sigstore
- [ ] Signature verification step documented

## 7. Container Image Scan

- [x] Trivy configured for image scanning
- [ ] Checks for: CVEs, root user, embedded secrets, misconfigs
- [ ] Pipeline BLOCKS on Critical CVE with available fix
- [ ] Findings forwarded to DefectDojo

## 8. IaC Scan

- [x] tfsec integrated for Terraform scanning (using Trivy config scanner)
- [ ] Checks for: public S3 buckets, wildcard IAM, insecure configs
- [ ] Pipeline BLOCKS on Critical misconfiguration
- [ ] Findings forwarded to DefectDojo

## 9. Provision Infrastructure

- [x] Terraform code organized (ecr.tf, sonarqube.tf)
- [ ] Remote state configured in S3
- [ ] State locking configured via DynamoDB
- [ ] Sentinel policy-as-code checks in place
- [ ] Flow followed: fmt -> validate -> plan -> apply
- [ ] Decision documented: persistent infra (ECR, SonarQube, EKS)
- [ ] Scheduled job: Not yet implemented

## 10. Configuration Management

- [ ] Ansible playbooks created for server hardening
- [ ] Root SSH login disabled
- [ ] Fail2ban installed and configured
- [ ] Auditd installed and configured
- [ ] CIS benchmark hardening applied
- [ ] Secrets managed via Ansible Vault
- [ ] Decision documented: per-pipeline vs scheduled drift-correction run

## 11. Deploy to Staging

- [x] Kubernetes manifests / Helm charts prepared
- [ ] Staging environment isolated from production
- [ ] Synthetic/non-production data used
- [ ] Rolling deployment strategy configured
- [ ] Health checks configured post-deploy
- [ ] Staging URL published for testing (LoadBalancer)

## 12. DAST - Dynamic Application Security Testing

- [x] OWASP ZAP configured against staging URL
- [ ] Scans for: SQLi, XSS, CSRF, SSRF, missing headers, broken auth
- [ ] Pipeline BLOCKS on Critical runtime vulnerability
- [ ] Findings forwarded to DefectDojo

## 13. Security Gates (Final Checkpoint - OPA)

- [ ] OPA policies defined for final aggregation gate
- [ ] Check: Zero Critical CVEs (from Stages 5, 7)
- [ ] Check: No exposed secrets (from Stage 2)
- [ ] Check: No root containers (UID 0) (from Stage 7)
- [ ] Check: No wildcard IAM permissions (from Stage 8)
- [ ] Check: No SQLi/RCE findings from DAST (Stage 12)
- [ ] On failure: pipeline blocked
- [ ] On failure: ticket auto-created
- [ ] On failure: team notified

## 14. Deploy to Production

- [ ] Deployment target configured (ECS / EKS)
- [ ] AWS CodeDeploy configured
- [ ] Canary strategy configured (5% -> 25% -> 50% -> 100%) OR
- [ ] Blue-green strategy configured (deploy green, health check, switch, remove blue)
- [ ] SHA-256 image digest verification step in place
- [ ] Auto-rollback on failure configured
- [ ] Direct SSH into containers disabled/blocked

## 15. Monitor & Manage

- [ ] DefectDojo dashboard set up for findings/CVE/MTTR tracking
- [ ] ELK Stack configured for log aggregation and search
- [ ] Prometheus configured for metrics collection and alerting
- [ ] Grafana dashboards created for visualization
- [ ] Alerting rules defined (Critical findings, failed deploys, etc.)

---

## Cross-Stage / Overall Checks

- [ ] All DefectDojo-forwarding stages (2, 4, 5, 7, 8, 12) verified to actually push findings
- [ ] Severity levels mapped consistently across all tools into DefectDojo
- [ ] Pipeline-blocking gates tested with intentionally vulnerable code/commits
- [ ] Documentation reflects ephemeral vs persistent infra decision (Stages 9-10)
- [ ] Rollback tested end-to-end (Stage 14)
- [ ] Runbook/playbook exists for "pipeline blocked" scenarios at each gate

---

## Recent Updates (July 25, 2026)

### New Implementations:
- [x] PR trigger configuration added to build.yml workflow
- [x] IaC scanning (Trivy config) added to build.yml workflow
- [x] SBOM stored as build artifact
- [x] Container image scanning reports stored as build artifact

### Pending Enhancements:
- [ ] Pipeline blocking gates on all security checks
- [ ] DefectDojo integration across all stages
- [ ] OPA security gates for final checkpoint
- [ ] Production deployment configuration (canary/blue-green)
- [ ] Image tagging with commit SHA
- [ ] Image signing with Cosign/Sigstore
- [ ] Health checks in staging deployment
- [ ] Scheduled cron runs for infrastructure provisioning
