# Healthcare EDI Ingestion & Routing Platform

## Overview

This repository contains comprehensive architecture specifications, implementation guides, and test artifacts for a HIPAA-aligned Azure platform that ingests healthcare EDI files (X12 834, 837, 277CA, etc.) from trading partners, validates and routes transactions through an event-driven architecture, and manages acknowledgments with SLA tracking.

**Platform Capabilities:**
- **Event-driven ingestion** via SFTP into Azure Data Lake (raw immutable storage)
- **Validation & metadata extraction** with interchange/control number tracking
- **Intelligent routing** using declarative rules and Azure Service Bus
- **Outbound acknowledgment orchestration** (TA1, 999, 277CA) with latency monitoring
- **Comprehensive observability** through custom logs, KQL queries, and SLA dashboards
- **Infrastructure as Code** using Bicep modules with GitHub Actions CI/CD
- **Partner self-service portal** specifications (API, domain model, security)

**Current Status (October 2025):**
- ✅ Complete architectural specifications (11 core docs + partner portal series)
- ✅ GitHub Actions CI/CD implementation guide with production-ready workflows
- ✅ Operational runbooks, KQL queries, and monitoring templates
- ⏳ Bicep module scaffolds (Service Bus, Functions) - implementation in progress
- ⏳ Function app implementations (Router, Outbound Orchestrator) - planned

## 📚 Document Index

### Core Architecture & Specifications

| Document | Purpose | Key Topics |
|----------|---------|------------|
| [AI_PROJECT_OVERVIEW.md](AI_PROJECT_OVERVIEW.md) | **AI assistant context** - comprehensive system overview | Domain vocabulary, reasoning patterns, task templates |
| [docs/01-architecture-spec.md](docs/01-architecture-spec.md) | High-level architecture & design principles | Components, data flow, technology stack |
| [docs/02-data-flow-spec.md](docs/02-data-flow-spec.md) | Detailed ingestion & processing flows | Validation, metadata extraction, lineage |
| [docs/03-security-compliance-spec.md](docs/03-security-compliance-spec.md) | Security, IAM, HIPAA controls | Managed identities, encryption, audit logging |
| [docs/07-nfr-risks-spec.md](docs/07-nfr-risks-spec.md) | Non-functional requirements & risk register | Performance, scalability, DR, risk mitigation |
| [docs/08-transaction-routing-outbound-spec.md](docs/08-transaction-routing-outbound-spec.md) | Routing logic & acknowledgment orchestration | Rule engine, control numbers, TA1/999/277CA |
| [docs/09-tagging-governance-spec.md](docs/09-tagging-governance-spec.md) | Azure resource tagging standards | Taxonomy, policy enforcement, cost tracking |
| [docs/11-event-sourcing-architecture-spec.md](docs/11-event-sourcing-architecture-spec.md) | Event sourcing pattern for enrollment system | CQRS, domain events, projections |
| [docs/12-raw-file-storage-strategy-spec.md](docs/12-raw-file-storage-strategy-spec.md) | Immutable storage & retention strategy | Lifecycle policies, compliance, lineage |

### Infrastructure & DevOps

| Document | Purpose | Key Topics |
|----------|---------|------------|
| [docs/04-iac-strategy-spec.md](docs/04-iac-strategy-spec.md) | Infrastructure as Code design | Bicep modules, naming conventions, deployment stages |
| [docs/04a-github-actions-implementation.md](docs/04a-github-actions-implementation.md) | **🚀 Production-ready CI/CD workflows** | OIDC auth, multi-environment CD, drift detection, security scanning |
| [docs/05-sdlc-devops-spec.md](docs/05-sdlc-devops-spec.md) | SDLC practices & branching strategy | PR workflows, quality gates, release management |
| [docs/06-operations-spec.md](docs/06-operations-spec.md) | Operational runbooks & monitoring | Incident response, alerting, SLA tracking, GitHub Actions ops |
| [GITHUB_ACTIONS_SUMMARY.md](GITHUB_ACTIONS_SUMMARY.md) | Summary of GitHub Actions implementation | Capabilities, metrics, validation checklist |

### Implementation Guides

| Document | Purpose | Key Topics |
|----------|---------|------------|
| [implementation-strategy/README.md](implementation-strategy/README.md) | **Ordered implementation playbooks** (1-10) | Step-by-step AI-assisted implementation prompts |
| [implementation-strategy/01-tooling-and-credential-acquisition.md](implementation-strategy/01-tooling-and-credential-acquisition.md) | Azure setup prerequisites | Subscriptions, service principals, tools |
| [implementation-strategy/04-infrastructure-bicep-plan.md](implementation-strategy/04-infrastructure-bicep-plan.md) | Bicep module development plan | Service Bus, Functions, Storage, Key Vault |
| [implementation-strategy/06-application-service-implementation.md](implementation-strategy/06-application-service-implementation.md) | Function app development guide | Router, Outbound Orchestrator, testing |
| [implementation-strategy/09-ci-cd-pipeline-automation.md](implementation-strategy/09-ci-cd-pipeline-automation.md) | Pipeline automation strategy | GitHub Actions deployment workflows |

### Partner Portal Specifications

Trading Partner Self-Service Portal (external-facing web application):

| Document | Purpose | Key Topics |
|----------|---------|------------|
| [docs/partner-portal/README.md](docs/partner-portal/README.md) | **Portal documentation index** | Navigation to all portal specs |
| [docs/partner-portal/01-requirements-functional.md](docs/partner-portal/01-requirements-functional.md) | Functional requirements | User stories, features, workflows |
| [docs/partner-portal/03-architecture.md](docs/partner-portal/03-architecture.md) | Portal architecture design | Tech stack, layers, integration patterns |
| [docs/partner-portal/04-domain-model.md](docs/partner-portal/04-domain-model.md) | Domain entities & relationships | Organization, User, FileSubmission, Acknowledgment |
| [docs/partner-portal/05-api-spec-draft.md](docs/partner-portal/05-api-spec-draft.md) | REST API specification | Endpoints, auth, payloads, error handling |
| [docs/partner-portal/06-data-schema.sql](docs/partner-portal/06-data-schema.sql) | Database schema (PostgreSQL) | Tables, indexes, constraints |
| [docs/partner-portal/07-security-authz.md](docs/partner-portal/07-security-authz.md) | Authentication & authorization | Azure AD B2C, RBAC, multi-tenant isolation |
| [docs/partner-portal/08-observability.md](docs/partner-portal/08-observability.md) | Logging, metrics, KQL queries | Custom logs, dashboards, alerts |


## 📂 Repository Structure

```
├── docs/                           # Architecture & design specifications
│   ├── 01-architecture-spec.md     # Core platform architecture
│   ├── 04a-github-actions-implementation.md  # CI/CD workflows (production-ready)
│   ├── partner-portal/             # Trading partner self-service portal specs
│   │   ├── 03-architecture.md
│   │   ├── 05-api-spec-draft.md
│   │   └── ...
│   └── diagrams/                   # Mermaid diagrams + generated PNGs
│       ├── architecture-overview.mmd
│       ├── routing-sequence.mmd
│       └── png/
├── implementation-strategy/        # Step-by-step implementation playbooks (1-10)
│   ├── 01-tooling-and-credential-acquisition.md
│   ├── 04-infrastructure-bicep-plan.md
│   └── ...
├── infra/bicep/modules/           # Bicep IaC module scaffolds (in progress)
├── config/
│   ├── partners/
│   │   ├── partners.schema.json   # Partner configuration JSON schema
│   │   └── partners.sample.json   # Example partner definitions
│   └── routing/
│       └── routing-rules.json     # Declarative Service Bus routing rules
├── queries/kusto/                  # Operational KQL queries (25+ files)
│   ├── ack_latency.kql            # Acknowledgment latency percentiles
│   ├── control_number_gap_detection.kql
│   ├── dlq_routing_messages.kql
│   └── ...
├── scripts/
│   └── generate-diagrams.ps1      # Mermaid → PNG renderer
├── api/partner-portal/
│   └── openapi.v1.yaml            # Partner Portal OpenAPI spec (planned)
├── ACK_SLA.md                     # SLA targets & KQL quick reference
├── AI_PROJECT_OVERVIEW.md         # AI assistant context & reasoning guide
├── GITHUB_ACTIONS_SUMMARY.md      # CI/CD implementation summary
└── README.md                      # This file
```

## 🚀 Quick Start

### For Architects & Developers

1. **Understand the system**: Start with [AI_PROJECT_OVERVIEW.md](AI_PROJECT_OVERVIEW.md) for comprehensive context
2. **Review architecture**: Read [docs/01-architecture-spec.md](docs/01-architecture-spec.md) for component overview
3. **Explore CI/CD**: See [docs/04a-github-actions-implementation.md](docs/04a-github-actions-implementation.md) for production-ready workflows
4. **Implementation path**: Follow numbered guides in [implementation-strategy/](implementation-strategy/)

### For Operators

1. **Monitoring**: Review operational KQL queries in [queries/kusto/](queries/kusto/)
2. **SLA tracking**: Reference [ACK_SLA.md](ACK_SLA.md) for latency targets and metrics
3. **Runbooks**: See [docs/06-operations-spec.md](docs/06-operations-spec.md) for incident response procedures
4. **GitHub Actions ops**: Follow [docs/06-operations-spec.md §15](docs/06-operations-spec.md) for workflow monitoring

### Validating Partner Configuration

```powershell
npx ajv validate -s ./config/partners/partners.schema.json -d ./config/partners/partners.sample.json
```

## 📊 Observability & Monitoring

### Key Resources

- **SLA Targets**: [ACK_SLA.md](ACK_SLA.md) - Acknowledgment latency targets and metrics
- **Routing Rules**: [config/routing/routing-rules.json](config/routing/routing-rules.json) - Declarative routing configuration
- **KQL Queries**: [queries/kusto/](queries/kusto/) - 25+ operational queries for dashboards

### Sample Kusto Queries

| Query File | Purpose | Metrics |
|------------|---------|---------|
| `ack_latency.kql` | Acknowledgment latency distribution | p50, p95, p99 by ack type |
| `syntax_reject_rate_999.kql` | Daily 999 rejection trends | Reject rate percentage |
| `ta1_failure_rate.kql` | Interchange validation failures | TA1 reject trends |
| `277ca_timeliness.kql` | Claim acknowledgment SLA tracking | 837 → 277CA latency |
| `control_number_gap_detection.kql` | Control number continuity check | Gap identification |
| `backlog_unacked_837.kql` | Unacknowledged transaction backlog | Count by age threshold |
| `dlq_routing_messages.kql` | Dead-letter queue monitoring | Failed routing messages |
| `outbound_assembly_latency.kql` | Outbound orchestrator performance | Assembly latency percentiles |

### Example: Acknowledgment Latency Analysis

```kusto
AckAssembly_CL
| where TimeGenerated > ago(24h)
| extend latencySeconds = datetime_diff('second', filePersistedTime, triggerStartTime) * -1
| summarize p50=percentile(latencySeconds,50), p95=percentile(latencySeconds,95), 
            p99=percentile(latencySeconds,99), count() by ackType
| order by p95 desc
```

All queries can be imported into Azure Monitor Workbooks or saved as Log Analytics queries. See [docs/06-operations-spec.md](docs/06-operations-spec.md) for dashboard configuration guidance.

## 🎨 Generating Diagrams

Architecture diagrams are maintained as Mermaid (`.mmd`) files and rendered to PNG:

```powershell
cd scripts
./generate-diagrams.ps1 -Install    # Install mermaid-cli (first time only)
./generate-diagrams.ps1              # Generate all PNGs from .mmd sources
```

**Available Diagrams:**
- `architecture-overview.mmd` - High-level system components
- `routing-sequence.mmd` - Message routing flow
- `outbound-assembly-sequence.mmd` - Acknowledgment generation
- `control-number-flow.mmd` - Control number tracking
- `routing-error-handling.mmd` - Error handling patterns
- `outbound-error-handling.mmd` - Outbound orchestrator errors

**Note:** Current mermaid-cli version has parsing issues with parentheses in first node labels. Use simplified labels for reliability.

## ✨ Key Features & Design Principles

### Architecture Principles

- ✅ **Event-driven orchestration** - No polling; uses Storage Events + Service Bus
- ✅ **Immutable data retention** - Raw files preserved for audit & lineage
- ✅ **Least privilege security** - Managed Identities with scoped RBAC
- ✅ **Configuration-driven routing** - Declarative rules, no hardcoded logic
- ✅ **Everything-as-Code** - Infrastructure, policies, routing rules, partner configs
- ✅ **Observability-first** - Custom logs, metrics, dashboards from day one
- ✅ **Progressive hardening** - Baseline security with layered compliance controls

### Platform Capabilities

| Capability | Status | Details |
|------------|--------|---------|
| Architecture Specs | ✅ Complete | 11 core docs + partner portal series |
| CI/CD Workflows | ✅ Production-ready | GitHub Actions with OIDC, drift detection, security scanning |
| Operational Runbooks | ✅ Complete | Monitoring, alerting, incident response, SLA tracking |
| KQL Queries | ✅ Complete | 25+ queries for dashboards & alerts |
| Bicep Modules | ⏳ In Progress | Service Bus, Functions scaffolds exist |
| Function Apps | ⏳ Planned | Router & Outbound Orchestrator implementations |
| Partner Portal | 📋 Specified | API spec, domain model, security model documented |

## 🎯 Implementation Roadmap

### Phase 1: Foundation (Current)
- [x] Complete architecture specifications
- [x] GitHub Actions CI/CD implementation
- [x] Operational KQL queries and runbooks
- [ ] Complete Bicep modules for all infrastructure

### Phase 2: Core Platform (Next)
- [ ] Deploy baseline infrastructure (Storage, Service Bus, Key Vault)
- [ ] Implement Router Function (config-driven routing)
- [ ] Implement Outbound Orchestrator Function (ack generation)
- [ ] Set up Log Analytics + custom tables
- [ ] Configure monitoring dashboards

### Phase 3: Validation & Operations
- [ ] Implement control number durable store
- [ ] Create synthetic test data generator
- [ ] Deploy drift detection workflows
- [ ] Configure alerting rules & runbook automation
- [ ] Execute end-to-end integration testing

### Phase 4: Partner Portal (Future)
- [ ] Implement portal backend (API + database)
- [ ] Build partner-facing UI
- [ ] Integrate Azure AD B2C authentication
- [ ] Deploy portal monitoring & logging

## 🔒 Security & Compliance

- **HIPAA-aligned architecture** with encryption at rest and in transit
- **Azure Policy enforcement** for tagging, diagnostics, network isolation
- **Managed Identity authentication** - no passwords or connection strings
- **Audit logging** for all data access and control number operations
- **Private endpoints** for secure network connectivity
- **Secret management** via Azure Key Vault with RBAC access control

See [docs/03-security-compliance-spec.md](docs/03-security-compliance-spec.md) for comprehensive security controls.

## 🛠️ CI/CD & Quality Gates

GitHub Actions workflows enforce:

- ✅ **Markdown linting** via markdownlint (config: `.markdownlint.json`)
- ✅ **SQL style checks** via sqlfluff (config: `.sqlfluff`)
- ✅ **Bicep validation** with what-if analysis and security scanning
- ✅ **Infrastructure drift detection** (nightly scheduled runs)
- ✅ **Multi-environment deployment** with manual approval gates
- ✅ **Post-deployment validation** and smoke tests

Extensible to include OpenAPI validation, Function app unit tests, and integration tests in future iterations.

See [docs/04a-github-actions-implementation.md](docs/04a-github-actions-implementation.md) for complete CI/CD implementation.

## 🤝 Contributing

This is an internal specification and implementation repository. When making changes:

1. Follow existing document structure and markdown conventions
2. Update relevant diagrams if architecture changes
3. Add corresponding KQL queries for new observability requirements
4. Maintain consistency with tagging governance standards
5. Reference implementation strategy guides for new capabilities

## 📄 License & Confidentiality

**Internal use only** for healthcare data operations. Contains architectural specifications but no PHI (Protected Health Information). Do not distribute externally without authorization.

---

**Last Updated:** October 2, 2025  
**Repository Maintainer:** Healthcare Platform Engineering Team
