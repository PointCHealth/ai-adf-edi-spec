# 09 - CI/CD Pipeline Automation Prompt

---

## Prompt

You are designing automated build, test, security scan, and deployment pipelines for the EDI platform.

### Context Inputs

- IaC strategy: `docs/04-iac-strategy-spec.md`
- GitHub Actions implementation guide: `docs/04a-github-actions-implementation.md`
- SDLC & DevOps practices: `docs/05-sdlc-devops-spec.md`
- Tagging & governance reference: `docs/09-tagging-governance-spec.md`

### Objectives

1. Define pipeline stages (validate, build, test, security-scan, package, deploy-infra, deploy-app, post-verify, promote)
2. Provide stage responsibilities & success criteria
3. Outline branching & release strategy (main, release branches, hotfix, feature)
4. Specify artifact packaging & versioning (containers, function zips, infra module versions)
5. Integrate security & quality gates (SAST, dependency, secret scan, IaC scan, license compliance)
6. Define environment promotion workflow & approvals
7. Provide rollback automation approach (infra & app)
8. Include sample YAML pipeline skeleton(s) (GitHub Actions) with reusable templates
9. Map required service connections / credentials & scopes
10. Supply pipeline observability & DORA metrics capture approach

### Constraints

- Pipelines must be idempotent & self-descriptive
- Secrets consumed from Key Vault or secure store references only
- Failing quality gates block downstream deployment stages
- Reusable templates for repeated logic (e.g., scanning)

### Required Output Sections

1. Stage Overview Table
2. Branching & Release Strategy
3. Artifact Packaging & Versioning
4. Security & Quality Gates
5. Promotion & Approval Workflow
6. Rollback Automation Strategy
7. Sample Pipeline Skeleton(s)
8. Service Connections & Permissions Map
9. Pipeline Observability & Metrics Plan
10. Open Questions

### Acceptance Criteria

- Every stage has clear entry/exit criteria
- Security gates positioned before deployment stages
- Pipeline skeleton includes caching, parallelism where beneficial
- Rollback differentiates infra vs app strategy
- Reference `docs/04a-github-actions-implementation.md` §5 for production-ready workflow templates (Infrastructure CI/CD, Function CI/CD, Drift Detection)

### Variable Placeholders

- CONTAINER_REGISTRY = `<registry name>`
- BUILD_ID = `<build identifier pattern>`
- ARTIFACT_RETENTION_DAYS = `<number>`

Return only the structured output sections.

---

## Usage

Use once service implementation patterns & tests established. Provide placeholders & run with AI assistant.
