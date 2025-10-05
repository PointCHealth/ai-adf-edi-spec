# Implementation Plan Index

**Document Version:** 0.2  
**Last Updated:** October 4, 2025  
**Status:** Living Index  
**Owner:** Program Management Office

---

## How to Use This Index

- Navigate the numbered guides in order; each builds on the dependencies listed in the documents.  
- Track status per document snapshot below; update the metadata block inside each file as it progresses.  
- Flag gaps or new workstreams by raising an issue and adding a new row to the appropriate phase.  
- Keep AI-generated drafts under review until human SMEs sign off.

---

## Document Catalog

### Core Planning

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 00 | [00-implementation-overview.md](00-implementation-overview.md) | Complete | Master implementation roadmap, milestones, and success criteria |
| 01 | [01-infrastructure-projects.md](01-infrastructure-projects.md) | Complete | Azure Bicep project portfolio and deployment strategy |
| 02 | [02-azure-function-projects.md](02-azure-function-projects.md) | Complete | Function app architecture, repositories, and operational patterns |

### Phase 0 - Foundation

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 03 | [03-repository-setup-guide.md](03-repository-setup-guide.md) | Draft Outline | GitHub org automation, branching guardrails, credential management |
| 04 | [04-development-environment-setup.md](04-development-environment-setup.md) | Draft Outline | Developer workstation prerequisites, local testing stack |

### Phase 1 - Core Platform

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 05 | [05-phase-1-core-platform.md](05-phase-1-core-platform.md) | Draft Outline | Sprint plan for foundational infrastructure and pipelines |
| 06 | [06-adf-pipeline-project.md](06-adf-pipeline-project.md) | Draft Outline | Azure Data Factory structure, pipeline catalog, deployment flow |
| 07 | [07-storage-container-structure.md](07-storage-container-structure.md) | Draft Outline | Data Lake Gen2 hierarchy, naming, lifecycle policies |

### Phase 2 - Routing Layer

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 08 | [08-phase-2-routing-layer.md](08-phase-2-routing-layer.md) | Draft Outline | Routing sprint plan, Service Bus provisioning, validation gates |
| 09 | [09-service-bus-configuration.md](09-service-bus-configuration.md) | Draft Outline | Topic topology, SQL filters, DLQ procedures, monitoring |

### Phase 3 - First Trading Partner

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 10 | [10-phase-3-first-trading-partner.md](10-phase-3-first-trading-partner.md) | Draft Outline | Pilot partner onboarding, mapper/connector tasks, go-live playbook |
| 11 | [11-phase-4-scale-partners.md](11-phase-4-scale-partners.md) | Draft Outline | Scaling additional transactions, performance, migration approach |
| 12 | [12-partner-onboarding-playbook.md](12-partner-onboarding-playbook.md) | Draft Outline | Repeatable onboarding workflows, questionnaires, readiness checks |

### Database Projects

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 13 | [13-database-project-control-numbers.md](13-database-project-control-numbers.md) | Draft Outline | Control number store schema, deployment scripts, validation |
| 14 | [14-database-project-enrollment-eventstore.md](14-database-project-enrollment-eventstore.md) | Draft Outline | Enrollment event sourcing design, replay strategy, performance |

### Phase 5 - Outbound Assembly

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 15 | [15-phase-5-outbound-assembly.md](15-phase-5-outbound-assembly.md) | Draft Outline | Coordinated build-out for acknowledgments and orchestration |
| 16 | [16-outbound-orchestrator-implementation.md](16-outbound-orchestrator-implementation.md) | Draft Outline | Durable Functions orchestration patterns and safeguards |
| 17 | [17-enterprise-scheduler-implementation.md](17-enterprise-scheduler-implementation.md) | Draft Outline | Scheduling service architecture, blackout handling, observability |

### Configuration Management

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 18 | [18-configuration-projects.md](18-configuration-projects.md) | Draft Outline | Partner and mapping configuration repositories, CI/CD strategy |
| 19 | [19-partner-configuration-schema.md](19-partner-configuration-schema.md) | Draft Outline | Canonical partner metadata schema and credential model |
| 20 | [20-mapping-rules-specification.md](20-mapping-rules-specification.md) | Draft Outline | Mapping rule schema, transformation functions, validation rules |

### Quality Engineering

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 21 | [21-testing-strategy.md](21-testing-strategy.md) | Draft Outline | Testing pyramid, tooling, and quality gates |
| 22 | [22-integration-testing-project.md](22-integration-testing-project.md) | Draft Outline | Shared test harness, contract tests, load and chaos coverage |
| 23 | [23-test-data-management.md](23-test-data-management.md) | Draft Outline | Synthetic data generation, masking, refresh cadence |

### CI/CD & Deployment

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 24 | [24-cicd-pipeline-implementation.md](24-cicd-pipeline-implementation.md) | Draft Outline | Standard GitHub Actions workflows, scanning, artifact flow |
| 25 | [25-deployment-strategy.md](25-deployment-strategy.md) | Draft Outline | Environment promotion, approvals, production guardrails |
| 26 | [26-shared-libraries-development.md](26-shared-libraries-development.md) | Draft Outline | Shared NuGet governance, release management, testing |

### Phase 6 - Production Hardening

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 27 | [27-phase-6-production-hardening.md](27-phase-6-production-hardening.md) | Draft Outline | Pre-launch hardening checklist and support readiness |
| 28 | [28-security-audit-checklist.md](28-security-audit-checklist.md) | Draft Outline | HIPAA audit evidence, penetration remediation, compliance |
| 29 | [29-performance-optimization.md](29-performance-optimization.md) | Draft Outline | Benchmark targets, tuning backlog, cost-performance balance |
| 30 | [30-disaster-recovery-plan.md](30-disaster-recovery-plan.md) | Draft Outline | RTO/RPO commitments, failover procedures, recovery drills |

### Operations & Governance

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 31 | [31-operations-runbooks.md](31-operations-runbooks.md) | Draft Outline | Incident response, escalation paths, manual procedures |
| 32 | [32-monitoring-dashboard-implementation.md](32-monitoring-dashboard-implementation.md) | Draft Outline | Dashboards, KQL library, alert rule deployment |
| 33 | [33-cost-management-plan.md](33-cost-management-plan.md) | Draft Outline | Cost tracking, budget alerts, optimization cadence |

### Knowledge Management

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 34 | [34-api-documentation-standards.md](34-api-documentation-standards.md) | Draft Outline | API documentation templates, schema publishing, versioning |
| 35 | [35-knowledge-transfer-plan.md](35-knowledge-transfer-plan.md) | Draft Outline | Training assets, handoff timelines, onboarding flow |
| 36 | [36-architecture-decision-records.md](36-architecture-decision-records.md) | Draft Outline | ADR process, decision register, review cadence |
| 37 | [37-glossary-and-terminology.md](37-glossary-and-terminology.md) | Draft Outline | Shared vocabulary for EDI, Azure, and compliance terms |
| 38 | [38-reference-architecture-diagrams.md](38-reference-architecture-diagrams.md) | Draft Outline | Diagram inventory, modeling standards, update workflow |
| 39 | [39-vendor-and-tool-inventory.md](39-vendor-and-tool-inventory.md) | Draft Outline | Third-party tools, licensing, support contacts |
| 40 | [40-project-retrospective-template.md](40-project-retrospective-template.md) | Draft Outline | Retrospective format, metrics, continuous improvement loop |

---

## Governance & Next Actions

- Confirm document owners and populate each outline with authoritative guidance.  
- Link supporting assets (Bicep modules, diagrams, scripts) within each guide as they are produced.  
- Schedule recurring reviews to promote documents from Draft Outline -> In Review -> Approved.  
- Update this index whenever a document status changes or new deliverables are added.
