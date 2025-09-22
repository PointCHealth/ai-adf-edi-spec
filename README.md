# Healthcare EDI Ingestion Platform (Azure Data Factory + Data Lake)

## Overview

This repository contains architecture and governance specifications for a HIPAA-aligned Azure platform ingesting healthcare EDI files (X12 and related) from trading partners via SFTP into an Azure Data Lake with event-driven orchestration using Azure Data Factory.

## Document Index

| Doc | Purpose |
|-----|---------|
| [docs/01-architecture-spec.md](docs/01-architecture-spec.md) | High-level architecture, components, principles |
| [docs/02-data-flow-spec.md](docs/02-data-flow-spec.md) | Detailed ingestion/data flow, validation, metadata model |
| [docs/03-security-compliance-spec.md](docs/03-security-compliance-spec.md) | Security, IAM, HIPAA controls, auditing |
| [docs/04-iac-strategy-spec.md](docs/04-iac-strategy-spec.md) | Infrastructure as Code design, modules, deployment workflow |
| [docs/05-sdlc-devops-spec.md](docs/05-sdlc-devops-spec.md) | Branching, CI/CD, quality gates, release management |
| [docs/06-operations-spec.md](docs/06-operations-spec.md) | Runbooks, monitoring, alerting, operational KPIs |
| [docs/07-nfr-risks-spec.md](docs/07-nfr-risks-spec.md) | Non-functional requirements and risk register |
| [docs/08-transaction-routing-outbound-spec.md](docs/08-transaction-routing-outbound-spec.md) | Routing layer & outbound acknowledgments/response flows |
| [docs/09-tagging-governance-spec.md](docs/09-tagging-governance-spec.md) | Azure resource & data tagging standards, enforcement, taxonomy |

## Repository Structure Additions

| Path | Purpose |
|------|---------|
| `infra/bicep/modules/` | Bicep module scaffolds (Service Bus, Router, Outbound Orchestrator) |
| `config/partners/partners.schema.json` | JSON schema for partner configuration validation |
| `config/partners/partners.sample.json` | Example partner definitions |
| `queries/kusto/` | Operational Kusto query snippets (latency, DLQ, control numbers) |
| `ACK_SLA.md` | Acknowledgment/response SLA quick reference & KQL snippets |
| `config/routing/routing-rules.json` | Declarative Service Bus subscription routing rules |
| `docs/diagrams/` | Mermaid source `.mmd` files |
| `docs/diagrams/png/` | Generated PNG diagrams |
| `scripts/generate-diagrams.ps1` | Script to render Mermaid to PNG |

## Using Partner Config Schema

Validate a partner config file locally (example PowerShell command to install and run `ajv` via npx):

```powershell
npx ajv validate -s ./config/partners/partners.schema.json -d ./config/partners/partners.sample.json
```

## Kusto Query Snippets & Observability Assets

Central references:

- SLA & Metrics: see [`ACK_SLA.md`](ACK_SLA.md)
- Routing Rules: [`config/routing/routing-rules.json`](config/routing/routing-rules.json)
- Queries directory: [`queries/kusto/`](queries/kusto/)

Current sample files:

- `ack_latency.kql` – Ack latency distribution (p50/p95/p99)
- `syntax_reject_rate_999.kql` – Daily 999 syntax reject rate
- `ta1_failure_rate.kql` – Interchange TA1 reject trend
- `277ca_timeliness.kql` – 837 -> 277CA latency percentiles
- `control_number_gap_detection.kql` – Prototype control number gap finder

Example inline (Ack latency over last 24h):

```kusto
AckAssembly_CL
| where TimeGenerated > ago(24h)
| extend latencySeconds = datetime_diff('second', filePersistedTime, triggerStartTime) * -1
| summarize p50=percentile(latencySeconds,50), p95=percentile(latencySeconds,95), p99=percentile(latencySeconds,99), count() by ackType
| order by p95 desc
```

Example 999 reject rate:

```kusto
AckAssembly_CL
| where TimeGenerated > ago(7d) and ackType == '999'
| summarize total=count(), rejects=countif(ak9Status == 'R') by bin(TimeGenerated,1d)
| extend rejectRate = rejects * 100.0 / total
```

Example TA1 failure rate:

```kusto
InterchangeValidation_CL
| where TimeGenerated > ago(14d)
| summarize total=count(), failures=countif(status == 'REJECT') by bin(TimeGenerated,1d)
| extend failureRate = failures * 100.0 / total
```

Import files under `queries/kusto/` into a workbook or saved queries for dashboards referenced in `06-operations-spec.md`.

## Diagram Generation

Generate PNGs (requires Node/npm):

```powershell
cd scripts
./generate-diagrams.ps1 -Install
./generate-diagrams.ps1
```

Then view images referenced in docs. Update a `.mmd` file and rerun to refresh PNG.

Note: The current mermaid-cli version in this environment produced parse errors when parentheses were included in the first node label of a flowchart (e.g., `Trading Partners (SFTP Sources)`). Simplified labels (removing those parentheses) render reliably. If you upgrade mermaid-cli later, you can reintroduce richer labels incrementally and regenerate.

Import files under `queries/kusto/` into a workbook or saved queries for dashboards referenced in `06-operations-spec.md`.

## Quick Start (Planned)

1. Clone repository & review architecture spec
2. Deploy baseline infra (Bicep) to dev subscription (coming soon under `infra/`)
3. Configure partner sample in `config/partners/partners.json`
4. Trigger synthetic test file ingestion script (planned under `scripts/`)

## Core Principles

- Event-driven ingestion (no polling)
- Immutable raw retention & lineage
- Least privilege with Managed Identities
- Everything-as-Code (infra, policy, pipelines export)
- Observability and metrics baked in

## Next Steps / TODO (Future Implementation Phase)

- Add Bicep modules under `infra/bicep` matching spec
- Implement ADF pipeline JSON exports + import pipeline
- Provide synthetic ingestion PowerShell & Python scripts
- Add partner configuration schema validation script
- Integrate policy assignment deployment pipeline
- Implement routing Function + Service Bus topic (`edi-routing`) and Outbound Orchestrator per specs
- Add control number counter store & monitoring queries
- Flesh out Function implementations (Router + Outbound Orchestrator) using provided Bicep scaffolds

## License / Confidentiality

Internal use for healthcare data operations (contains no PHI). Do not distribute externally without approval.

---
