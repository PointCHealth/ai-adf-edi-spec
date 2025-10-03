# 06 - Application Service Implementation Prompt

---

## Prompt

You are guiding implementation of application-layer services: routing functions, outbound assembly orchestrator, partner portal backend (API), control number management, error handling flows.

### Context Inputs

- Architecture overview: `docs/01-architecture-spec.md`
- Routing & outbound architecture: `docs/08-transaction-routing-outbound-spec.md`
- Control number store specification: `docs/08-transaction-routing-outbound-spec.md` §14
- Routing message schema: `docs/08-transaction-routing-outbound-spec.md` §4-5
- Partner Portal API spec: `api/partner-portal/openapi.v1.yaml`
- Tagging & governance reference: `docs/09-tagging-governance-spec.md`

### Objectives

1. Define service responsibilities & boundaries referencing architecture & sequence diagrams
2. Propose high-level component design (modules, layers, key classes/functions) per service
3. Specify interface contracts (message schemas, DTOs, queue/topic contracts, REST endpoints) referencing `api/partner-portal/openapi.v1.yaml`
4. Provide error taxonomy & retry / DLQ handling patterns (link to `docs/08-transaction-routing-outbound-spec.md` §9)
5. Outline control number generation & gap detection logic (align with `docs/08-transaction-routing-outbound-spec.md` §14: Azure SQL database with optimistic concurrency control, stored procedures, and gap detection queries)
6. Define configuration & secret injection strategy (environment variables, Key Vault references)
7. Provide performance & scalability considerations (throughput targets, concurrency, cold start mitigation)
8. Suggest secure coding & validation patterns (payload validation, anti-tamper, logging hygiene)
9. Delivery plan: implementation order, feature toggles, incremental deployment approach
10. Include sample skeleton code snippets (language-agnostic or pseudo) for critical functions

### Constraints

- Functions should be stateless; state externalized
- No direct secrets in code; use references
- All external I/O wrapped with resilience (timeouts, retries, circuit breakers where appropriate)
- Logging must include correlation identifiers

### Required Output Sections

1. Service Responsibility Matrix
2. Component Designs
3. Interface Contracts Summary
4. Error Handling & DLQ Strategy
5. Control Number Logic Outline
6. Configuration & Secret Injection
7. Performance & Scalability Considerations
8. Secure Coding Patterns
9. Destination System Boundary Clarification
10. Implementation & Delivery Plan
11. Sample Skeleton Snippets
12. Open Questions

### Acceptance Criteria

- Every service has at least one clear responsibility & non-responsibility statement
- Error taxonomy covers validation, transient, partner, internal, security categories
- Control number logic addresses gaps, retries, monotonicity, optimistic concurrency (Azure SQL store)
- Skeleton snippets illustrate logging, correlation, resilience
- Destination system boundary clearly delineates:
  - **Core Platform (in scope)**: Routing Function, Outbound Orchestrator, Control Number Store
  - **Destination Systems (external)**: Eligibility Service, Claims Processing, Enrollment Management, Remittance (these subscribe to routing topic and implement their own architecture patterns independently)

### Variable Placeholders

- DEFAULT_TTL_MINUTES = `<number>`
- MAX_RETRY_ATTEMPTS = `<number>`

Return only the structured output sections.

---

## Usage

Use once infrastructure deployment patterns are stable. Provide placeholders, run with AI assistant.
