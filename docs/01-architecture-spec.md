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

## Appendix A – Healthcare EDI Transaction Catalog (Overview)

This catalog summarizes commonly supported ASC X12N HIPAA healthcare transaction sets (plus key technical acknowledgments) to ground architectural routing, storage, and outbound response design. For each transaction: purpose, primary business use, salient data elements (envelope + core segments – not exhaustive), typical internal routing destinations, security/PHI considerations, and expected response/acknowledgment patterns are listed. This serves as a master reference for partner onboarding, routing rule authoring, and observability dashboards.

### Legend / Conventions

- Control Numbers: Interchange (ISA13), Functional Group (GS06), Transaction (ST02), Claim/Eligibility control numbers appear in specific segments (e.g., BHT, TRN, CLM, NM1).
- Acknowledgments: TA1 (interchange), 999 (functional syntax), 277CA (claims acknowledgement variant), 271 (eligibility response), 277 (claim status), 835 (remittance), 824 (application advice – optional), 997 (legacy; superseded by 999 but may appear historically), 864 (text report – rare), 820 (payment order – sometimes paired with 835 EFT).
- Routing: Describes the internal subsystem or domain service that consumes the routing message/event (after envelope peek) and any secondary processors (e.g., analytics, compliance audit).
- PHI Sensitivity: High (contains member/claim data), Medium (member identifiers but limited clinical detail), Low (primarily financial/summary) – all treated as PHI under platform security; classification drives minimization in routing metadata.

### A.1 Eligibility Inquiry / Response (270 / 271)

| Aspect | 270 Inquiry | 271 Response |
|--------|-------------|--------------|
| Purpose | Request eligibility & benefit info for a subscriber/dependent | Return coverage, benefit, plan, service-level details |
| Core Segments (beyond envelope) | BHT, HL loops (2000A/B/C/D), NM1 (submitter, receiver, subscriber, dependent), TRN (trace), DTP (service date), EQ (service type), REF (trace/mbr id) | BHT, HL loops mirrored, NM1, TRN (echo), EB (eligibility or benefit), DTP, MSG (text), AAA (rejection), REF |
| Key Identifiers | TRN02 (trace), Subscriber/Member ID (NM109), Provider NPI (NM109 in 2100A) | Echo TRN02, Member ID, EB qualifiers |
| Typical Routing | Eligibility service (real-time or near RT); analytics (volumes, rejection codes) | Returns assembled outbound path to partner via outbound orchestrator |
| Expected Responses | 999 (syntax) and 271 (business) | TA1/999 from partner on our 271 (if partner returns ack); none internally |
| PHI Sensitivity | Medium | Medium |
| Notable Errors | AAA segments (request reject), missing coverage | AAA segments conveying denial reason |

### A.2 Claim (Professional / Institutional / Dental) – 837P / 837I / 837D

| Aspect | Description |
|--------|-------------|
| Purpose | Submit healthcare claims for reimbursement (professional, institutional facility, dental). |
| Core Segments | BHT, NM1 loops (billing provider, subscriber, patient, payer), HL hierarchical loops, CLM (claim), DTP (service dates), SV1/SV2/SV3 (service lines), REF (claim identifiers), HI (diagnosis codes), NM1 rendering/referring providers, AMT, CAS (adjustments – sometimes later). |
| Key Identifiers | CLM01 (claim submitter’s identifier), Patient/Subscriber IDs, Payer ID, Billing provider NPI (NM109), BHT03 (reference). |
| Typical Routing | Claims intake service -> pre-adjudication validation -> claim repository; compliance audit; analytics (lag patterns). |
| Expected Responses | TA1 (if interchange issue), 999 (syntax), 277CA (claim acknowledgment/validation status), later 835 (remittance) and 277 (claim status) depending on lifecycle. |
| PHI Sensitivity | High (diagnosis/procedure). |
| Notable Errors | Validation (invalid codes), duplicate CLM01, subscriber not eligible, provider not authorized. |

### A.3 Remittance Advice – 835

| Aspect | Description |
|--------|-------------|
| Purpose | Communicate adjudicated claim payment details, adjustments, and patient responsibility amounts. |
| Core Segments | BPR (payment order), TRN (trace/EFT reference), REF (payer identifiers), CLP (claim payment info), NM1 loops (payer, payee, patient), CAS (adjustments), AMT (totals), PLB (provider-level adjustments), SVC (service line), DTM (dates). |
| Key Identifiers | TRN02 (trace/EFT), CLP01 (claim control), Payer ID, Payee NPI/TIN. |
| Typical Routing | Remittance processing service -> financial posting, reconciliation, analytics, provider portal export. |
| Expected Responses | 999 (syntax) back to payer if inbound; rarely 824 if application-level issue. Outbound side: none beyond partner’s acks. |
| PHI Sensitivity | High (claim/member). |
| Notable Errors | Control total mismatch, missing associated claim, duplicate TRN, adjustment code mapping failures. |

### A.4 Enrollment (Member Maintenance) – 834

| Aspect | Description |
|--------|-------------|
| Purpose | Add, change, terminate, or reinstate member coverage and demographic details. |
| Core Segments | INS (member action), REF (subscriber/mbr identifiers), DTP (effective dates), NM1 loops (member, sponsor, payer), HD (coverage details), LX (transaction set line number), COB (coordination of benefits), AMT, N1 (sponsor/employer). |
| Key Identifiers | INS03 (maintenance reason), REF*0F (subscriber ID), Member ID, Policy/Group number (REF), Coverage effective dates (DTP). |
| Typical Routing | Enrollment service -> member master data store -> eligibility engine refresh. |
| Expected Responses | TA1 (if structural), 999 (syntax). Some trading partners also exchange 824 for application acceptance/rejection; internally may generate 999 + optional 824. |
| PHI Sensitivity | Medium (demographics, coverage – limited clinical). |
| Notable Errors | Overlapping coverage date, termination without prior enrollment, invalid maintenance reason code. |

### A.5 Claim Status Inquiry / Response – 276 / 277

| Aspect | 276 Inquiry | 277 Response |
|--------|------------|--------------|
| Purpose | Request status of previously submitted claim(s). | Provide status (accepted, denied, pending, paid) and action codes. |
| Core Segments | BHT, HL loops, TRN (trace), REF (claim identifier), DTP (service date), NM1 loops (provider, payer, subscriber), PAT | BHT, HL loops, TRN (echo), STC (status info), REF (claim or control numbers), DTP, SVC (service line status). |
| Key Identifiers | Claim control/reference (REF), TRN02, Provider NPI, Patient ID | STC status codes, echoed claim reference, TRN02. |
| Typical Routing | Claim inquiry processor -> claim repository index lookup. | Claim status service -> outbound assembly. |
| Expected Responses | 999 (syntax), 277 (business). | TA1/999 (partner acks). |
| PHI Sensitivity | Medium (claim reference, limited detail) | Medium |
| Notable Errors | Unknown claim, invalid date range, unauthorized provider | Missing internal claim mapping, stale status. |

### A.6 Health Care Services Review (Prior Authorization) – 278 (Request & Response)

| Aspect | Request (278) | Response (278) |
|--------|-------------|----------------|
| Purpose | Request authorization for healthcare services or admissions. | Grant, pend, modify, or deny services. |
| Core Segments | BHT, HL loops (requester, subscriber, dependent), UM (request details), HCR (certification), HSD (quantity/time), REF (patient/control), DTP (service dates), AAA (reject) | Mirror BHT/HL, UM (review outcome), HCR, REF, DTP, AAA (denial), MSG. |
| Key Identifiers | REF (patient/control), UM01 (request category) | Echo control REF, certification number, UM outcome. |
| Typical Routing | Prior auth service -> clinical/utilization management workflow. | Same service -> outbound response assembly. |
| Expected Responses | 999 (syntax), 278 response (business). | TA1/999 acks from partner on outbound. |
| PHI Sensitivity | High (clinical intent/procedures). | High (clinical outcome). |
| Notable Errors | Missing clinical documentation, invalid service type, coverage inactive | Inconsistent certification, duplicate request. |

### A.7 Payment Order / Remittance – 820 (If Used)

| Aspect | Description |
|--------|-------------|
| Purpose | Transmit premium payment or payment order and remittance information (often payer to plan/employer or employer to payer). |
| Core Segments | BPR (payment), TRN (trace), REF (originator), DTM (dates), N1 loops, ENT (entity detail), RMR (remittance ref), SE. |
| Key Identifiers | TRN02 (trace), RMR02 (invoice/remit ref), Payer/Payee IDs. |
| Typical Routing | Finance/payment reconciliation module; pairing with related 834/benefit invoice. |
| Expected Responses | 999 (syntax) optionally 824 (application) if rejection or balancing issue. |
| PHI Sensitivity | Low (financial, not clinical). |
| Notable Errors | Amount mismatch, unknown invoice reference, duplicate TRN. |

### A.8 Application Advice – 824 (Optional)

| Aspect | Description |
|--------|-------------|
| Purpose | Provide application-level acceptance/rejection (beyond syntactic 999) for inbound 834, 820, 837, etc. |
| Core Segments | BGN (begin), OTI (transaction info), REF (reference), TED (error details), SE. |
| Key Identifiers | OTI02 (group control), OTI03 (transaction set), REF (reference to original), TED segments (error codes). |
| Typical Routing | Generated by application validation module when business content fails (e.g., invalid coverage change). |
| Expected Responses | 999 (syntax) for the 824 itself; no business response. |
| PHI Sensitivity | Low (should avoid detailed PHI – error codes only). |
| Notable Errors | Provided as codes in TED segments. |

### A.9 Functional Acknowledgment – 999 & Legacy 997

| Aspect | Description |
|--------|-------------|
| Purpose | Report syntactic validation results at functional group & transaction level (AK1/AK2/IK3/IK4/AK9). 997 legacy analogous without detailed error codes. |
| Core Segments | AK1, AK2, IK3/IK4 (errors), AK9 (summary). |
| Key Identifiers | AK1/AK2 reference GS06, ST02; AK9 aggregates counts. |
| Typical Routing | Outbound orchestrator after validation engine results aggregated. |
| Expected Responses | Partner may send TA1 if interchange issue with our 999. No further business response. |
| PHI Sensitivity | Low. |
| Notable Errors | Syntax, segment sequence, missing required element. |

### A.10 Interchange Acknowledgment – TA1

| Aspect | Description |
|--------|-------------|
| Purpose | Accept/reject interchange envelope (ISA/IEA) before functional-level processing. |
| Core Segments | TA1 segment within X12 interchange (not its own transaction set). |
| Key Identifiers | Interchange control number (ISA13), date/time, error code. |
| Typical Routing | Immediate generation by envelope validator if structural errors. |
| Expected Responses | None (terminal). |
| PHI Sensitivity | Low. |
| Notable Errors | ISA/IEA mismatch, invalid date, repetition separator error. |

### A.11 Claim Status Response (277) & Claim Acknowledgment (277CA distinction)

| Aspect | Description |
|--------|-------------|
| Purpose | 277CA specifically acknowledges receipt/validation of 837 claim; 277 (status) communicates ongoing adjudication outcomes. |
| Core Segments | STC (status codes), BHT, HL loops, TRN, REF (claim ctrl), SVC (service line), DTP. |
| Key Identifiers | Claim control number (REF), STC01 composite status, TRN02. |
| Typical Routing | Claims status engine -> outbound orchestrator; analytics for turnaround metrics. |
| Expected Responses | 999 from partner for our 277; inbound we produce 999 + downstream claim ingest. |
| PHI Sensitivity | Medium–High depending on included service info. |
| Notable Errors | Status code mapping, orphaned status (no prior claim). |

### A.12 Miscellaneous / Less Common (If Required Future Phases)

- 864 Text Report: human-readable report; rarely used – consider converting to structured log.
- 880 Grocery Products Invoice (not healthcare) – exclude unless multi-industry.
- NCPDP Telecom (non-X12) – distinct standard; out-of-scope here.

### A.13 Transaction to Response Matrix (Summary)

| Inbound Transaction | Primary Business Response | Technical Acks Expected | Possible Additional Responses | Outbound Timing Considerations |
|---------------------|---------------------------|-------------------------|-------------------------------|-------------------------------|
| 270 | 271 | TA1 (if envelope), 999 | 824 (rare) | Near real-time (<2–5 min) |
| 276 | 277 | TA1, 999 | (None) | Near real-time |
| 278 Request | 278 Response | TA1, 999 | 824 (if business rule fail) | Near real-time or short batch |
| 834 | 999 | TA1 | 824 (application advice) | Batch (daily or intra-day) |
| 820 | 999 | TA1 | 824 | Batch (financial settlement windows) |
| 837 (P/I/D) | 999, 277CA, later 277 status, 835 remittance | TA1 | 824 (optional), 277 (subsequent) | Multi-stage lifecycle (minutes to days) |
| 835 | (None – financial) | TA1, 999 | 824 (if we issue application rejection) | Batch (payer schedules) |
| 824 | (None) | TA1, 999 | — | As generated by application engine |
| 999 | (None) | TA1 | — | Within SLA (<15 min) |
| TA1 | (None) | — | — | Immediate |
| 277CA | (Intermediate) | TA1, 999 | 277 (later), 835 (final) | Within hours |
| 277 (status) | 835 (ultimate financial) | TA1, 999 | — | Periodic until final |

### A.14 Routing Metadata Minimization

Only minimal, non-PHI envelope metadata is published on the routing topic: `transactionSet`, `partnerCode`, `interchangeControl`, `functionalGroup`, `stPosition`, `routingId`, `ingestionId`, checksum, and correlation key. Member IDs, claim numbers (CLM01), diagnosis/procedure codes, monetary amounts, and benefit details are deliberately excluded at the routing layer to uphold least-privilege and minimize sensitive data propagation.

### A.15 Observability Crosswalk

| Transaction | Key Metrics | Error Signals | SLA Anchor |
|------------|-------------|--------------|-----------|
| 270/271 | Inquiry volume, response latency | AAA rejects spike | Response latency (<2–5 min) |
| 278 | Auth request count, decision latency | AAA/denials | Decision latency (<15 min initial) |
| 834 | Member adds/terms, reject rate | 824 negative count | Daily batch completion window |
| 837 | Claim intake rate, 277CA issuance latency | 999 rejects, 277CA errors | 999 <15m; 277CA <4h |
| 835 | Payment posting latency | Control total mismatch alerts | Remit availability vs payer SLA |
| 276/277 | Inquiry -> status turnaround | STC error code anomalies | Status response <2–5 min |
| 820 | Payment order variance | Balancing failures | Settlement window adherence |
| 824 | Application reject trends | High error code concentration | N/A (supporting) |
| 999 | Syntax reject ratio | AK9 reject spike | <15 min from ingest |
| TA1 | Interchange reject ratio | Envelope errors per partner | Immediate (<5 min) |

### A.16 Security & Compliance Notes

- Encryption: All transactions at rest & in transit (TLS/SFTP); optional PGP Phase 2 for 834, 837, 835 based on partner requirements.
- Access Segmentation: Claim (837) & Remittance (835) raw paths may require stricter ACLs vs. eligibility (270/271) due to richer PHI & financial data.
- Retention: Proposed uniform baseline (e.g., 7 years) with potential shorter analytic derivative retention; catalog enables differential retention policies by transaction if required.
- Data Masking: Downstream curated views must ensure suppression of unneeded clinical codes for non-claims personas.

### A.17 Future Extensions

- Add FHIR mapping reference table (837 -> Claim FHIR resources; 834 -> Coverage/Enrollment; 270/271 -> CoverageEligibilityRequest/Response) when Phase 2 semantics parsing begins.
- Introduce automated completeness scoring for 837 (presence of HI segments, CLM line counts) feeding quality dashboards.
- Evaluate addition of 275 (attachments) if prior authorization / claim documentation exchange becomes in-scope.

---
