# Healthcare EDI Ingestion – SDLC & DevOps Practices

## 1. Purpose

Define standardized software delivery lifecycle (SDLC), branching, quality gates, and deployment automation processes for the EDI ingestion platform (IaC, Data Factory assets, Functions, configuration artifacts).

## 2. Source Control Structure

| Area | Repo / Path | Notes |
|------|-------------|-------|
| Infrastructure (Bicep) | `/infra/bicep` | Modules + main template |
| Terraform (optional) | `/infra/terraform` | Only if multi-cloud needed |
| ADF Pipelines (exported) | `/adf` | JSON artifacts versioned |
| Function Code | `/src/functions/validation` | Custom validators |
| Config (partners) | `/config/partners` | JSON/Delta partner registry |
| Docs | `/docs` | Living architecture & runbooks |

## 3. Branching Model

| Branch | Purpose | Policies |
|--------|---------|----------|
| `main` | Production-ready state | Protected, PR only, blocked on checks |
| `develop` (optional) | Integration of features | Nightly test deploy |
| `feature/*` | Feature or fix branches | Short-lived, rebase/merge develop |
| `hotfix/*` | Urgent production fixes | Branch from main, fast-track |

## 4. Pull Request Requirements

- Minimum 2 reviewers (infra + data engineering) for IaC & pipeline logic.
- Required automated checks:
  - Bicep compile & linter
  - Security scan (PSRule / Checkov)
  - Unit tests (Functions)
  - `what-if` (dev) result posted as comment
  - Secret scan (pre-commit + CI)
- PR template sections: Summary, Risk, Rollback plan, Testing evidence.

## 5. Versioning & Releases

| Artifact | Version Scheme | Mechanism |
|----------|----------------|-----------|
| IaC templates | Semantic (MAJOR.MINOR.PATCH) | Git tag + release notes |
| ADF pipelines | Incremental commit hash reference | Export job serializes JSON |
| Function code | Semantic | CI builds package artifact |
| Partner config | Date-based incremental (YYYYMMDD.N) | Reviewed like code |

## 6. CI Pipelines (Illustrative)

### 6.1 Infrastructure CI (`infra_ci.yml`)

Steps:
 
1. Checkout
2. Bicep build + lint
3. PSRule / Checkov security scan
4. What-if against dev RG (no apply)
5. Publish artifact (bicep + parameter hash)

### 6.2 Function App CI (`func_ci.yml`)

Steps:
 
1. Restore deps
2. Run unit tests (coverage gate >=80%)
3. Static analysis (bandit/ESLint depending on language)
4. Build package (zip)
5. Publish artifact

### 6.3 Data Factory Export (`adf_export_pipeline.yml`)

- On changes in ADF repo or manual trigger: run export script (ARM template or pipeline JSON per object) into `/adf` then open PR if diff.

## 7. CD Pipelines

| Stage | Activities | Gates |
|-------|-----------|-------|
| Dev | Deploy IaC artifact; deploy Functions; import ADF JSON; run smoke tests | Automatic |
| Test | Reuse artifact; `what-if`; integration tests (synthetic file ingest); security baseline check | Manual approval |
| Prod | `what-if`; deploy; post-deploy validation; notify stakeholders | Manual approval (Change Mgmt) |

Rollback: Redeploy last known good artifact (tag reference) + revert config.

## 8. Testing Strategy

| Layer | Test Types | Tools |
|-------|-----------|-------|
| Unit (Functions) | Logic branches, validators | xUnit/pytest/jest |
| Integration | Event → pipeline → raw path verification | Test harness script + Azure SDK |
| Performance | Burst upload simulation | Locust / custom script |
| Security | Policy & RBAC enforcement tests | Azure CLI / PSRule |
| Chaos (optional) | Simulate transient failures | Scripted fault injection |

## 9. Quality Gates

| Gate | Threshold |
|------|----------|
| Unit test coverage | >=80% |
| Lint errors | 0 blocking |
| Critical security findings | 0 before merge |
| What-if unexpected changes | Must be adjudicated |
| Policy compliance | 100% required |

## 10. Configuration Management

- Partner config changes follow same PR + review path.
- Feature flags (Key Vault/App Config) updated via IaC when possible; runtime emergency toggles logged.
- Maintain changelog for partner onboarding.

## 11. Observability in SDLC

| Aspect | Implementation |
|--------|---------------|
| Pipeline metrics | Azure DevOps/GitHub built-in + export to Log Analytics (optional) |
| Release annotations | Post-deploy script writes annotation to Log Analytics dashboard |
| Deployment hash | Stored as tag on root resource group and in metadata file |

## 12. Security Integration in DevOps

- Dependency scanning (Dependabot / Renovate) scheduled weekly.
- Secret scanning pre-commit (detect-secrets) & CI.
- PR security checklist: endpoints, new roles, data exposure changes.

## 13. Release Management

| Activity | Description |
|----------|------------|
| Release Notes | Auto-generated from merged PR titles + manual summary |
| Change Ticket | Auto-linked to deployment pipeline run |
| Freeze Window | Optional (e.g., first business day of month) – prod deploys restricted |

## 14. Documentation Workflow

- Docs stored in `/docs`; updates required for architectural-impacting changes (definition of done includes doc update).
- ADR (Architecture Decision Record) format for significant decisions under `/docs/adr/ADR-<sequence>-<slug>.md`.

## 15. Onboarding & Offboarding

| Process | Steps |
|---------|-------|
| Developer Onboarding | Add to AAD group; clone repo; run bootstrap script; review security training |
| Access Revocation | Remove from AAD group; audit pending approvals |

## 16. Automation Scripts

- `scripts/validate_partner_config.py` – schema & reference checks
- `scripts/synthetic_ingest.ps1` – test file generator & upload
- `scripts/whatif_report.ps1` – summarize daily drift

## 17. Risk Controls in SDLC

| Risk | Control |
|------|--------|
| Unreviewed infra change | PR policy + mandatory what-if output |
| Over-permissive identity | Automated RBAC audit script in CI |
| Drift after hotfix | Post-hotfix reconciliation job compares templates |
| Silent pipeline failure | Alert on CI job failure to engineering channel |

## 18. KPI & Continuous Improvement

| KPI | Target | Action if Missed |
|-----|-------|-----------------|
| Lead time to prod | < 3 days | Value stream mapping |
| Change failure rate | < 5% | Post-mortem & action items |
| MTTR (ingestion pipeline) | < 60 min | Runbook refinement |
| Deployment frequency | Weekly (steady state) | Automate blockers |

## 19. Open Items

- Confirm if develop branch is desired or trunk-based
- Select test harness framework for ingestion integration
- Define ADR template

---
