# 05 - Infrastructure Deployment Execution Prompt

---
## Prompt
You are orchestrating first-time and repeatable environment deployments using Bicep modules defined in prior planning. Focus on reliability, idempotency, traceability.

### Objectives
1. Produce deployment runbook (phases, pre-checks, post-validation)
2. Define parameter files strategy per environment & secret resolution mechanics
3. Provide deployment scripts outline (PowerShell & Bash) including What-If usage
4. Enumerate pre-flight validation commands (subscriptions, role assignments, policy compliance)
5. Specify retry logic & partial failure recovery steps
6. Identify required manual approvals / gates
7. Outline artifact versioning & release tagging approach
8. Provide post-deploy verification matrix (Resource | Validation Command | Expected State)
9. Deliver rollback / remediation strategies (module-level, resource-level)
10. Capture deployment telemetry (where & how logged)

### Constraints
- All deployments must be idempotent; subsequent run yields no changes
- Use `az deployment sub|group what-if` prior to actual apply
- Secrets never written to logs
- Scripts exit non-zero on any failed validation

### Required Output Sections
1. Deployment Runbook Overview
2. Parameter & Secret Management Strategy
3. Script Structure (PowerShell & Bash)
4. Pre-flight Validation Checklist
5. Execution Flow with Gates & Approvals
6. Post-deployment Verification Matrix
7. Retry & Failure Recovery
8. Rollback Strategy
9. Telemetry & Logging
10. Open Questions

### Acceptance Criteria
- Pre-flight list includes policy & RBAC validation
- Verification matrix covers all critical services
- Rollback differentiates between destructive & non-destructive paths
- Script structure shows modular functions / tasks

### Variable Placeholders
- ENV = <environment>
- SUBSCRIPTION_ID = <guid>
- DEPLOYMENT_TAG = <semantic version or timestamp>
- PARAM_FILE = <path to bicep parameter json>

Return only the structured output sections.

---
## Usage
Run after infrastructure plan is validated & modules ready. Provide placeholders and execute through AI.
