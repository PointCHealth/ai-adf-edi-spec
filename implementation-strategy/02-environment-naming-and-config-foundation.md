# 02 - Environment Naming & Configuration Foundation Prompt

---
## Prompt
You are designing a deterministic, scalable environment naming and configuration foundation for the EDI routing platform. Build on outputs from `01-tooling-and-credential-acquisition.md`.

### Objectives
1. Define global naming contract components & allowed character sets
2. Produce canonical naming patterns for: Management Groups, Subscriptions, Resource Groups, Key Vaults, Storage, Service Bus, Function Apps, App Config, Log Analytics, Application Insights, Container Registries
3. Provide environment layering model (dev/test/prod + optional sandboxes) & promotion flow
4. Specify configuration segregation strategy (static IaC parameters vs dynamic runtime config vs secrets)
5. Define tagging schema (Key -> Value rules) referencing `docs/09-tagging-governance-spec.md`
6. Outline Azure Policy assignment plan binding to scopes & environments
7. Deliver JSON schemas for: naming tokens, environment metadata, resource logical model
8. Provide collision & drift detection approach (scripts or policy suggestions)

### Constraints
- All names must be reversible-parsable into tokens
- Avoid exceeding Azure length constraints
- Prefer short deterministic abbreviations (e.g., `sbx`, `dev`, `tst`, `prd`)
- Tag values must be stable & automation-friendly (no spaces unless required)

### Required Output Sections
1. Naming Token Glossary
2. Naming Pattern Table (Resource Type | Pattern | Example)
3. Environment Layering & Promotion Model
4. Configuration Segregation Strategy
5. Tagging Schema & Enforcement
6. Policy Assignment Plan
7. JSON Schemas
8. Drift & Collision Detection Strategy
9. Open Questions

### Acceptance Criteria
- Every resource type pattern includes at least one worked example
- JSON schemas validate token structure & environment descriptors
- Policy plan maps each policy to a scope & rationale
- Tagging schema covers ownership, cost, data classification, environment, workload

### Variable Placeholders
- ORG_CODE = <org code>
- WORKLOAD_CODE = edi
- ENVIRONMENTS = [dev,test,prod]
- REGION_PRIMARY = <azure region short>

Return only the structured output sections.

---
## Usage
Use after completion of Tooling & Credential Acquisition. Replace placeholders then run with AI assistant.
