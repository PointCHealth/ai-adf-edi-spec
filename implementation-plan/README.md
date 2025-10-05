# Implementation Plan Index

**Document Version:** 0.2  
**Last Updated:** October 4, 2025  
**Status:** Living Index  
**Owner:** Program Management Office

---

## How to Use This Index

- Navigate the numbered guides in order; agents automatically honor the dependencies captured in each document.  
- Status metadata is updated by GitHub agents as validations complete; no manual edits required.  
- Flag gaps or new workstreams by opening an agent task that adds the row to the appropriate phase.  
- Continuous agent validation replaces manual sign-off, with evidence attached to each update.

---

## Document Catalog

### Core Planning

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 00 | [00-implementation-overview.md](00-implementation-overview.md) | Automated Execution Plan | Master implementation roadmap, milestones, and success criteria |
| 01 | [01-infrastructure-projects.md](01-infrastructure-projects.md) | Agent-Orchestrated Implementation Guide | Azure Bicep project portfolio and deployment strategy |
| 02 | [02-azure-function-projects.md](02-azure-function-projects.md) | Agent-Orchestrated Implementation Guide | Function app architecture, repositories, and operational patterns |

### Phase 0 - Foundation

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 03 | [03-repository-setup-guide.md](03-repository-setup-guide.md) | Agent-Orchestrated Outline | GitHub org automation, branching guardrails, credential management |
| 04 | [04-development-environment-setup.md](04-development-environment-setup.md) | Agent-Orchestrated Outline | Developer workstation prerequisites, local testing stack |

### Phase 1 - Core Platform

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 05 | [05-phase-1-core-platform.md](05-phase-1-core-platform.md) | Agent-Orchestrated Outline | Sprint plan for foundational infrastructure and pipelines |
| 06 | [06-adf-pipeline-project.md](06-adf-pipeline-project.md) | Agent-Orchestrated Outline | Azure Data Factory structure, pipeline catalog, deployment flow |
| 07 | [07-storage-container-structure.md](07-storage-container-structure.md) | Agent-Orchestrated Outline | Data Lake Gen2 hierarchy, naming, lifecycle policies |

### Phase 2 - Routing Layer

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 08 | [08-phase-2-routing-layer.md](08-phase-2-routing-layer.md) | Agent-Orchestrated Outline | Routing sprint plan, Service Bus provisioning, validation gates |
| 09 | [09-service-bus-configuration.md](09-service-bus-configuration.md) | Agent-Orchestrated Outline | Topic topology, SQL filters, DLQ procedures, monitoring |

### Phase 3 - First Trading Partner

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 10 | [10-phase-3-first-trading-partner.md](10-phase-3-first-trading-partner.md) | Agent-Orchestrated Outline | Pilot partner onboarding, mapper/connector tasks, go-live playbook |
| 11 | [11-phase-4-scale-partners.md](11-phase-4-scale-partners.md) | Agent-Orchestrated Outline | Scaling additional transactions, performance, migration approach |
| 12 | [12-partner-onboarding-playbook.md](12-partner-onboarding-playbook.md) | Agent-Orchestrated Outline | Repeatable onboarding workflows, questionnaires, readiness checks |

### Database Projects

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 13 | [13-database-project-control-numbers.md](13-database-project-control-numbers.md) | Agent-Orchestrated Outline | Control number store schema, deployment scripts, validation |
| 14 | [14-database-project-enrollment-eventstore.md](14-database-project-enrollment-eventstore.md) | Agent-Orchestrated Outline | Enrollment event sourcing design, replay strategy, performance |

### Phase 5 - Outbound Assembly

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 15 | [15-phase-5-outbound-assembly.md](15-phase-5-outbound-assembly.md) | Agent-Orchestrated Outline | Coordinated build-out for acknowledgments and orchestration |
| 16 | [16-outbound-orchestrator-implementation.md](16-outbound-orchestrator-implementation.md) | Agent-Orchestrated Outline | Durable Functions orchestration patterns and safeguards |
| 17 | [17-enterprise-scheduler-implementation.md](17-enterprise-scheduler-implementation.md) | Agent-Orchestrated Outline | Scheduling service architecture, blackout handling, observability |

### Configuration Management

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 18 | [18-configuration-projects.md](18-configuration-projects.md) | Agent-Orchestrated Outline | Partner and mapping configuration repositories, CI/CD strategy |
| 19 | [19-partner-configuration-schema.md](19-partner-configuration-schema.md) | Agent-Orchestrated Outline | Canonical partner metadata schema and credential model |
| 20 | [20-mapping-rules-specification.md](20-mapping-rules-specification.md) | Agent-Orchestrated Outline | Mapping rule schema, transformation functions, validation rules |

### Quality Engineering

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 21 | [21-testing-strategy.md](21-testing-strategy.md) | Agent-Orchestrated Outline | Testing pyramid, tooling, and quality gates |
| 22 | [22-integration-testing-project.md](22-integration-testing-project.md) | Agent-Orchestrated Outline | Shared test harness, contract tests, load and chaos coverage |
| 23 | [23-test-data-management.md](23-test-data-management.md) | Agent-Orchestrated Outline | Synthetic data generation, masking, refresh cadence |

### CI/CD & Deployment

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 24 | [24-cicd-pipeline-implementation.md](24-cicd-pipeline-implementation.md) | Agent-Orchestrated Outline | Standard GitHub Actions workflows, scanning, artifact flow |
| 25 | [25-deployment-strategy.md](25-deployment-strategy.md) | Agent-Orchestrated Outline | Environment promotion, approvals, production guardrails |
| 26 | [26-shared-libraries-development.md](26-shared-libraries-development.md) | Agent-Orchestrated Outline | Shared NuGet governance, release management, testing |

### Phase 6 - Production Hardening

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 27 | [27-phase-6-production-hardening.md](27-phase-6-production-hardening.md) | Agent-Orchestrated Outline | Pre-launch hardening checklist and support readiness |
| 28 | [28-security-audit-checklist.md](28-security-audit-checklist.md) | Agent-Orchestrated Outline | HIPAA audit evidence, penetration remediation, compliance |
| 29 | [29-performance-optimization.md](29-performance-optimization.md) | Agent-Orchestrated Outline | Benchmark targets, tuning backlog, cost-performance balance |
| 30 | [30-disaster-recovery-plan.md](30-disaster-recovery-plan.md) | Agent-Orchestrated Outline | RTO/RPO commitments, failover procedures, recovery drills |

### Operations & Governance

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 31 | [31-operations-runbooks.md](31-operations-runbooks.md) | Agent-Orchestrated Outline | Incident response, escalation paths, manual procedures |
| 32 | [32-monitoring-dashboard-implementation.md](32-monitoring-dashboard-implementation.md) | Agent-Orchestrated Outline | Dashboards, KQL library, alert rule deployment |
| 33 | [33-cost-management-plan.md](33-cost-management-plan.md) | Agent-Orchestrated Outline | Cost tracking, budget alerts, optimization cadence |

### Knowledge Management

| ID | Document | Status | Summary |
|----|----------|--------|---------|
| 34 | [34-api-documentation-standards.md](34-api-documentation-standards.md) | Agent-Orchestrated Outline | API documentation templates, schema publishing, versioning |
| 35 | [35-knowledge-transfer-plan.md](35-knowledge-transfer-plan.md) | Agent-Orchestrated Outline | Training assets, handoff timelines, onboarding flow |
| 36 | [36-architecture-decision-records.md](36-architecture-decision-records.md) | Agent-Orchestrated Outline | ADR process, decision register, review cadence |
| 37 | [37-glossary-and-terminology.md](37-glossary-and-terminology.md) | Agent-Orchestrated Outline | Shared vocabulary for EDI, Azure, and compliance terms |
| 38 | [38-reference-architecture-diagrams.md](38-reference-architecture-diagrams.md) | Agent-Orchestrated Outline | Diagram inventory, modeling standards, update workflow |
| 39 | [39-vendor-and-tool-inventory.md](39-vendor-and-tool-inventory.md) | Agent-Orchestrated Outline | Third-party tools, licensing, support contacts |
| 40 | [40-project-retrospective-template.md](40-project-retrospective-template.md) | Agent-Orchestrated Outline | Retrospective format, metrics, continuous improvement loop |

---

## Governance & Next Actions

- GitHub agents maintain ownership mappings via the workspace manifest and populate outlines with curated guidance.  
- Supporting assets (Bicep modules, diagrams, scripts) are linked automatically as adjacent workstreams publish them.  
- Automated maturity pipelines promote documents from outline to ready once validation gates pass.  
- This index refreshes whenever agent workflows report a status update or add new deliverables.
