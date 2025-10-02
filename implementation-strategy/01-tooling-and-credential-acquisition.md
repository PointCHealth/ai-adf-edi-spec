# 01 - Tooling & Credential Acquisition Prompt

Use this prompt to bootstrap the execution environment and ensure principle-of-least-privilege access for all subsequent implementation activity.

---
## Prompt
You are an experienced Azure integration platform engineer assisting with an EDI routing & outbound processing platform implementation. Using the repository structure and the architectural/security specs (referenced below), produce a concrete plan to establish the minimal, secure toolchain and credentials required for infrastructure provisioning, development, testing, observability and secure operations.

### Context Inputs
- Repository root structure (summarize salient dirs: `infra/bicep`, `api/partner-portal`, `queries/kusto`, `docs/*`)
- Security & compliance reference: `docs/03-security-compliance-spec.md`
- Architecture overview: `docs/01-architecture-spec.md`
- Operations spec: `docs/06-operations-spec.md`
- Non-functional & risk spec: `docs/07-nfr-risks-spec.md`
- Tagging & governance reference: `docs/09-tagging-governance-spec.md`

### Objectives
1. Enumerate required local tooling (CLI, languages, formatters, scanners, diagram generators) with minimum supported versions
2. Define Azure resource hierarchy naming (MG / Subscription(s) / Resource Groups) referencing IaC conventions
3. Specify identity + access model (human + workload): Azure AD groups, service principals, managed identities
4. Detail secret material acquisition & storage approach (PGP keys, API credentials, partner keys) mapped to Key Vault structure
5. Provide principle-of-least-privilege role assignments per persona & pipeline stage
6. Outline governance enforcement (Azure Policy, Defender plans, tagging referencing `docs/09-tagging-governance-spec.md` if present)
7. Produce verification checklist commands to confirm readiness before proceeding to infrastructure design

### Constraints
- Prefer managed identities over client secrets where possible
- No broad Contributor for automation; use granular roles (e.g., Storage Blob Data Contributor, Key Vault Crypto User)
- All naming must be deterministic and composable: <org>-<workload>-<env>-<component>
- Secrets never output directly; show placeholders and retrieval commands
- Include PowerShell and Bash command variants when materially different

### Required Output Sections
1. Tooling Matrix (markdown table)
2. Azure Resource Hierarchy & Naming Schema
3. Identity & Access Model
4. Secrets & Key Vault Layout
5. RBAC Assignment Plan (table: Principal | Scope | Role | Justification)
6. Governance & Compliance Controls
7. Verification Commands & Checklist
8. Open Questions / Assumptions

### Acceptance Criteria
- Every listed tool has a rationale & version strategy
- No role assignment grants excessive rights relative to stated need
- Verification commands are paste-ready and idempotent
- At least 5 open questions to validate with stakeholders

### Variable Placeholders To Fill Before Running
- ORG_CODE = <short org code>
- WORKLOAD_CODE = edi
- ENVIRONMENTS = dev,test,prod
- LOCATION_PRIMARY = <azure region>
- MG_ROOT = <management group id>
- SUBSCRIPTION_MAP = <table or json of env->subscriptionId>
- KEY_VAULT_NAME_PATTERN = <naming pattern>

Return only the structured output sections, no extraneous commentary.

---
## Usage
Copy everything under the Prompt heading (excluding this Usage section) into the AI assistant and fill placeholders. Iterate until acceptance criteria are confirmed.
