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

### 3.5 Trading Partner Abstraction (Core Architectural Principle)

**Core Principle**: ALL data sources and destinations (external healthcare organizations AND internal systems) are uniformly modeled as **Trading Partners** with configured endpoints and integration adapters.

| Partner Type | Connection Method | Examples | Configuration |
|--------------|------------------|----------|---------------|
| **EXTERNAL** | SFTP, AS2, REST API | Medicare, Commercial Payers, Clearinghouses | `partners.json`: partnerType=EXTERNAL, endpoint.type=SFTP |
| **INTERNAL** | Service Bus, Database, Internal API | Enrollment, Claims, Eligibility, Remittance | `partners.json`: partnerType=INTERNAL, endpoint.type=SERVICE_BUS |

**Benefits of Unified Model**:
- Eliminates architectural distinction between "internal" and "external" systems
- Enables consistent integration patterns, monitoring, and lifecycle management  
- Supports flexible internal system architectures (event sourcing, CRUD, custom patterns)
- Simplifies operational model (one partner onboarding process)
- Allows independent scaling and evolution of each trading partner

**Integration Adapter Pattern**: Each trading partner connects via a bidirectional adapter (see Doc 13) that:
- Subscribes to filtered Service Bus routing messages
- Transforms data to/from partner-specific formats  
- Implements partner protocol (SFTP, API, database, queue)
- Writes outcome signals to outbound staging for acknowledgment generation
- Operates with loose coupling to core platform

**Partner Configuration**: Each trading partner defined in `config/partners/partners.json` with:
- Unique partner code and metadata
- Partner type (EXTERNAL or INTERNAL)
- Data flow direction (INBOUND, OUTBOUND, BIDIRECTIONAL)
- Endpoint type and connection details
- Integration adapter type (EVENT_SOURCING, CRUD, CUSTOM)
- SLA targets and business rules

See `config/partners/partners.schema.json` for complete configuration schema.

---

| Layer | Purpose | Representative Azure Services / Artifacts |
|-------|---------|--------------------------------------------|  
| Ingestion & Landing | Receive partner SFTP drops into secure storage | SFTP (managed service or partner-managed) -> ADLS Gen2 (raw container) |
| Event Orchestration | Trigger downstream pipeline upon file arrival | Azure Data Factory (ADF) event pipeline, Storage Events |
| Validation & Metadata | Interchange/envelope parsing, syntax validation, metadata extraction (control numbers, transaction set IDs) | ADF activities, Custom Function(s) or Data Flow (future) |
| Routing | Classify & dispatch messages to appropriate trading partner endpoints | Azure Function (Router), Service Bus Topic (`edi-routing`) + subscriptions with rule filters |
| **Partner Integration (Adapters)** | Bidirectional format transformation and protocol adaptation | **Azure Functions (C# standardized), Service Bus, SFTP/API connectors. Maps between platform X12 format and partner-specific formats (XML, JSON, CSV, database). Configured per partner type and endpoint. See Doc 13 for mapper/connector patterns and centralized mapping rules repository.** | **Azure Functions (mappers/connectors), Service Bus subscriptions, partner-specific protocol adapters** |
| **Trading Partners (External)** | **External healthcare organizations** | **Payers, providers, clearinghouses via SFTP/AS2/API** |
| **Trading Partners (Internal)** | **Internal systems configured as partners** | **Enrollment Management (event sourcing - see Doc 11), Eligibility Service, Claims Processing, Remittance - each with configured endpoints. Architecture choice varies by partner: event sourcing, CRUD, or custom patterns.** |
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

### 7.4 GitHub Actions CI/CD (Implementation Details)

**Authentication**: OpenID Connect (OIDC) federated identity - passwordless, short-lived tokens with automatic rotation. No service principal secrets stored in GitHub.

**Federated Credential Configuration**:
- Issuer: `https://token.actions.githubusercontent.com`
- Subject patterns: `repo:vincemic/ai-adf-edi-spec:environment:prod` (environment-scoped)
- Audience: `api://AzureADTokenExchange`

**Workflow Catalog**:
| Workflow | Trigger | Purpose | Key Actions |
|----------|---------|---------|-------------|
| `infra-ci.yml` | Pull Request | Validation & what-if | Bicep build/lint, PSRule scan, Checkov scan, what-if deployment, PR comment |
| `infra-cd.yml` | Push to main / Manual | Environment deployments | Deploy to dev (auto), test (gated), prod (gated + change ticket) |
| `function-ci.yml` | PR (paths: src/functions/**) | Function build & test | Build, unit tests, code coverage, static analysis, package upload |
| `function-cd.yml` | Manual dispatch | Function deployment | Deploy function packages to environments |
| `adf-export.yml` | Weekly schedule / Manual | ADF pipeline versioning | Export ADF pipelines to JSON, create PR with changes |
| `drift-detection.yml` | Nightly schedule | Infrastructure drift | What-if comparison, create issue if drift detected |
| `security-scan.yml` | Push / PR / Weekly | Dependency & code security | Dependency review, CodeQL analysis, SARIF upload |
| `config-validation.yml` | PR (paths: config/**) | Partner config validation | Schema validation (AJV), format checks, policy compliance |

**Environment Protection Rules**:
| Environment | Auto-Deploy | Approval Required | Wait Timer | Additional Gates |
|-------------|-------------|------------------|------------|------------------|
| **dev** | ✅ (on merge to main) | None | None | None |
| **test** | ❌ | 1 reviewer (data-eng-team) | None | Policy compliance evaluation |
| **prod** | ❌ | 2 reviewers (security + platform-lead) | 5 minutes | Change ticket validation + security gate |

**Deployment Flow**:
```text
PR Created → infra-ci.yml (validate) → Merge to main → 
  deploy-dev (auto) → smoke tests → 
    deploy-test (manual trigger + 1 approval) → integration tests →
      deploy-prod (manual trigger + 2 approvals + change ticket) → post-deploy validation
```

**Artifact Management**:
- Compiled Bicep templates: 90-day retention
- Function packages: 90-day retention (release artifacts indefinite)
- Deployment manifests: Indefinite retention
- What-if outputs: 14-day retention

**Security Features**:
- Secret scanning with push protection
- Dependency review (fail on high severity)
- SARIF uploads to Security tab (PSRule, Checkov, CodeQL)
- Signed commits required on main branch
- Code owners enforcement (CODEOWNERS file)

**Performance Optimizations**:
- Artifact caching for dependencies (`actions/cache@v3`)
- Conditional job execution (skip unnecessary environments)
- Matrix strategy for parallel function builds
- Reusable composite actions (azure-login, bicep-whatif)

**Cost Management**:
- GitHub-hosted runners: 2,000 minutes/month free (private repos)
- Artifact retention: 30 days (cost-optimized); 90 days for releases
- Self-hosted runners considered for high-volume scenarios

**Reference**: See Doc 04a for complete GitHub Actions implementation guide including troubleshooting, operational procedures, and workflow examples.

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

## 11. Control Number Management (Comprehensive Specification)

**Decision**: Azure SQL Database with optimistic concurrency control

**Purpose**: Maintain monotonic, gap-free sequence numbers for all outbound EDI acknowledgments and responses (ISA13, GS06, ST02) with audit trail and collision detection.

**Key Capabilities**:
- **Sequence Generation**: Monotonic ISA (interchange), GS (functional group), and ST (transaction set) control numbers
- **Concurrency Control**: Optimistic locking using SQL ROWVERSION for collision-free multi-threaded access
- **Gap Detection**: Automated queries identify missing sequences; alerting on anomalies
- **Audit Trail**: Complete history of all issued control numbers with correlation to outbound files
- **Rollover Handling**: Coordinated reset procedures when approaching max values (999999999)
- **Disaster Recovery**: Active geo-replication to paired region with failover procedures

**Performance Characteristics**:
| Metric | Target | Notes |
|--------|--------| ------ |
| **Acquisition Latency** | < 50ms p95 | Single row read + update with index |
| **Concurrent Throughput** | 100+ TPS | Optimistic concurrency handles contention |
| **Retry Rate** | < 5% | Exponential backoff minimizes collisions |
| **Gap Detection Query** | < 5 sec | Run off-hours; indexed on IssuedUtc |

**Data Model**:
```sql
CREATE TABLE [dbo].[ControlNumberCounters] (
    [CounterId] INT IDENTITY(1,1) PRIMARY KEY,
    [PartnerCode] NVARCHAR(15) NOT NULL,
    [TransactionType] NVARCHAR(10) NOT NULL,
    [CounterType] NVARCHAR(20) NOT NULL, -- 'ISA', 'GS', 'ST'
    [CurrentValue] BIGINT NOT NULL DEFAULT 1,
    [MaxValue] BIGINT NOT NULL DEFAULT 999999999,
    [RowVersion] ROWVERSION NOT NULL, -- Optimistic concurrency
    CONSTRAINT [UQ_Counter] UNIQUE ([PartnerCode], [TransactionType], [CounterType])
);
```

**Concurrency Model**: 
- Read current value + ROWVERSION
- Calculate next value (CurrentValue + 1)
- Update with WHERE clause checking ROWVERSION unchanged
- If @@ROWCOUNT = 0, retry with exponential backoff (max 5 attempts)
- On success, insert audit record

**Gap Detection**: Scheduled query compares issued control numbers for monotonic sequence:
```sql
WITH NumberedAudit AS (
    SELECT ControlNumberIssued,
           LAG(ControlNumberIssued) OVER (ORDER BY ControlNumberIssued) AS PreviousNumber
    FROM [dbo].[ControlNumberAudit]
    WHERE IssuedUtc >= DATEADD(DAY, -30, GETUTCDATE())
)
SELECT PreviousNumber AS GapStart, ControlNumberIssued AS GapEnd,
       (ControlNumberIssued - PreviousNumber - 1) AS GapSize
FROM NumberedAudit
WHERE ControlNumberIssued - PreviousNumber > 1;
```

**Retention Policy**:
- Active counters: Indefinite (operational necessity)
- Audit history: 7 years (HIPAA compliance alignment)
- Archive to cold storage after 2 years

**Security Controls**:
- Transparent Data Encryption (TDE) enabled
- Outbound Orchestrator Managed Identity with `db_datawriter` + `db_datareader` roles only
- Private endpoint; no public access
- Connection string in Key Vault
- Azure SQL Auditing logs all UPDATE operations

**Monitoring & Alerts**:
| Condition | Threshold | Action |
|-----------|-----------|--------|
| Retry rate > 10% | 15 min sustained | Notify platform engineering |
| Gap detected | Any occurrence | Critical alert + runbook link |
| Counter > 80% max value | Single check | Warning + coordinate reset |
| Acquisition latency p95 > 200ms | 30 min | Investigate database performance |

**Disaster Recovery**:
- Automated backups: Point-in-Time Restore up to 35 days
- Active geo-replication to paired region (read-only secondary)
- Manual failover trigger; resume from last known good value in secondary
- Post-failover validation: Run gap detection query; document any drift

**Reference**: See Doc 08 §14 for complete specification including stored procedures, rollover procedures, partner onboarding initialization, and operational runbooks.

---

### A.13 Transaction to Response Matrix (Summary)

Taxonomy defined in `09-tagging-governance-spec.md` (referenced, not duplicated here) – AI actions impacting IaC must preserve required tags (ownership, environment, dataSensitivity, costCenter, complianceScope, workload, component).

Automated Policy Patterns (intended):

- Deny: Resource creation without mandatory tags.
- Append: Diagnostics settings + encryption.
- Audit: Public network exposure exceptions.

---

## 14. Diagram Assets

Mermaid `.mmd` sources under `docs/diagrams/` rendered to PNG via `scripts/generate-diagrams.ps1` (uses mermaid-cli). Labels simplified to avoid parser bug with parentheses. AI generating new diagrams should conform to existing style (top-down flowcharts; concise node labels) and update PNGs by rerunning script.

---

## 15. Implementation Readiness Status

### 15.1 Completed Artifacts

| Artifact | Status | Location |
|----------|--------|----------|
| Architecture Specifications | ✅ Complete | `docs/01-15*.md` |
| Implementation Plan | ✅ Complete | `implementation-plan/00-40*.md` |
| AI Prompt Library | ✅ Complete | `implementation-plan/ai-prompts/*.md` |
| Infrastructure Specifications | ✅ Complete | `docs/04-iac-strategy-spec.md`, `docs/04a-github-actions-implementation.md` |
| KQL Query Library | ✅ Complete | `queries/kusto/*.kql` |
| Partner Configuration Schemas | ✅ Complete | `config/partners/*.json` |
| Tagging & Governance | ✅ Complete | `docs/09-tagging-governance-spec.md` |

### 15.2 Ready for AI-Driven Implementation

**AI Prompt Catalog** (`implementation-plan/ai-prompts/`):
- 01: Create 5 strategic repositories
- 02: Generate CODEOWNERS files
- 03: Configure GitHub variables
- 04: Create infrastructure CI/CD workflows
- 05: Create function CI/CD workflows
- 06: Create monitoring workflows
- 07: Create Dependabot configuration
- 08: Create Bicep infrastructure templates
- 09: Create Azure Function projects
- 12: Create shared NuGet libraries
- 13: Create partner configuration schema
- 14: Create integration test suite
- 15: Onboard trading partner (existing)

**Estimated AI Code Generation Coverage**: 70-90% across all components

### 15.3 Implementation Gaps Requiring Human Decision

| Gap | Impact | Owner |
|-----|--------|-------|
| Azure subscription approval | Blocks Phase 0 | Finance/Procurement |
| GitHub Enterprise licensing | Required for Copilot Enterprise | IT/Procurement |
| Trading partner pilot selection | Affects Phase 3 timeline | Business Stakeholders |
| HIPAA BAA execution | Required before production | Compliance/Legal |
| Production deployment approval | Gates final go-live | Executive Sponsor |

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

### 15.1 Strategic Multi-Repository Architecture

**Decision**: Five strategic repositories for independent deployment, clear ownership, and operational scalability.

**Timeline**: 18-week AI-accelerated implementation (vs. 28 weeks traditional)

| Repository | Purpose | Primary Components | Deployment Frequency |
|------------|---------|-------------------|---------------------|
| **edi-platform-core** | Core infrastructure, shared libraries, router, scheduler | Bicep IaC, NuGet libraries (HealthcareEDI.*), InboundRouter, EnterpriseScheduler | Low (stable foundation) |
| **edi-mappers** | EDI transaction family mappers | EligibilityMapper (270/271), ClaimsMapper (837/277), EnrollmentMapper (834), RemittanceMapper (835) | Medium (per transaction type) |
| **edi-connectors** | Trading partner protocol adapters | SftpConnector, ApiConnector, DatabaseConnector | Medium (per integration pattern) |
| **edi-partner-configs** | Partner metadata, routing rules, mapping definitions | JSON schemas, partner configs, validation workflows | High (per partner onboarding) |
| **edi-data-platform** | Data orchestration and storage | ADF pipelines, SQL databases (ControlNumbers, EventStore) | Low (stable after Phase 1) |

### 15.2 Implementation Phases (AI-Accelerated)

| Phase | Duration | Focus | Key Deliverables |
|-------|----------|-------|------------------|
| **Phase 0: Foundation** | Weeks 1-2 | Repository setup, CI/CD, Azure subscriptions | 5 repositories, GitHub Actions, OIDC auth, branch protection |
| **Phase 1: Core Platform** | Weeks 3-6 | File ingestion, storage, basic validation | ADF pipelines, storage zones, Router Function, shared libraries |
| **Phase 2: Routing Layer** | Weeks 7-10 | Service Bus routing, message distribution | Service Bus topics, routing rules, subscription filters |
| **Phase 3: First Trading Partner** | Weeks 11-14 | Eligibility mapper/connector, basic acks | 270/271 processing, SFTP connector, 999 acknowledgments |
| **Phase 4: Scale Partners** | Weeks 15-16 | Claims, enrollment, multiple partners | 837/834 processing, event sourcing, partner adapters |
| **Phase 5: Outbound Assembly** | Weeks 17-18 | Control numbers, advanced acks, scheduler | Azure SQL counters, TA1/277CA, enterprise scheduler |
| **Phase 6: Production Hardening** | Weeks 19-20 (overlap) | Security audit, performance, DR | HIPAA compliance, monitoring, operations runbooks |

**Time Savings**: 10 weeks (36% reduction) via AI-driven code generation, automated testing, and parallel workstreams.

### 15.3 Repository Structure (Strategic Multi-Repo)

```text
edi-platform-core/
├── infra/bicep/              # All Bicep infrastructure modules
├── shared/                    # NuGet packages (HealthcareEDI.*)
├── functions/                 # InboundRouter, EnterpriseScheduler
├── tests/                     # Integration tests
├── docs/                      # Cross-repo architecture docs
└── .github/workflows/         # Core CI/CD pipelines

edi-mappers/
├── functions/                 # 4 mapper functions
├── shared/                    # Mapper-specific utilities
├── tests/                     # Mapper integration tests
└── .github/workflows/         # Mapper CI/CD

edi-connectors/
├── functions/                 # 3 connector functions
├── shared/                    # Connector-specific utilities
├── tests/                     # Connector integration tests
└── .github/workflows/         # Connector CI/CD

edi-partner-configs/
├── partners/                  # Partner JSON configurations
├── schemas/                   # JSON schemas
├── routing/                   # Routing rules
└── .github/workflows/         # Config validation

edi-data-platform/
├── adf/                       # ADF pipeline definitions
├── sql/                       # SQL database projects
└── .github/workflows/         # Data platform CI/CD
```

**Cross-Repository Coordination**:
- Shared libraries published to Azure Artifacts (NuGet feed)
- Documentation centralized in edi-platform-core/docs/
- Multi-root VS Code workspace for AI context awareness
- GitHub Actions reusable workflows for consistency

## 16. Quick Reference: File Map (AI Lookup)

### 16.1 Current Repository (ai-adf-edi-spec)

| Path | Category | AI Usage |
|------|----------|----------|
| `README.md` | Entry point | High-level index; keep consistent if adding docs |
| `AI_PROJECT_OVERVIEW.md` | AI context | Central reasoning substrate (this file) |
| `AI_PROMPTS_ALIGNMENT_REPORT.md` | Alignment status | Track prompt updates and misalignments |
| `ACK_SLA.md` | SLA & KQL | Source for performance targets |
| `implementation-plan/00-implementation-overview.md` | Master plan | Strategic approach, timeline, team structure |
| `implementation-plan/ai-prompts/*.md` | AI prompts | Executable prompts for code generation |
| `config/partners/partners.schema.json` | Schema | Validate partner configs pre-deploy |
| `config/partners/partners.sample.json` | Example config | Basis for generating production variant |
| `config/routing/routing-rules.json` | Routing rules | Feed Router Function logic |
| `infra/bicep/modules/*.bicep` | IaC modules | Reference for generating infrastructure |
| `queries/kusto/*.kql` | Observability queries | Transform into workbooks / alerts |
| `docs/01-15*.md` | Architecture specs | Source-of-truth narratives |
| `docs/04a-github-actions-implementation.md` | CI/CD guide | Complete GitHub Actions implementation |

### 16.2 Strategic Repositories (To Be Created)

| Repository | Purpose | AI Prompt Reference |
|------------|---------|--------------------|
| `edi-platform-core` | Infrastructure, shared libraries, core functions | Prompts 08, 09, 12 |
| `edi-mappers` | Transaction mappers | Prompt 09 |
| `edi-connectors` | Protocol adapters | Prompt 09 |
| `edi-partner-configs` | Partner configurations | Prompt 13 |
| `edi-data-platform` | ADF and SQL | Prompt 08 |

---

## 20. Next Recommended AI Actions (18-Week Implementation)

### Phase 0: Foundation (Weeks 1-2)

**AI Prompts to Execute**:
1. **01-create-strategic-repos-structure.md**: Create 5 repositories with proper structure
2. **02-create-codeowners.md**: Generate CODEOWNERS for all repos
3. **03-configure-github-variables.md**: Set up repository variables and secrets
4. **04-create-infrastructure-workflows.md**: Generate Bicep CI/CD workflows
5. **05-create-function-workflows.md**: Generate Function CI/CD workflows
6. **06-create-monitoring-workflows.md**: Create drift detection and monitoring workflows
7. **07-create-dependabot-config.md**: Configure automated dependency updates

**Human Actions**:
- Azure subscription provisioning
- GitHub organization setup
- Service principal creation with OIDC
- Branch protection configuration

### Phase 1: Core Platform (Weeks 3-6)

**AI Prompts to Execute**:
1. **08-create-bicep-templates.md**: Generate all infrastructure as code
2. **12-create-shared-libraries.md**: Create 6 NuGet shared libraries
3. **09-create-function-projects.md**: Create InboundRouter and EnterpriseScheduler functions

**Implementation Tasks**:
- Deploy infrastructure to dev environment
- Publish shared libraries to Azure Artifacts
- Implement ADF ingestion pipelines
- Create Log Analytics custom tables
- Build and deploy router function

### Phase 2: Routing Layer (Weeks 7-10)

**AI Prompts to Execute**:
1. **13-create-partner-config-schema.md**: Generate partner configuration schemas
2. **14-create-integration-tests.md**: Create integration test suite

**Implementation Tasks**:
- Configure Service Bus topics and subscriptions
- Implement routing logic with rule evaluation
- Create first routing rules for eligibility
- Deploy and test routing flow
- Set up dead-letter queue handling

### Phase 3: First Trading Partner (Weeks 11-14)

**AI Prompts to Execute**:
1. **15-onboard-trading-partner.md**: Create eligibility partner configuration

**Implementation Tasks** (AI-Generated Code):
- EligibilityMapper function (270/271)
- SftpConnector function
- Partner-specific mapping rules
- Basic 999 acknowledgment generation
- End-to-end integration tests

### Phase 4-6: Scale & Production (Weeks 15-18)

**AI-Generated Components**:
- ClaimsMapper (837/277CA)
- EnrollmentMapper (834) with event sourcing
- RemittanceMapper (835)
- ApiConnector and DatabaseConnector
- Azure SQL control number store
- TA1 and 277CA acknowledgment assembly
- Comprehensive monitoring dashboards
- Operations runbooks

**Human Actions**:
- Security audit and penetration testing
- HIPAA compliance validation
- Partner coordination and UAT
- Production deployment approval
- Operations team training

### AI Code Generation Workflow

1. **Select Prompt**: Choose from `implementation-plan/ai-prompts/`
2. **Execute with Copilot**: Paste into GitHub Copilot Chat or Copilot Workspace
3. **Review Output**: Validate generated code against specifications
4. **Run Tests**: Execute validation steps from prompt
5. **Commit**: Push to feature branch and create PR
6. **CI/CD**: Automated testing and deployment
7. **Iterate**: Refine based on feedback and test results

**Expected AI Productivity**:
- Code generation: 10x faster than manual coding
- Test coverage: 85-90% AI-generated
- Documentation: Auto-updated with code changes
- Overall timeline: 36% reduction (18 weeks vs 28 weeks)

---

## 21. How to Use This Document as an AI

- Treat sections 5, 16, 17 as canonical constraints & task templates.
- Before generating new code, cross-reference invariants (section 17) and open questions (section 18) to flag assumption dependencies.
- When modifying or extending infra, ensure Tagging + Observability integration are explicit steps.
- Maintain bidirectional traceability: If a new metric is added, ensure corresponding KQL & documentation are updated in the same change set.

---

## 22. Changelog (This File)

- v1.0 (Initial): Consolidated architectural & operational context for AI enablement.
- v2.0 (October 5, 2025): Updated for strategic multi-repository architecture, 18-week AI-accelerated timeline, comprehensive AI prompt library integration, and alignment with implementation-plan documentation.

---
End of AI Context Overview.
