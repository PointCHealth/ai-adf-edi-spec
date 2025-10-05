# Azure Function Projects (C# .NET 9)

**Document Version:** 1.0  
**Last Updated:** October 4, 2025  
**Status:** Agent-Orchestrated Implementation Guide  
**Owner:** GitHub Agent Orchestration

---

## Table of Contents

1. [Overview](#1-overview)
2. [Project Structure Template](#2-project-structure-template)
3. [Router Function Project](#3-router-function-project)
4. [Mapper Function Projects](#4-mapper-function-projects)
5. [Connector Function Projects](#5-connector-function-projects)
6. [Scheduler Function Project](#6-scheduler-function-project)
7. [Shared Libraries](#7-shared-libraries)
8. [Testing Strategy](#8-testing-strategy)
9. [CI and CD Pipeline](#9-ci-and-cd-pipeline)
10. [Operations](#10-operations)

---

## 1. Overview

### 1.1 Function Portfolio

**Note**: Repository assignments reflect the strategic multi-repo structure used from project inception.

| Project | Strategic Repository | Technology | Hosting Plan | Primary Trigger |
| **Router Function** | `edi-platform-core` | C# .NET 8 isolated worker | Premium EP1 | HTTP (from ADF) |
| **Eligibility Mapper** | `edi-mappers` | C# .NET 8 isolated worker | Premium EP1 | Service Bus Topic |
| **Claims Mapper** | `edi-mappers` | C# .NET 8 isolated worker | Premium EP1 | Service Bus Topic |
| **Enrollment Mapper** | `edi-mappers` | C# .NET 8 isolated worker | Premium EP1 | Service Bus Topic |
| **Remittance Mapper** | `edi-mappers` | C# .NET 8 isolated worker | Premium EP1 | Service Bus Topic |
| **SFTP Connector** | `edi-connectors` | C# .NET 8 isolated worker | Premium EP1 | Timer + Blob |
| **API Connector** | `edi-connectors` | C# .NET 8 isolated worker | Premium EP1 | Service Bus Topic |
| **Database Connector** | `edi-connectors` | C# .NET 8 isolated worker | Premium EP1 | Timer + Service Bus |
| **Scheduler** | `edi-platform-core` | C# .NET 8 isolated worker | Premium EP1 | Timer |

**Total Function Apps**: 9 (can be consolidated into fewer apps with multiple functions if preferred).

### 1.2 Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Adopt isolated worker model | Enables dependency injection, modern middleware patterns, and granular control over hosting |
| Premium plan for all apps | Provides VNET integration, predictable scale, and always-on to meet EDI SLAs |
| Separate mapper projects | Aligns deployments per transaction family and isolates partner-specific logic |
| Central shared libraries | Ensures consistent validation, logging, and X12 parsing across projects |
| Infrastructure as code | Bicep templates guarantee compliant deployment and simplify environment parity |

### 1.3 Cross-Cutting Responsibilities

- Enforce correlation IDs on inbound and outbound messages for traceability.
- Emit structured logs to Application Insights with operation and partner metadata.
- Guard every external call (SFTP, HTTP, database) with resilient retry policies.
- Use Key Vault references for secrets; never embed credentials in configuration files.

---

## 2. Project Structure Template

### 2.1 Repository Layout

**Strategic Repository Structure (Phase 3+)**:

**edi-platform-core/functions/router/**:
```text
router/
 src/
    Functions/                # HTTP triggers
    Services/                 # Routing orchestration
    Models/                   # Routing DTOs
    Infrastructure/           # Storage, Service Bus clients
 tests/
    Unit/
    Integration/
 host.json
 local.settings.json.example
 README.md
```

**edi-mappers/eligibility/** (similar for claims, enrollment, remittance):
```text
eligibility/
 src/
    Functions/                # Service Bus triggers
    Services/                 # Mapping orchestration
    Models/                   # Mapper DTOs
    Segments/                 # X12 segment builders
 tests/
    Unit/
    Integration/
 host.json
 local.settings.json.example
 README.md
```

**edi-connectors/sftp/** (similar for api, database):
```text
sftp/
 src/
    Functions/                # Timer/Blob triggers
    Services/                 # SFTP client services
    Models/                   # Connector DTOs
 tests/
    Unit/
    Integration/
 host.json
 local.settings.json.example
 README.md
```

### 2.2 Local Development Requirements

- Install .NET 8 SDK, Azure Functions Core Tools v4, Azurite, and Docker Desktop.
- Provide local secrets via `local.settings.json` (checked-in example only) and developer-specific environment variables.
- Run `dotnet workload update` monthly to keep isolated worker templates in sync.

### 2.3 Configuration Artifacts

- Store environment-specific configuration in `appsettings.{Environment}.json` and publish via deployment pipelines.
- Maintain binding configuration in `host.json` (logging sampling, extension bundles, retry policies).
- Reference routing and partner metadata from `edi-partner-configs` repository rather than embedding duplicates.
- Consume shared libraries via NuGet packages from Azure Artifacts (published from `edi-platform-core`).

---

## 3. Router Function Project

### 3.1 Responsibilities

- Accept file notifications from Azure Data Factory and retrieve blob metadata.
- Parse ISA/GS/ST envelopes to derive transaction metadata (sender, receiver, control number).
- Publish routing messages to Service Bus topics with consistent property naming.

### 3.2 Implementation Highlights

- Use `Azure.Storage.Blobs` with streaming downloads to avoid loading entire files for metadata extraction.
- Apply X12 parsing helpers from `HealthcareEDI.X12Parser` shared library.
- Validate partner configuration before publishing; send malformed messages to dead-letter with context.

### 3.3 Non-Functional Requirements

- Process up to 200 concurrent notifications with idempotent handling.
- Complete routing within 5 seconds average to meet 270/271 response targets.
- Emit telemetry: `RouterFunction.Received`, `RouterFunction.Published`, and `RouterFunction.DeadLettered` events.

---

## 4. Mapper Function Projects

### 4.1 Scope

- Transform canonical payloads from routing into partner-specific EDI transactions.
- Support eligibility, claims, enrollment, and remittance transaction families.
- Apply partner overrides defined in configuration repository.

### 4.2 Design Patterns

- Use strategy pattern to select mapper implementation per partner and transaction set.
- Isolate segment builders in `Segments/` folder to keep functions thin.
- Persist mapper metrics (segment counts, validation errors) to Application Insights custom events.

### 4.3 Quality Considerations

- Validate outbound structures against X12 schemas before publishing.
- Provide regression test suites with golden files per partner.
- Flag mapping drift (when partner configuration mismatches library version) during CI.

---

## 5. Connector Function Projects

### 5.1 Responsibility Matrix

| Connector | Primary Role | Key Integrations |
|-----------|--------------|------------------|
| SFTP | Push assembled files to partner drop zones | SFTP server, Key Vault secrets |
| API | Call partner REST endpoints for real-time submission | HTTP APIs with OAuth or mutual TLS |
| Database | Persist payloads in partner-managed databases | SQL or stored procedure execution |

### 5.2 Implementation Guidance

- Use `Azure.Identity` and Key Vault secrets for credentials; support rotation without redeployments.
- Wrap outbound calls in Polly policies (retry with jitter, circuit breaker for partner outages).
- Publish success and failure events back to Service Bus for downstream auditing.

### 5.3 Error Handling

- Retry transient errors (network failures, throttling) with exponential backoff.
- Route permanent failures to dead-letter queues with full diagnostic context.
- Surface SLA-impacting failures through PagerDuty alerts and dashboards.

---

## 6. Scheduler Function Project

### 6.1 Responsibilities

- Read partner scheduling metadata and compute release windows per transaction family.
- Trigger outbound assembly via Service Bus commands while honoring blackout periods.
- Enable manual run-now execution with concurrency protection.

### 6.2 Implementation Notes

- Store schedules in configuration repository with validation schema.
- Use Durable Timers or cron expressions in Functions runtime based on complexity.
- Persist last-run markers in storage to avoid duplicate releases after restarts.

### 6.3 Observability

- Emit `Scheduler.JobTriggered` and `Scheduler.JobSkipped` events with partner context.
- Track lag between scheduled and actual execution for SLA reporting.
- Provide dashboard showing next 24-hour schedule across partners.

---

## 7. Shared Libraries

**Repository**: `edi-platform-core/shared/`  
**Distribution**: Azure Artifacts (NuGet private feed)

### 7.1 Package Inventory

- `HealthcareEDI.Common`: base abstractions, dependency injection helpers, resilience policies.
- `HealthcareEDI.X12Parser`: EDI parsing utilities, segment builders, schema validators.
- `HealthcareEDI.Logging`: Serilog enrichers, correlation pipeline, Application Insights exporters.
- `HealthcareEDI.Configuration`: strongly typed configuration accessors and caching.
- `HealthcareEDI.ServiceBus`: Service Bus client wrappers and retry policies.
- `HealthcareEDI.MappingEngine`: Mapping rule evaluation engine.

### 7.2 Governance

- Developed and maintained in `edi-platform-core` repository.
- Follow semantic versioning with release notes stored in repository `CHANGELOG.md`.
- Require unit and contract tests before publishing packages to Azure Artifacts.
- Run static analysis (Roslyn analyzers, Sonar) and vulnerability scanning in CI.
- Published automatically on merge to main via GitHub Actions.

### 7.3 Consumption Guidelines

- Centralize package version management in `Directory.Packages.props` in each consuming repository.
- Reference packages from Azure Artifacts feed: `https://pkgs.dev.azure.com/PointCHealth/_packaging/edi-packages/nuget/v3/index.json`.
- Only expose public APIs that are stable; mark experimental types as internal.
- Document breaking changes and provide migration steps two sprints in advance.
- Consuming repositories (`edi-mappers`, `edi-connectors`) automatically notified of new versions via repository dispatch events.

### 7.4 Cross-Repo Updates

When a breaking change is introduced in shared libraries:

1. Publish preview version (e.g., `2.0.0-preview.1`) to Azure Artifacts.
2. Create coordinated PRs in consuming repositories (`edi-mappers`, `edi-connectors`).
3. Update and test all consuming functions with preview version.
4. Merge core library PR → publishes stable version (e.g., `2.0.0`).
5. Merge consuming repository PRs → deploy updated functions.
6. See `03a-repository-migration-strategy.md` Appendix C for detailed workflow.

---

## 8. Testing Strategy

### 8.1 Coverage Expectations

- Unit tests for parsing, mapping, and validation logic with minimum 80% coverage.
- Integration tests leveraging Testcontainers (Service Bus, Storage, SQL) for end-to-end flows.
- Contract tests to ensure outbound payloads meet partner expectations before releases.

### 8.2 Tooling

- xUnit with FluentAssertions for expressive assertions.
- `Azure.Messaging.ServiceBus` test clients and Service Bus Explorer for validation.
- Azure Load Testing scenarios scripted for peak transaction volume simulations.

### 8.3 Automation

- Configure GitHub Actions to run unit and integration suites on every pull request.
- Publish coverage reports to Codecov; fail builds when coverage regresses below threshold.
- Nightly synthetic runs execute representative scenarios in lower environments.

---

## 9. CI and CD Pipeline

### 9.1 Pipeline Organization (Strategic Repositories)

**Per-Repository Pipelines**:

| Repository | Pipeline File | Triggers | Deployment Targets |
|------------|--------------|----------|--------------------|
| `edi-platform-core` | `.github/workflows/deploy-core-functions.yml` | Push to `main`, path: `functions/**` | Router, Scheduler |
| `edi-mappers` | `.github/workflows/deploy-mappers.yml` | Push to `main`, path-specific | Eligibility, Claims, Enrollment, Remittance |
| `edi-connectors` | `.github/workflows/deploy-connectors.yml` | Push to `main`, path-specific | SFTP, API, Database |

**Shared Library Pipeline** (`edi-platform-core`):
- `.github/workflows/publish-nuget.yml`
- Triggers: Push to `main`, path: `shared/**`
- Publishes NuGet packages to Azure Artifacts
- Triggers repository dispatch events to consuming repos

### 9.2 Pipeline Stages (Per Function)

1. **Build and Test**: `dotnet restore`, `dotnet build`, `dotnet test` with coverage.
2. **Static Analysis**: run analyzers, dependency vulnerability scan, and linting.
3. **Package**: create deployment package artifacts (zip for Azure Functions).
4. **Deploy Dev**: use `az functionapp deployment source config-zip` to dev environment.
5. **Integration Tests**: run end-to-end tests in dev environment.
6. **Deploy Test**: promote to test environment with manual approval.
7. **Deploy Prod**: promote to prod environment with change ticket validation.

### 9.3 Path-Based Triggers (Mappers and Connectors)

**Example** (`edi-mappers/.github/workflows/deploy-mappers.yml`):
```yaml
on:
  push:
    branches: [main]
    paths:
      - 'eligibility/**'
      - 'claims/**'
      - 'enrollment/**'
      - 'remittance/**'

jobs:
  deploy-eligibility:
    if: contains(github.event.head_commit.modified, 'eligibility/')
    runs-on: ubuntu-latest
    steps:
      # Build and deploy eligibility mapper only
  
  deploy-claims:
    if: contains(github.event.head_commit.modified, 'claims/')
    runs-on: ubuntu-latest
    steps:
      # Build and deploy claims mapper only
  # ... similar for other mappers
```

### 9.4 Cross-Repo Coordination

**Scenario**: Shared library update triggers redeployment of dependent functions.

**Workflow**:
1. Merge PR in `edi-platform-core/shared/` → publishes NuGet package.
2. GitHub Action triggers repository dispatch event to `edi-mappers` and `edi-connectors`.
3. Consuming repositories receive event, update package references, rebuild, and redeploy.

**Implementation** (see `03a-repository-migration-strategy.md` Section 6.3).

### 9.5 Secrets and Access

- Leverage GitHub OIDC federation with Azure for secretless authentication (per repository).
- Store environment configuration in Azure App Configuration or Key Vault references at deployment time.
- Rotate credentials on a 90-day cadence; enforce alerting when rotation windows are missed.
- Each repository has separate Azure service principal with least-privilege RBAC.

### 9.6 Compliance Gates

- Integrate policy checks (PSRule, Checkov) before production promotion.
- Require change ticket linkage and approver sign-off for production deployments.
- Capture deployment metadata (build number, commit SHA, initiator) for audit trail.
- Cross-repo dependency validation: ensure compatible shared library versions before prod deployment.

---

## 10. Operations

### 10.1 Observability

- Centralize telemetry in Log Analytics; provide KQL queries for latency, error rates, and partner volumes.
- Use Application Insights availability tests to monitor critical HTTP endpoints.
- Tag telemetry with `transactionSet`, `partnerCode`, and `controlNumber` for drill-down.

### 10.2 Support Procedures

- Operate an agent-managed escalation queue with automated incident triage and notification.
- Auto-generate runbooks for replaying failed transactions and clearing dead-letter queues.
- Execute quarterly disaster recovery simulations covering Functions, Service Bus, and storage dependencies.

### 10.3 Continuous Improvement

- Agents analyze incident metrics continuously to surface automation opportunities.
- Track cost per transaction and adjust hosting plans when utilization changes.
- Feed lessons learned back into documentation and shared libraries.
