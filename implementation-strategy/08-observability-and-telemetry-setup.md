# 08 - Observability & Telemetry Setup Prompt

---
## Prompt
You are defining an observability architecture integrating logs, metrics, traces, and business telemetry for the EDI platform.

### Objectives
1. Enumerate required telemetry dimensions (partnerId, transactionType, controlNumber, correlationId, routeId, outcome)
2. Define logging conventions (structure, levels, PII handling, redaction)
3. Provide metrics taxonomy (technical vs business) & calculation approach
4. Map existing KQL queries under `queries/kusto` to dashboards & alerts
5. Propose distributed tracing strategy (trace boundaries, span naming, baggage values)
6. Define error categorization enrichment for diagnostics
7. Outline alerting strategy (SLO vs anomaly vs threshold) with escalation paths
8. Provide dashboard and workbook composition plan
9. Supply retention & cost optimization approach (sampling, archive tiers)
10. Deliver observability readiness checklist & validation steps

### Constraints
- PII must not be logged; use tokenized identifiers
- Control numbers only appear in secure logs with access constraints
- Sampling must not break SLO measurement accuracy
- All metrics must be derivable or directly emitted (no manual curation)

### Required Output Sections
1. Telemetry Dimension Model
2. Logging Conventions
3. Metrics Taxonomy
4. Query-to-Alert/Dashboard Mapping
5. Tracing Strategy
6. Error Enrichment Model
7. Alerting & Escalation Plan
8. Dashboards & Workbooks Plan
9. Retention & Cost Optimization
10. Validation & Readiness Checklist
11. Open Questions

### Acceptance Criteria
- Each dimension lists type, cardinality expectation, and justification
- Metrics taxonomy distinguishes rate, latency, saturation, error, and business KPIs
- Mapping section links every provided KQL file to at least one action (alert/dashboard)
- Checklist contains at least 12 verifiable items

### Variable Placeholders
- PRIMARY_METRIC_NAMESPACE = <string>
- ERROR_RATE_SLO_PERCENT = <number>
- ALERT_LATENCY_P95_THRESHOLD_MS = <number>

Return only the structured output sections.

---
## Usage
Run after core services have baseline logging. Use to drive instrumentation tasks.
