# 04 - Infrastructure (Bicep) Planning Prompt

---

## Prompt

You are producing a comprehensive infrastructure design & Bicep module plan for implementing a **5-layer architecture** healthcare EDI processing platform.

### Solution Architecture Context

The platform implements a **layered, domain-driven architecture**:

```text
┌─────────────────────────────────────────────────────────────┐
│                Cross-Cutting Concerns                       │
│         (Security, Observability, Configuration)           │
├─────────────────────────────────────────────────────────────┤
│               Outbound Assembly Layer                       │
│        (Acknowledgment Generation, Control Numbers)        │
├─────────────────────────────────────────────────────────────┤
│              Destination Systems Layer                      │
│     (Eligibility, Claims, Enrollment, Remittance)         │
├─────────────────────────────────────────────────────────────┤
│               Routing & Event Hub Layer                     │
│           (Message Routing, Event Correlation)             │
├─────────────────────────────────────────────────────────────┤
│                 Core Platform Layer                         │
│         (Ingestion, Storage, Infrastructure)               │
└─────────────────────────────────────────────────────────────┘
```

### Context Inputs

- Architecture overview: `docs/01-architecture-spec.md`
- Solution structure guide: `docs/15-solution-structure-implementation-guide.md`
- Routing architecture: `docs/08-transaction-routing-outbound-spec.md`
- Tagging & governance reference: `docs/09-tagging-governance-spec.md`
- Security & compliance reference: `docs/03-security-compliance-spec.md`

### Objectives

1. Inventory required Azure services & SKUs mapped to architectural layers
2. Define module boundaries aligned with domain separation and deployment units
3. Map each logical capability to resource set with clear ownership boundaries
4. Produce parameter surface per module (mandatory vs optional, secureString vs string)
5. Establish naming alignment with environment foundation and layer-specific prefixes
6. Include security & networking: private endpoints, firewall rules, identity assignment per layer
7. Provide dependency graph respecting layer boundaries and deployment order
8. Define idempotency & drift detection approach for layer-based deployment
9. Suggest test harness approach aligned with solution architecture patterns
10. Cost awareness with layer-specific optimization strategies

### Architecture-Specific Requirements

**Layer Isolation**: Each layer should be independently deployable with minimal cross-layer dependencies
**Microservice Boundaries**: Destination systems must be isolated with their own infrastructure modules
**Event-Driven Integration**: Service Bus namespace and topics must support filtered subscriptions
**Control Number Store**: Azure SQL Database with optimistic concurrency for acknowledgment generation
**Security by Design**: Managed Identities per layer with least-privilege RBAC

### Constraints

- Align modules with architectural layers for clear deployment boundaries  
- Each destination system gets its own infrastructure module (independent deployment)
- Shared services (routing, outbound) get dedicated modules
- All modules MUST expose standardized outputs: `resourceIds`, `endpoints`, `identityPrincipalIds`
- Parameters MUST align with layer-specific security and networking requirements
- Security defaults locked down with layer-appropriate private endpoint strategies

### Required Output Sections

1. **Layer-to-Azure Service Mapping**
2. **Module Boundary Definition (Layer-Aligned)**  
3. **Destination System Module Strategy**
4. **Module Parameter Specification**
5. **Security & Networking Plan (Per Layer)**
6. **Layer Dependency Graph**
7. **Outputs & Drift Detection Strategy**
8. **Layer-Specific Test Harness Plan**
9. **Cost Considerations (Per Layer)**
10. **Implementation Phase Alignment**

### Acceptance Criteria

- Every architectural layer maps to one or more Bicep modules
- Destination systems are independently deployable with isolated infrastructure
- No module creates cross-layer dependencies that prevent independent deployment  
- Dependency graph respects layer boundaries and enables phase-based delivery
- Test harness validates both functional requirements and architectural boundaries

### Variable Placeholders

- ORG_CODE = `<org code>`
- WORKLOAD_CODE = edi
- ENVIRONMENTS = [dev,test,prod]
- REGION_PRIMARY = `<azure region short>`

Return only the structured output sections.

---

## Usage

Execute after security bootstrap. Feed prior outputs as context. Replace placeholders before invoking.
