# AI Context Overview: Healthcare EDI Ingestion & Outbound Acknowledgment Platform

This document distills the repository’s specifications into an AI-optimized knowledge base. It introduces the problem space, domain vocabulary, system architecture, major components, configuration surfaces, operational telemetry, security posture, and forward work so an autonomous assistant can reason about extensions, code generation, verification, or impact analysis.

---

## 1. Problem Domain & Business Goal

Healthcare trading partners (clearinghouses, providers, payers) submit HIPAA X12 EDI transaction files (e.g., 837 claims) via SFTP. The platform ingests these files into an Azure landing zone, validates structure & interchange envelopes, enriches with metadata, routes messages for downstream processing, and manages acknowledgments / responses (TA1, 999, 277CA, others) while enforcing observability, governance, compliance, lineage, and SLA tracking.

Key value: Standardized, event‑driven ingestion and routing with auditable control numbers, scalable monitoring, and strict least‑privilege security aligned to HIPAA.

---

## 2. Core Architectural Principles

- Event-driven orchestration (avoid polling; rely on storage + Service Bus events)
- Immutable raw data retention & deterministic lineage
- Config-driven partner routing & rules (JSON + schema validation)
- Separation of concerns: Ingestion, Validation, Routing, Outbound Assembly
- Everything-as-Code (infra, policy, routing rules, partner config, queries)
- Observability-first: custom logs, Kusto queries, SLA dashboards
- Least privilege via Managed Identities + scoped RBAC + network isolation
- Progressive hardening: start with baseline; layer policies (tagging, encryption, logging) early

---

## 3. High-Level Component Inventory

| Layer | Purpose | Representative Azure Services / Artifacts |
|-------|---------|--------------------------------------------|  
| Ingestion & Landing | Receive partner SFTP drops into secure storage | SFTP (managed service or partner-managed) -> ADLS Gen2 (raw container) |
| Event Orchestration | Trigger downstream pipeline upon file arrival | Azure Data Factory (ADF) event pipeline, Storage Events |
| Validation & Metadata | Interchange/envelope parsing, syntax validation, metadata extraction (control numbers, transaction set IDs) | ADF activities, Custom Function(s) or Data Flow (future) |
| Routing | Classify & dispatch messages to appropriate trading partner endpoints | Azure Function (Router), Service Bus Topic (`edi-routing`) + subscriptions with rule filters |
| **Trading Partner Integration** | **Bidirectional adapters for all trading partners** | **Azure Functions (mappers/connectors), Service Bus subscriptions, partner-specific protocol adapters** |
| **Trading Partners (External)** | **External healthcare organizations** | **Payers, providers, clearinghouses via SFTP/AS2/API** |
| **Trading Partners (Internal)** | **Internal systems configured as partners** | **Enrollment Management (event sourcing), Eligibility Service, Claims Processing, Remittance - each with configured endpoints** |
| Outbound Orchestration | Generate and publish acknowledgments / response artifacts (TA1, 999, 277CA) from trading partner outcomes | Azure Function (Outbound Orchestrator), Service Bus, Storage staging |
| Control Number Management | Detect gaps / duplicates; maintain sequence integrity | Azure SQL Database with optimistic concurrency + KQL queries |
| Observability & SLA | Latency, error mix, reject rates, backlog | Azure Monitor / Log Analytics (custom tables), KQL queries under `queries/kusto/` |
| Governance & Tagging | Uniform taxonomy & cost/ownership tracking | Azure Policy + Tagging Standards (`09-tagging-governance-spec`) |
| Infrastructure as Code | Reproducible environment provisioning | Bicep modules (`infra/bicep/modules/`) |

## 4. Data Flow (Simplified Narrative)

1. Trading partner (external or internal source) transfers X12 file to SFTP landing -> Ingested into ADLS raw folder (immutable).
2. Storage event triggers ADF pipeline (or Function wrapper) for metadata extraction + initial validation.
3. Validation results + interchange metadata are persisted into custom log tables (e.g., `InterchangeValidation_CL`).
4. Routing Function reads normalized metadata message (from staging queue/event) and applies declarative rules from `config/routing/routing-rules.json` to publish to Service Bus subscriptions.
5. **Trading partner integration adapters** receive filtered messages and process transactions according to partner-specific logic. Each trading partner (whether external or internal) is configured with:
   - Unique partner code and configuration profile
   - Endpoint type (SFTP, Service Bus, REST API, Database)
   - Data flow direction (INBOUND, OUTBOUND, BIDIRECTIONAL)
   - Integration adapter handling format transformation and protocol adaptation
6. Trading partners produce outcome signals; Outbound Orchestrator assembles TA1 / 999 / 277CA payloads referencing original control numbers and timing them vs SLA targets.
7. Outbound acknowledgments are written to outbound storage + delivered to trading partners via configured delivery mechanism (SFTP pickup, API push, queue) and logged (`AckAssembly_CL`).
8. KQL dashboards compute latency percentiles, reject rates, gap detection, backlog health; alerts feed Ops runbooks.

**Key Architectural Principle**: All data sources and destinations (external payers/providers AND internal claims/eligibility/enrollment systems) are treated uniformly as **trading partners** with configured endpoints and integration adapters. This eliminates architectural distinctions between "internal" and "external" systems.

---

## 5. Domain Vocabulary (Glossary for AI Reasoning)

- X12: ANSI ASC X12 healthcare EDI standard (e.g., 837, 277CA).
- Interchange (ISA/IEA): Envelope wrapper; contains interchange control number (ICN).
- Functional Group (GS/GE): Groups related transaction sets; group control number.
- Transaction Set (ST/SE): Individual business document (e.g., claim batch) with control number.
- Control Number Gap: Missing or out-of-sequence expected control number; indicates loss or duplication risk.
- **Trading Partner**: External healthcare organization (payer, provider, clearinghouse) or internal configured system endpoint receiving or sending EDI data.
- **Partner Type**: Classification of trading partner as **EXTERNAL** (outside organization) or **INTERNAL** (internal system treated as partner).
- **Partner Code**: Unique identifier for each trading partner (e.g., `PARTNERA`, `INTERNAL-CLAIMS`).
- **Data Flow Direction**: Classification of partner data flow as **INBOUND** (partner sends data), **OUTBOUND** (partner receives data), or **BIDIRECTIONAL** (both).
- **Endpoint Type**: Protocol used for partner integration - **SFTP**, **REST_API**, **SERVICE_BUS**, or **DATABASE**.
- **Integration Adapter**: Bidirectional Azure Function connecting EDI platform to trading partner endpoints; handles format transformation and protocol adaptation.
- **Adapter Type**: Pattern for integration adapter - **EVENT_SOURCING** (event-driven with immutable log), **CRUD** (direct operations), or **CUSTOM** (specialized logic).
- Ack Types:
  - TA1: Interchange-level acknowledgment (structure / envelope acceptance or reject)
  - 999: Functional acknowledgment (syntax acceptance or rejection at transaction / segment level)
  - 277CA: Claim acknowledgment (business-level status for 837 transactions)
- Latency Metrics: Time between file persisted and ack assembly (p50/p95/p99 tracked).
- Backlog: Count of unacknowledged originating transactions pending trading partner processing.
- Routing Rule: Declarative filter mapping metadata attributes (e.g., partnerId, transactionType, direction) to a Service Bus subscription or handler.

---

## 6. Configuration Surfaces

| File | Purpose | Notes |
|------|---------|-------|
| `config/partners/partners.schema.json` | JSON Schema for validating partner definitions | Enforces partnerType (EXTERNAL/INTERNAL), dataFlow.direction, endpoint types (SFTP, SERVICE_BUS, REST_API, DATABASE), integration.adapterType |
| `config/partners/partners.sample.json` | Example partner configs (2 external, 4 internal) | Demonstrates SFTP endpoints for external partners, Service Bus subscriptions for internal partners with different adapter types |
| `config/routing/routing-rules.json` | Declarative routing logic | Consumed by Router Function to build Service Bus rules with direction filters |
| `ACK_SLA.md` | SLA targets & KQL snippet references | Central operational SLA quick reference |

Validation Command (local): `npx ajv validate -s ./config/partners/partners.schema.json -d ./config/partners/partners.sample.json`

**Partner Configuration Schema Highlights**:

- `partnerType`: "EXTERNAL" | "INTERNAL"
- `dataFlow.direction`: "INBOUND" | "OUTBOUND" | "BIDIRECTIONAL"
- `endpoint.type`: "SFTP" | "SERVICE_BUS" | "REST_API" | "DATABASE" with protocol-specific configuration
- `integration.adapterType`: "EVENT_SOURCING" | "CRUD" | "CUSTOM" with optional customAdapterConfig

---

## 7. Infrastructure as Code (IaC) Strategy

- Bicep modules exist (scaffolds) for: `servicebus.bicep`, `router-function.bicep`, `outbound-orchestrator.bicep`.
- Expected future additions: Storage accounts (raw, curated, outbound), Log Analytics workspace, ADF factory, Key Vault, Policy assignments, Diagnostic settings, Private endpoints.
- Deployment Pipeline (planned): Orchestrate module validation (what-if), security scanning, promotion Dev → NonProd → Prod, enforcing tagging and policy compliance.

Design Tenets for AI:

1. Keep modules atomic (single primary resource + outputs for composition).
2. Derive naming from central prefix + environment + workload segment.
3. Emit standardized tags (see Tagging Governance spec) from each module root.

---

## 8. Security & Compliance Highlights

- Principle of Least Privilege: Managed Identities per Function, ADF, with minimal Data Lake & Service Bus rights.
- Separation of data zones (raw immutable vs processed) to support audit & lineage.
- Logging of validation and acknowledgments for forensic replay (immutability of source events).
- Tagging + Policy enforcement for encryption at rest, TLS, diagnostic logs.
- No PHI currently stored (spec-phase), but designed to ensure PHI handling via encryption & restricted access.

---

## 9. Observability & Metrics

Custom log tables (illustrative names from KQL snippets):

- `AckAssembly_CL` – Ack generation events & latency fields.
- `InterchangeValidation_CL` – Interchange / envelope validation outcomes.

Representative KQL (already in repo under `queries/kusto/`):

- Latency distribution (`ack_latency.kql`)
- 999 reject rate (`syntax_reject_rate_999.kql`)
- TA1 failure rate (`ta1_failure_rate.kql`)
- 277CA timeliness (`277ca_timeliness.kql`)
- Control number gap detection (`control_number_gap_detection.kql`)
- Routing latency + DLQ monitoring (`routing_latency.kql`, `dlq_routing_messages.kql`)

Operational KPIs (from specs & SLA doc):

- Ack latency percentiles (per ack type) vs SLA target thresholds.
- Daily reject / failure rates (TA1, 999) – trending downward goal.
- Control number continuity (no gaps / duplicates beyond tolerated window).
- DLQ backlog should remain 0 or drained within defined recovery SLA.

Alerting Concept:

- Threshold + Trend alerts (e.g., p95 latency > SLA for 3 consecutive intervals).
- Anomaly-based (unusual spike in TA1 rejects using baseline from past N days).

---

## 10. Routing Mechanics (Planned Implementation)

1. Router Function loads `routing-rules.json` at startup (with cache invalidation strategy future enhancement).
2. Builds / ensures Service Bus subscription rules (idempotent reconciliation) mapping metadata attributes to label-based filters.
3. On message arrival (post-validation event), applies evaluated rule set → publishes to topic with enriched headers (partnerId, transactionType, control numbers, correlation IDs).
4. Dead-letter logic: malformed metadata or missing partner config results in DLQ send + logging for ops triage.

Key Invariants:

- Each inbound file yields at most one routing decision message.
- A routing decision must be traceable back to immutable original file path + control numbers.
- Rule evaluation order is deterministic (explicit priority or most-specific-match wins).

---

## 11. Outbound Acknowledgment Orchestration (Planned)

Flow:

1. Trigger condition: Downstream validation / claim adjudication events or timers.
2. Aggregate required source metadata (original control numbers, statuses) to assemble standardized TA1 / 999 / 277CA payloads.
3. Persist assembled ack to outbound storage + log to `AckAssembly_CL` with timing fields.
4. Optionally publish distribution event (future partner delivery channel integration).

Latency Measurement Definition:
`latencySeconds = datetime_diff('second', filePersistedTime, ackTriggerStartTime) * -1` (from example snippet) – AI should confirm directionality before reusing; negative multiplier suggests a historical correction; might standardize as `ackTriggerStartTime - filePersistedTime` later.

---

## 12. Control Number Governance

Purpose: Detect ingestion gaps or duplicates that can compromise transactional integrity.
Approach (prototype): KQL query scanning sequential increments by partner / interchange stream.
Future Hardening:

- Dedicated durable store (e.g., Cosmos DB / Table Storage) with atomic upsert.
- Replay detection heuristics (same control number + file hash) → flag duplicates.
- Alert if gap persists beyond tolerance window (e.g., next 5 arrivals do not close gap).

---

## 13. Tagging & Governance (Summary)

Taxonomy defined in `09-tagging-governance-spec.md` (referenced, not duplicated here) – AI actions impacting IaC must preserve required tags (ownership, environment, dataSensitivity, costCenter, complianceScope, workload, component).

Automated Policy Patterns (intended):

- Deny: Resource creation without mandatory tags.
- Append: Diagnostics settings + encryption.
- Audit: Public network exposure exceptions.

---

## 14. Diagram Assets

Mermaid `.mmd` sources under `docs/diagrams/` rendered to PNG via `scripts/generate-diagrams.ps1` (uses mermaid-cli). Labels simplified to avoid parser bug with parentheses. AI generating new diagrams should conform to existing style (top-down flowcharts; concise node labels) and update PNGs by rerunning script.

---

## 15. Current Repository Gaps (Implementation Phase Pending)

| Gap | Impact | Suggested AI Assistance |
|-----|--------|------------------------|
| Missing ADF pipeline JSON exports | Hard to bootstrap pipeline-as-code | Generate pipeline definitions scaffolds |
| No actual Function code (Router, Outbound Orchestrator) | Specs not executable | Produce starter Azure Function (TypeScript/Python/C#) with config-driven rule loader |
| No control number durable store | Potential gap detection latency | Propose minimal schema & integration layer |
| Absent synthetic ingestion scripts | Hard to test end-to-end | Create PowerShell + Python sample file drop simulator |
| Policy assignment IaC absent | Governance drift risk | Author Bicep/Policy module set + pipeline step |
| No CI/CD YAML pipelines | Manual deployments | Scaffold GitHub Actions YAML referencing Bicep what-if + deployment gates |

---

## 16. AI Task Patterns (Common Prompts This Context Enables)

Use this section to guide autonomous expansions safely.

Pattern Examples:

1. Generate Azure Function (Router) reading `routing-rules.json`, validating schema, syncing Service Bus subscription rules idempotently.
2. Implement control number store adapter (interface + Cosmos DB or Table Storage backend) + update gap detection queries to reference store.
3. Produce Bicep module for Log Analytics workspace with standardized tags & diagnostic settings to ingest Function App logs.
4. Convert existing KQL snippets into Azure Monitor Workbook JSON template.
5. Create CI pipeline performing: schema validation (AJV), Bicep lint + what-if, KQL syntax validation, unit test stubs for Functions.
6. Add synthetic file generator (837 minimal test payload) + uploader script emitting randomized control numbers within a bounded sequence.

Safeguards to Maintain:

- Do not alter existing sample schema semantics without versioning (introduce `schemaVersion`).
- Preserve tag mapping across all new Bicep resources.
- Ensure any new log table naming remains consistent (`*_CL`).
- Avoid embedding PHI in sample data (use synthetic placeholders).

---

## 17. Reasoning Invariants (Guidance for AI Consistency)

### 17.1 Core Architectural Principles

- Every ingestion artifact must be traceable: (file path, partnerId, control numbers, event correlation ID).
- Latency metrics require consistent timestamp semantics (define once; reuse variable names).
- Routing rules = declarative truth; code should not hardcode partner logic.
- Infrastructure naming pattern must remain deterministic to avoid drift between environments.
- Observability artifacts (queries, dashboards) should be version-controlled beside code that emits corresponding logs.

### 17.2 Design Patterns to Maintain

- **Event-Driven Architecture**: File arrival → validation → routing → processing → acknowledgment
- **Saga Pattern**: Track multi-step acknowledgment workflows with compensation
- **Circuit Breaker**: Isolate failing trading partners to prevent cascade failures
- **Strangler Fig**: Enable gradual migration from legacy EDI processing
- **Trading Partner Abstraction**: Each trading partner (internal or external) independently configured with own endpoint and adapter type
- **Protocol Adapter Pattern**: Separate transport protocol concerns (SFTP, Service Bus, REST API) from business logic

### 17.3 Technology Decisions (Rationale)

- **Service Bus over Event Grid**: Ordering guarantees and rich SQL filtering required
- **Azure SQL for Control Numbers**: ACID guarantees and optimistic concurrency support
- **Managed Identities**: Eliminate shared secrets, support automatic rotation
- **Durable Functions for Outbound**: State management for complex acknowledgment workflows
- **ADLS Gen2**: Hierarchical namespace required for data lake partitioning strategy

---

## 18. Open Questions / Assumptions (To Validate Later)

| Item | Current Assumption | Potential Options |
|------|--------------------|-------------------|
| Durable control number store | Not yet selected | Cosmos DB, Azure Table Storage, SQL DB |
| ADF vs Function-first for validation | ADF pipeline performs baseline | Function-based micro-pipeline for flexibility |
| Partner config reload strategy | Manual redeploy | Timer-triggered hash check or Event Grid on file change |
| Multi-tenant isolation level | Shared resource group w/ tags | Per-partner namespace or logical isolation |
| Ack distribution channel | Future (SFTP back / API) | Event Grid, SFTP push, AS2 gateway |

AI producing code should surface when an assumption is material to its output.

---

## 15. Recommended Solution Structure

### 15.1 Core Architecture Layers

The implementation should be structured around **5 core functional domains** with clean separation of concerns:

| Layer | Purpose | Technology Stack | Repository Path |
|-------|---------|------------------|----------------|
| **Core Platform** | Foundation ingestion, storage, shared utilities | ADF, ADLS Gen2, Event Grid | `/src/platform/` |
| **Routing & Event Hub** | Decoupling layer, message routing | Azure Functions, Service Bus | `/src/routing/` |
| **Trading Partner Integration** | Bidirectional adapters for all trading partners | Azure Functions, protocol adapters | `/src/partners/` |
| **Trading Partners** | Internal and external partner systems | Various (event sourcing, CRUD, custom) | Partner-managed or `/src/partners/internal/` |
| **Outbound Assembly** | Acknowledgment generation | Durable Functions, Azure SQL | `/src/outbound/` |
| **Cross-Cutting** | Security, observability, configuration | Log Analytics, Key Vault, Bicep | `/src/cross-cutting/` |

### 15.2 Implementation Phases

| Phase | Duration | Focus | Key Deliverables |
|-------|----------|-------|------------------|
| **Phase 1: Foundation** | Weeks 1-4 | Infrastructure, basic ingestion | Bicep modules, ADF pipelines, storage zones |
| **Phase 2: Routing & First Trading Partner** | Weeks 5-8 | Event-driven routing, eligibility partner integration | Router Function, Service Bus, 270/271 processing |
| **Phase 3: Scale & Additional Trading Partners** | Weeks 9-16 | Claims, enrollment, enhanced outbound | 837/834 processing, control number store, partner adapters |
| **Phase 4: Production Readiness** | Weeks 17-20 | Security hardening, operations | HIPAA compliance, monitoring, DR strategy |

### 15.3 Repository Structure Recommendation

```text
/
├── docs/                         # (existing specs)
├── src/
│   ├── platform/                # Core ingestion & infrastructure
│   ├── routing/                 # Message routing layer
│   ├── partners/                # Trading partner integration adapters
│   │   ├── internal/           # Internal partner implementations
│   │   └── external/           # External partner protocol adapters
│   ├── outbound/               # Acknowledgment assembly
│   └── shared/                 # Common libraries
├── infra/
│   ├── bicep/                  # (existing modules)
│   └── environments/           # Environment-specific configs
├── tests/
│   ├── unit/                   # Component tests
│   ├── integration/            # Service integration tests
│   └── e2e/                    # End-to-end scenarios
└── .github/workflows/          # CI/CD pipelines
```

## 16. Quick Reference: File Map (AI Lookup)

| Path | Category | AI Usage |
|------|----------|----------|
| `README.md` | Entry point | High-level index; keep consistent if adding docs |
| `AI_PROJECT_OVERVIEW.md` | AI context | Central reasoning substrate (this file) |
| `ACK_SLA.md` | SLA & KQL | Source for performance targets |
| `config/partners/partners.schema.json` | Schema | Validate partner configs pre-deploy |
| `config/partners/partners.sample.json` | Example config | Basis for generating production variant |
| `config/routing/routing-rules.json` | Routing rules | Feed Router Function logic |
| `infra/bicep/modules/*.bicep` | IaC modules | Extend with new infra components |
| `queries/kusto/*.kql` | Observability queries | Transform into workbooks / alerts |
| `docs/0*.md` | Detailed specs | Source-of-truth narratives |

---

## 20. Next Recommended AI Actions (Structured Implementation)

### Phase 1 Actions (Foundation)

1. **Infrastructure Setup**: Generate Bicep modules for core services (Storage, ADF, Event Grid, Log Analytics) with proper tagging and security defaults.
2. **CI/CD Pipeline**: Create GitHub Actions workflow for Bicep validation, deployment, and testing.
3. **Core Ingestion**: Implement ADF pipeline templates for basic file validation and metadata extraction.
4. **Observability Foundation**: Convert key KQL queries into Log Analytics custom tables and basic dashboards.

### Phase 2 Actions (Routing Layer)

1. **Router Function**: Generate Azure Function code for envelope parsing and Service Bus message publishing.
2. **Service Bus Configuration**: Create Bicep modules for topics, subscriptions, and filtering rules with direction support.
3. **First Trading Partner Integration**: Implement eligibility partner (270/271) integration adapter as proof of concept.
4. **Basic Acknowledgments**: Generate 999 functional acknowledgment assembly logic.

### Phase 3 Actions (Scale)

1. **Claims Processing Partner**: Implement 837/277CA trading partner integration adapter with complex business logic patterns.
2. **Control Number Store**: Create Azure SQL-based counter management with optimistic concurrency.
3. **Event Sourcing Partner**: Implement enrollment management (834) using event sourcing pattern as internal trading partner.
4. **Enhanced Outbound**: Complete acknowledgment lifecycle (TA1, 277CA, etc.) with SLA tracking and partner-specific delivery.

### Phase 4 Actions (Production)

1. **Security Hardening**: Implement HIPAA compliance controls, private endpoints, and RBAC policies.
2. **Operational Excellence**: Create monitoring dashboards, alert rules, and incident response runbooks.
3. **Partner Portal**: Generate self-service partner configuration and testing tools.
4. **DR Strategy**: Implement multi-region backup and disaster recovery procedures.

---

## 21. How to Use This Document as an AI

- Treat sections 5, 16, 17 as canonical constraints & task templates.
- Before generating new code, cross-reference invariants (section 17) and open questions (section 18) to flag assumption dependencies.
- When modifying or extending infra, ensure Tagging + Observability integration are explicit steps.
- Maintain bidirectional traceability: If a new metric is added, ensure corresponding KQL & documentation are updated in the same change set.

---

## 22. Changelog (This File)

- v1.0 (Initial): Consolidated architectural & operational context for AI enablement.

---
End of AI Context Overview.
