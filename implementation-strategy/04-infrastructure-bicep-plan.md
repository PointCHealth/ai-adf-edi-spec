# 04 - Infrastructure (Bicep) Planning Prompt

---
## Prompt
You are producing a comprehensive infrastructure design & Bicep module plan prior to authoring or extending templates in `infra/bicep/modules`.

### Context Inputs
- Architecture overview: `docs/01-architecture-spec.md`
- Routing architecture: `docs/08-transaction-routing-outbound-spec.md`
- Tagging & governance reference: `docs/09-tagging-governance-spec.md`
- Security & compliance reference: `docs/03-security-compliance-spec.md`

### Objectives
1. Inventory required Azure services & SKUs (Functions, Service Bus with Topics/Subscriptions, Storage, Key Vault, App Config, Log Analytics, Application Insights, Event Grid, Data Factory if applicable, Container Registry, Azure SQL for Control Number Store)
2. Map each logical capability (routing, outbound assembly, control number management, partner portal backend, observability) to resource set & deployment unit
3. Define module boundaries & composition (one module per capability vs shared primitives) with reuse strategy
4. Produce parameter surface per module (mandatory vs optional, secureString vs string)
5. Establish naming alignment with output from environment foundation prompt
6. Include security & networking: private endpoints, firewall rules, identity assignment
7. Provide dependency graph (topological order for deployment)
8. Define idempotency & drift detection approach (what outputs to expose, how to detect change)
9. Suggest test harness approach for modules (what to validate post-deploy)
10. Cost awareness: list cost drivers & right-sizing assumptions

### Constraints
- Avoid over-modularization; prefer cohesive modules delivering a functional slice
- All modules MUST expose standardized outputs: `resourceIds`, `endpoints`, `identityPrincipalIds` where relevant
- Parameters MUST have clear descriptions & defaults where safe
- Security defaults locked down (public network disabled unless explicitly enabled)

### Required Output Sections
1. Service Inventory Table
2. Capability-to-Resource Mapping
3. Module Boundary Definition
4. Module Parameter Specification
5. Security & Networking Plan
6. Deployment Dependency Graph
7. Outputs & Drift Detection Strategy
8. Module Test Harness Plan
9. Cost Considerations
10. Open Questions

### Acceptance Criteria
- Every capability maps to at least one module
- No module lists unused parameters
- Dependency graph is acyclic & deployment order explicit
- Test harness plan includes both functional & guardrail validations

### Variable Placeholders
- ORG_CODE = <org code>
- WORKLOAD_CODE = edi
- ENVIRONMENTS = [dev,test,prod]
- REGION_PRIMARY = <azure region short>

Return only the structured output sections.

---
## Usage
Execute after security bootstrap. Feed prior outputs as context. Replace placeholders before invoking.
