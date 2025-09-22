# Healthcare EDI Ingestion & Data Lake Platform – Architecture Specification

## 1. Overview / Executive Summary
This document defines the target architecture for ingesting healthcare EDI (e.g., X12 270/271, 276/277, 278, 834, 835, 837, custom CSV/JSON companion outputs) files delivered by external trading partners via SFTP, landing them securely in Azure, and persisting canonical copies plus enriched metadata into an Azure Data Lake for downstream analytics, compliance retention, and operational reporting. The solution emphasizes HIPAA compliance, least‑privilege security, automation, observability, repeatability (Infrastructure as Code), and a governed SDLC.

## 2. Business Goals & Success Criteria
- Reliable near–real‑time ingestion of partner EDI payloads (target under 5 minutes from arrival to raw zone persistence)
- Immutable retention of original (“as received”) artifacts for compliance & dispute resolution (WORM optional per policy)
- Standardized metadata for lineage, partner attribution, transaction set, file integrity, timestamps
- Scalable to > N partners (design target 50+) and peak bursts (e.g., eligibility morning spikes)
- Security & Compliance: HIPAA PHI handling, encryption in transit & at rest, auditable access
- Operational Excellence: automated onboarding, self‑service partner configuration via code + metadata, proactive monitoring & alerting
- Cost Transparency: tagging and cost allocation by environment & workload

## 3. In-Scope
- Ingestion of EDI files via per‑partner SFTP user accounts (Managed SFTP on Storage / Azure SFTP pattern)
- Routing to Azure Data Lake Storage Gen2 with multi‑zone layout (raw / curated / processed)
- Metadata extraction (file, partner, transaction set, size, checksum, received timestamps, processing status)
- Event‑driven orchestration using Azure Data Factory (ADF) pipelines & triggers (option: Event Grid + Azure Functions for advanced parsing)
- Centralized secret & key management (Azure Key Vault)
- Observability: Logging, metrics, lineage, and alerting (Log Analytics, Azure Monitor, Azure Purview / Microsoft Purview)
- Infrastructure as Code (Bicep/Terraform) and DevOps pipelines for promotion across dev/test/prod

## 4. Out-of-Scope (Phase 1)
- Full semantic parsing / transformation of EDI into relational models (will be staged for downstream pipelines)
- Real-time API-based ingestion (e.g., AS2, API gateway transactions)
- Master data management or downstream analytics warehouse modeling
- Data quality rule authoring beyond basic structural validation

## 5. Core Architectural Principles
1. Zero Trust / Least Privilege – RBAC & ACL minimization, just-in-time elevation
2. Separation of Concerns – Ingestion vs. enrichment vs. analytics tiers
3. Idempotent & Replayable – Ability to reprocess from immutable raw store
4. Event-Driven – Triggers fire on file arrival (no polling loops)
5. Declarative Infrastructure – Everything versioned & reproducible via IaC
6. Secure by Default – Encryption, private endpoints, restricted egress
7. Observability First – Unified telemetry, lineage, and SLA tracking
8. Metadata-Centric – All processing actions stamped & queryable

## 6. Target High-Level Architecture
(See accompanying diagram – textual description below.)

![Architecture Overview](./diagrams/png/architecture-overview.png)

[Mermaid source](./diagrams/architecture-overview.mmd)

### Components

- External Trading Partners (SFTP clients)
- Azure Storage (SFTP-enabled hierarchical namespace) – Partner landing containers/folders
- Event Grid (Blob Created events)
- Azure Data Factory – Orchestrates validation, tagging, movement, and status updates
- Optional Azure Function / Container App – Pluggable EDI pre-processor (checksum, virus scan, structural validation)
- Azure Data Lake Storage Gen2 – Multi-zone structure
- Azure Key Vault – Secrets (SFTP local accounts keys/SSH public keys if needed), service principals, encryption keys (if CMK)
- Microsoft Purview – Data catalog, lineage capture (ADF integration)
- Log Analytics Workspace – Central logging, query, alert rules
- Azure Monitor / Action Groups – Alerts (failed pipeline, latency thresholds)
- Azure DevOps / GitHub – Repos, Pipelines (CI for IaC + ADF JSON, CD for releases)
- Azure Active Directory (Entra ID) – Managed Identities for ADF, Functions, Purview scanners
- Azure Service Bus (Topics) – Durable routing fan‑out for downstream subsystem processing (see Routing Layer)

### Routing & Outbound (Preview Overview)

The core ingestion architecture is extended by a Routing Layer that decouples raw file validation/persistence from downstream transactional processing and outbound acknowledgment generation. After a file is validated and the immutable raw copy is persisted, a lightweight routing function (or ADF activity invoking a Function) parses only the envelope headers needed to emit one routing message per ST transaction. These messages are published to a Service Bus Topic (e.g., `edi-routing`) with filterable application properties (`transactionSet`, `partnerCode`, `priority`). Internal subsystem consumers (eligibility, claims, enrollment, remittance) attach subscriptions with SQL filters. This pattern:

1. Prevents tight coupling between ingestion throughput and downstream system responsiveness.
2. Enables independent scaling and retry semantics per subscriber via Service Bus DLQs.
3. Provides a normalized, minimal metadata contract (no PHI) for internal event processing.

Outbound acknowledgment and response generation (TA1, 999, 271, 277, 835) is orchestrated separately (Durable Function or scheduled ADF pipeline) aggregating subsystem outcomes and constructing response EDI files in an outbound staging area before partner pickup. See companion `08-transaction-routing-outbound-spec.md` for full details.

Key additions introduced by the Routing Layer:

- Service Bus Topic: `edi-routing` plus subscription rule governance.
- Routing Function: Stateless, envelope‑peek only (avoid full file parse cost on hot path).
- Correlation IDs: `ingestionId` (file) and `routingId` (per ST) propagate through logs and outbound lineage.
- Outbound Orchestrator: Builds acknowledgment/response artifacts; publishes optional `edi-outbound-ready` signal.

Security Notes (Routing Scope):

- Principle of least privilege: Router granted read on raw container + send on routing topic only.
- No PHI or member identifiers placed into routing messages—envelope & technical metadata only.
- Control numbers managed centrally to avoid duplication; stored in a concurrency‑safe counter store.

Performance Considerations:

- Envelope peek reads only the first N KB of the raw blob; large file size does not linearly impact routing latency.
- Target routing publish latency p95 < 2 seconds from raw persistence.

(Detailed sequencing, message schema, control number governance, and outbound acknowledgment SLAs are defined in `08-transaction-routing-outbound-spec.md`.)

#### Routing Fast Path Sequence (Mermaid)

![Routing Fast Path](./diagrams/png/routing-sequence.png)

[Mermaid source](./diagrams/routing-sequence.mmd)

### Data Lake Zoning (Example)

- `raw/partner=<code>/transaction=<x12set>/ingest_date=YYYY-MM-DD/filename`
- `staging/` (optional structural normalization or decompression)
- `curated/` (downstream transformed model – later phase)
- `metadata/` (catalog exports, process audit logs not in Log Analytics)

### Processing Sequence (Happy Path)

1. Partner uploads file via SFTP to assigned folder (e.g., `/inbound/partnerA/`)
2. Blob Created event emitted to Event Grid
3. Event triggers Data Factory pipeline (or Function which then invokes ADF) with blob URL + metadata
4. Pipeline executes: integrity checks (size > 0, extension matches allowlist), optional AV scan, compute checksum (SHA256)
5. Capture technical + business metadata (partner, transaction code inferred by file naming pattern or header peek) into metadata store (e.g., ADLS metadata folder and/or Purview custom lineage + Log Analytics custom table)
6. Move or copy (recommended: copy original to immutable raw path; optionally set legal hold/WORM if policy) and tag blob with classification labels
7. (Optional) Trigger downstream parsing pipeline (Phase 2) via pipeline dependency or event
8. Emit success/failure telemetry; update status table (e.g., Azure Table Storage or Delta Lake log) for traceability

### Error Handling

- Quarantine container for files failing structural or security validation
- Dead-letter event concept: Events that cause repeated pipeline failure logged and flagged for manual intervention
- Reprocessing: Manual or automated trigger referencing original blob path & metadata

## 7. Logical Architecture Layers

| Layer | Purpose |
|-------|---------|
| Ingestion | Secure reception of partner files (SFTP) |
| Orchestration | Pipeline coordination, conditional branching (ADF) |
| Validation & Prep | Integrity, security, classification |
| Routing Layer | Envelope peek + publish transaction routing events (Service Bus) |
| Storage (Raw) | Immutable retention of originals |
| Storage (Staging/Curated) | (Future) Transformation outputs |
| Outbound Assembly | Generate acknowledgments / response EDI files |
| Metadata & Catalog | Lineage, schema, audit, discovery |
| Observability | Logs, metrics, alerts, SLA dashboards |
| Security & Governance | IAM, encryption, policy, compliance |

## 8. Technology Choices Rationale

- Azure Storage SFTP vs. standalone SFTP VM: PaaS managed, integrates with Blob events, lower ops overhead.
- Event Grid vs. ADF schedule triggers: True event-driven, lower latency and cost vs. polling.
- Data Factory: Native integration with diverse sinks, monitoring UI, Purview lineage.
- Optional Azure Function: Extensible for advanced validations not natively supported.
- Azure Service Bus (Topics): Durable, ordered, filterable fan‑out decoupling ingestion from downstream processing with DLQ isolation.
- Purview: Central governance & lineage (mandatory for regulated data lineage evidence).
- Key Vault & Managed Identities: Eliminates embedded secrets, supports rotation.
- IaC (Bicep preferred, Terraform optional): Declarative, modular, environment parity.

## 9. High-Level Naming Conventions (Illustrative)

- Resource Group: `rg-edi-${env}`
- Storage Account (Landing/Data Lake): `stedi${env}001`, `datalake${env}001`
- Key Vault: `kv-edi-${env}`
- Data Factory: `adf-edi-${env}`
- Log Analytics: `log-edi-${env}`
- Purview: `pvw-edi-${env}`
- Function App: `func-edi-validate-${env}`
- Tags: `env=${env}`, `owner=dataplatform`, `costCenter=...`, `dataSensitivity=PHI`

## 10. Capacity & Scale Considerations

- Target throughput: design for burst 100 files/minute aggregated across partners
- Average file size: assume 1–5 MB (eligibility, claims); plan for occasional 50–100 MB batches (use parallel block blob upload client config if needed)
- Storage performance tier: Hot for landing + raw; lifecycle to Cool/Archive after retention threshold (policy-driven)
- Concurrency: ADF pipeline concurrency limited by integration runtime; scale with parallel activities and separation of validation vs. copy

## 11. Extensibility

- Plug-in parser architecture (Function dispatch by transaction set)
- Partner config file (JSON/Delta) drives dynamic routing, naming validation, and expected frequency SLA
- Feature flags (App Config / Key Vault secrets) to toggle advanced validation steps
- Routing plug-ins: Additional subscription handlers can be added without modifying ingestion pipelines by attaching new filtered Service Bus subscriptions.
- Outbound template library: Segment templates for acknowledgments maintained independently from ingestion code.

## 12. Dependencies & Integrations

- Identity: Entra ID (Managed Identities)
- Security Ops: SIEM integration (export diagnostic logs)
- Downstream Analytics: Synapse / Fabric (Phase 2)
- Internal Transaction Processors: Consume routing messages (claims, eligibility, enrollment, remittance services)
- Outbound Acknowledgment Flow: Consumes subsystem outcomes to build TA1/999/271/277/835 responses

## 13. Assumptions

- Trading partners can be provisioned with SFTP credentials or SSH keys
- File naming patterns follow documented standard to infer transaction types
- Network access to Storage SFTP endpoint is restricted via firewall + private endpoints (partners use public SFTP as required; alternative IP allowlist)

## 14. Open Questions

- Are legal hold / immutability policies (Blob Immutable Storage) mandated for all raw EDI files? Duration?
- Required retention period (e.g., 7 years)?
- Need for near real-time downstream transformations in Phase 1?
- Volume projections per partner for sizing cost model?
- Service Bus namespace multi-tenant vs. dedicated? (Throughput & isolation)
- Preferred orchestrator for outbound (ADF vs. Durable Functions)?
- Control number store implementation (Table vs. Durable entity)?

---
(Additional sections—security, data flow, IaC, SDLC—will be in companion documents.)
