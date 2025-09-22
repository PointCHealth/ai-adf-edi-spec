# 03 - Security & Secrets Bootstrap Prompt

---
## Prompt
You are formalizing the initial security control plane for the EDI platform. Build on naming, RBAC and token models from previous prompts.

### Objectives
1. Define threat model summary (key assets, primary threat actors, top misuse cases) referencing `docs/03-security-compliance-spec.md`
2. Propose layered defensive controls (prevent/detect/respond) across identity, network, data, code, runtime
3. Design secrets strategy: Key Vault segmentation, key rotation policies, secret versioning, PGP key lifecycle (reference `docs/partner-portal/diagrams/pgp-key-lifecycle.mmd`)
4. Provide encryption strategy (at rest, in transit, field-level where applicable)
5. Outline secure baseline for Function Apps, Service Bus, Storage, API endpoints
6. Define perimeter & internal network access patterns (Private Endpoints vs Service Endpoints)
7. Supply automated scanning & policy enforcement (IaC scanning, dependency scanning, secret scanning)
8. Deliver incident response playbook skeleton & logging requirements alignment with `queries/kusto`
9. Provide zero-trust access flows for partner onboarding & key exchange

### Constraints
- No plaintext secrets in pipelines
- All external partner cryptographic material must be integrity-verified
- Continuous verification of managed identity role assignments
- Minimize cross-env lateral movement

### Required Output Sections
1. Threat Model Summary
2. Control Matrix (Domain | Prevent | Detect | Respond)
3. Secrets & Key Management Architecture
4. Encryption Strategy
5. Secure Resource Baselines
6. Network Access Model
7. Scanning & Enforcement Pipeline
8. Incident Response Skeleton
9. Partner Key Exchange Flow
10. Open Questions

### Acceptance Criteria
- Control matrix covers at least 5 domains
- Key lifecycle includes generation, distribution, rotation, revocation, archival
- Incident response skeleton maps log sources to queries
- Partner key exchange includes authenticity & revocation steps

### Variable Placeholders
- KEY_VAULT_ROOT = <kv base name pattern>
- PARTNER_KEY_RETENTION_DAYS = <number>
- ROTATION_INTERVAL_DAYS = <number>

Return only the structured output sections.

---
## Usage
Run after environment foundation is established. Replace placeholders. Provide to AI assistant for structured output.
