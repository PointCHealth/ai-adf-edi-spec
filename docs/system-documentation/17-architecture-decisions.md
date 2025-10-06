# Document 17: Architecture Decision Records (ADRs)

**Document Version:** 1.0  
**Last Updated:** October 6, 2025  
**Status:** Active  
**Part of:** EDI Platform System Documentation Series

---

## Table of Contents

1. [Overview](#1-overview)
2. [ADR Index](#2-adr-index)
3. [ADR-001: Event-Driven Architecture](#3-adr-001-event-driven-architecture)
4. [ADR-002: Hybrid Orchestration Pattern](#4-adr-002-hybrid-orchestration-pattern)
5. [ADR-003: X12 Parser Library Selection](#5-adr-003-x12-parser-library-selection)
6. [ADR-004: Event Sourcing for 834 Enrollment](#6-adr-004-event-sourcing-for-834-enrollment)
7. [ADR-005: Multi-Zone Data Lake Pattern](#7-adr-005-multi-zone-data-lake-pattern)
8. [ADR-006: Unified Trading Partner Model](#8-adr-006-unified-trading-partner-model)
9. [ADR-007: Azure Functions for Integration](#9-adr-007-azure-functions-for-integration)
10. [ADR-008: Service Bus Topic-Based Routing](#10-adr-008-service-bus-topic-based-routing)
11. [ADR-009: Control Number Management Strategy](#11-adr-009-control-number-management-strategy)
12. [ADR-010: Infrastructure as Code with Bicep](#12-adr-010-infrastructure-as-code-with-bicep)
13. [ADR-011: GitHub Actions for CI/CD](#13-adr-011-github-actions-for-cicd)
14. [ADR-012: Multi-Repository Strategy](#14-adr-012-multi-repository-strategy)
15. [ADR Review Schedule](#15-adr-review-schedule)
16. [References](#16-references)

---

## 1. Overview

### 1.1 Purpose

Architecture Decision Records (ADRs) document the key architectural choices made during the design and implementation of the Healthcare EDI Platform. Each ADR captures:

- **Context**: The business and technical situation requiring a decision
- **Decision**: The chosen approach and rationale
- **Alternatives**: Options considered and reasons for rejection
- **Consequences**: Trade-offs, benefits, and risks
- **Status**: Current state (Proposed, Accepted, Superseded, Deprecated)

### 1.2 ADR Format

All ADRs follow a consistent structure:

```markdown
# ADR-XXX: Decision Title

**Status:** [Proposed | Accepted | Superseded | Deprecated]
**Date:** YYYY-MM-DD
**Decision Makers:** Team/Role
**Technical Area:** [Architecture | Infrastructure | Security | etc.]

## Context
[Business and technical background]

## Decision
[The chosen approach]

## Rationale
[Why this decision was made]

## Alternatives Considered
[Other options and why they were rejected]

## Consequences
[Benefits, trade-offs, risks, and mitigations]

## Implementation
[How this decision is being implemented]

## References
[Related documents, specifications, external resources]
```

### 1.3 ADR Lifecycle

```text
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌────────────┐
│ Proposed │────▶│ Accepted │────▶│Superseded│────▶│ Deprecated │
└──────────┘     └──────────┘     └──────────┘     └────────────┘
                       │
                       │ (If alternative approach proven better)
                       ▼
                 ┌──────────┐
                 │ Rejected │
                 └──────────┘
```

### 1.4 When to Create an ADR

Create an ADR when making decisions that:

- **Are difficult to reverse**: Fundamental technology choices (databases, messaging platforms)
- **Have long-term impact**: Architectural patterns affecting multiple components
- **Involve trade-offs**: Decisions with significant benefits and drawbacks
- **Require explanation**: Choices that future team members will question
- **Set precedent**: Patterns that should be followed consistently

**Examples**: Choice of cloud provider, authentication mechanism, data storage strategy, integration patterns, deployment approach.

**Non-examples**: Code formatting rules, variable naming conventions, minor library choices.

---

## 2. ADR Index

| ADR | Title | Status | Date | Technical Area |
|-----|-------|--------|------|----------------|
| [ADR-001](#3-adr-001-event-driven-architecture) | Event-Driven Architecture | ✅ Accepted | 2025-09-15 | Architecture |
| [ADR-002](#4-adr-002-hybrid-orchestration-pattern) | Hybrid Orchestration Pattern | ✅ Accepted | 2025-09-18 | Architecture |
| [ADR-003](#5-adr-003-x12-parser-library-selection) | X12 Parser Library Selection | ✅ Accepted | 2025-10-05 | Infrastructure |
| [ADR-004](#6-adr-004-event-sourcing-for-834-enrollment) | Event Sourcing for 834 Enrollment | ✅ Accepted | 2025-09-20 | Architecture |
| [ADR-005](#7-adr-005-multi-zone-data-lake-pattern) | Multi-Zone Data Lake Pattern | ✅ Accepted | 2025-09-16 | Infrastructure |
| [ADR-006](#8-adr-006-unified-trading-partner-model) | Unified Trading Partner Model | ✅ Accepted | 2025-09-22 | Architecture |
| [ADR-007](#9-adr-007-azure-functions-for-integration) | Azure Functions for Integration | ✅ Accepted | 2025-09-25 | Infrastructure |
| [ADR-008](#10-adr-008-service-bus-topic-based-routing) | Service Bus Topic-Based Routing | ✅ Accepted | 2025-09-19 | Architecture |
| [ADR-009](#11-adr-009-control-number-management-strategy) | Control Number Management | ✅ Accepted | 2025-09-28 | Infrastructure |
| [ADR-010](#12-adr-010-infrastructure-as-code-with-bicep) | Infrastructure as Code with Bicep | ✅ Accepted | 2025-09-10 | DevOps |
| [ADR-011](#13-adr-011-github-actions-for-cicd) | GitHub Actions for CI/CD | ✅ Accepted | 2025-09-12 | DevOps |
| [ADR-012](#14-adr-012-multi-repository-strategy) | Multi-Repository Strategy | ✅ Accepted | 2025-09-08 | DevOps |

---

## 3. ADR-001: Event-Driven Architecture

**Status:** ✅ Accepted  
**Date:** September 15, 2025  
**Decision Makers:** Platform Architecture Team  
**Technical Area:** Architecture  
**Supersedes:** N/A

### Context

The Healthcare EDI Platform must process files from trading partners as they arrive via SFTP. Initial design considerations included:

1. **Polling-Based**: Azure Data Factory scheduled triggers checking for new files every N minutes
2. **Event-Driven**: Azure Storage Events triggering pipelines immediately upon file arrival
3. **Hybrid**: Events for inbound, schedules for outbound and reconciliation

**Business Requirements:**

- **Latency**: Files must be processed within 5 minutes of arrival
- **Cost Efficiency**: Minimize unnecessary polling overhead
- **Scalability**: Handle variable partner upload patterns (morning spikes, ad-hoc deliveries)
- **Extensibility**: Support future real-time integration scenarios
- **Auditability**: Track exact arrival time and processing sequence

**Constraints:**

- Azure Storage SFTP emits Blob Created events
- Event Grid provides reliable event delivery with dead-lettering
- Some workflows (outbound acknowledgments, reconciliation) require time-based triggers

### Decision

**Implement a hybrid orchestration pattern combining event-driven processing for partner-initiated inbound flows with time-based scheduling for platform-initiated outbound and reconciliation workflows.**

**Event-Driven (Partner → Platform):**

- Azure Storage emits `Microsoft.Storage.BlobCreated` events
- Event Grid delivers events to Azure Data Factory triggers
- ADF pipelines execute immediately upon file arrival
- Sub-second latency from upload to pipeline start

**Time-Based (Platform → Partner, Internal Reconciliation):**

- Enterprise Scheduler (ADF + Azure Function) manages scheduled workloads
- Governed calendars with blackout windows
- Dependency-aware job execution
- SLA monitoring and alerting

### Rationale

#### Why Event-Driven for Inbound?

1. **Lower Latency**: Sub-second vs. minutes with polling (5-minute poll interval = 2.5 min average delay)
2. **Cost Efficiency**: No wasted pipeline runs checking empty directories
3. **Scalability**: Automatic scaling with Event Grid's elastic capacity
4. **Immediate Response**: Partners see faster acknowledgment generation
5. **Azure-Native**: Leverages platform capabilities without custom code

#### Why Time-Based for Outbound?

1. **Deterministic Timing**: Business requirements for "daily 8 PM enrollment export"
2. **Dependency Management**: Multi-step workflows with sequential dependencies
3. **Blackout Windows**: Avoid partner system maintenance windows
4. **Batching Optimization**: Aggregate transactions for cost-effective delivery
5. **Governance**: Change-controlled schedules in source control

### Alternatives Considered

#### Option 1: Pure Polling Architecture

**Approach**: ADF scheduled triggers every 1-5 minutes for all workflows.

**Pros:**

- Simple mental model
- No Event Grid dependency
- Easier debugging (predictable timing)

**Cons:**

- **Higher cost**: Wasted pipeline runs (estimated 80% empty checks)
- **Higher latency**: Average 2.5 min delay with 5-min polling
- **Not scalable**: Cannot handle partner-specific intervals without N triggers
- **Less responsive**: Poor user experience for real-time partners

**Decision:** ❌ Rejected - Cost and latency unacceptable

---

#### Option 2: Pure Event-Driven Architecture

**Approach**: Event Grid for all workflows, including outbound (timer events).

**Pros:**

- Consistent pattern across all flows
- Maximum responsiveness
- Native cloud design

**Cons:**

- **No governance for schedules**: Timer events don't integrate with source control
- **Difficult dependency management**: Event chaining becomes complex
- **Limited visibility**: Harder to track "what should have run but didn't"
- **Blackout windows**: No built-in calendar management

**Decision:** ❌ Rejected - Insufficient control for time-based workflows

---

#### Option 3: Custom Scheduler Service

**Approach**: Build custom .NET service for all scheduling needs.

**Pros:**

- Full control over scheduling logic
- Custom dependency management
- Flexible calendar support

**Cons:**

- **High development cost**: 4-6 weeks vs. 1 week for hybrid ADF approach
- **Operational burden**: Custom service requires monitoring, updates, scaling
- **Reinventing the wheel**: ADF already provides most needed capabilities
- **Team skillset**: Requires specialized knowledge vs. platform skills

**Decision:** ❌ Rejected - Not cost-effective

### Consequences

#### Benefits

| Benefit | Description | Impact |
|---------|-------------|--------|
| **Optimal Latency** | Event-driven inbound achieves sub-5-minute SLA | High |
| **Cost Efficiency** | 80% reduction in wasted pipeline runs | Medium |
| **Scalability** | Automatic scaling with partner volume | High |
| **Governance** | Time-based schedules in source control | High |
| **Flexibility** | Each workflow type uses optimal pattern | Medium |

#### Trade-offs

| Trade-off | Description | Mitigation |
|-----------|-------------|------------|
| **Complexity** | Two orchestration patterns to understand | Clear documentation; training |
| **Event Grid Dependency** | Additional service in critical path | Monitor Event Grid health; SLA tracking |
| **Debugging Variability** | Event timing less predictable than schedules | Enhanced logging; Event Grid replay |

#### Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Event Grid outage | High | Low | Azure SLA 99.99%; dead-letter queue for retry |
| Event loss | High | Very Low | Event Grid guarantees at-least-once delivery |
| Cost overrun from excessive events | Medium | Low | Budget alerts; event filtering |

### Implementation

#### Phase 1: Event-Driven Inbound (Week 1)

```bicep
resource eventGridTopic 'Microsoft.EventGrid/systemTopics@2021-06-01-preview' = {
  name: 'st-edi-blob-events-${env}'
  location: location
  properties: {
    source: storageAccount.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

resource adfTrigger 'Microsoft.DataFactory/factories/triggers@2018-06-01' = {
  name: 'tr-blob-created'
  properties: {
    type: 'BlobEventsTrigger'
    pipelines: [
      { pipelineReference: { referenceName: 'pl_inbound_validation' } }
    ]
    typeProperties: {
      blobPathBeginsWith: '/inbound/blobs/'
      events: ['Microsoft.Storage.BlobCreated']
    }
  }
}
```

#### Phase 2: Enterprise Scheduler (Week 2)

```yaml
# config/schedules/outbound-enrollment-daily.yml
schedule:
  name: "outbound-enrollment-daily"
  description: "Daily 834 enrollment export to partners"
  cron: "0 20 * * *"  # 8 PM daily
  timezone: "America/New_York"
  enabled: true
  pipeline: "pl_outbound_834_assembly"
  blackoutWindows:
    - start: "2025-12-24T00:00:00Z"
      end: "2025-12-26T23:59:59Z"
      reason: "Holiday freeze"
  dependencies:
    - "internal-enrollment-sync-complete"
  sla:
    maxDurationMinutes: 30
    alertOnFailure: true
```

#### Monitoring

```kql
// Event-driven pipeline latency
StorageBlobLogs
| where OperationName == "PutBlob"
| join kind=inner (
    ADFActivityRun
    | where PipelineName == "pl_inbound_validation"
    | where Status == "Succeeded"
  ) on $left.CorrelationId == $right.BlobCorrelationId
| summarize 
    avg_latency_seconds = avg(datetime_diff('second', PipelineStart, BlobCreated)),
    p95_latency_seconds = percentile(datetime_diff('second', PipelineStart, BlobCreated), 95)
  by bin(BlobCreated, 1h)
```

### References

- [Document 01: Architecture Specification](../01-architecture-spec.md)
- [Document 08: Transaction Routing and Outbound](./08-transaction-routing-outbound-spec.md)
- [Document 14: Enterprise Scheduler](../14-enterprise-scheduler-spec.md)
- [Azure Event Grid Documentation](https://docs.microsoft.com/azure/event-grid/)

---

## 4. ADR-002: Hybrid Orchestration Pattern

**Status:** ✅ Accepted  
**Date:** September 18, 2025  
**Decision Makers:** Platform Architecture Team  
**Technical Area:** Architecture  
**Related to:** ADR-001 (Event-Driven Architecture)

### Context

Following the decision to use event-driven architecture for inbound processing (ADR-001), we needed to define the complete orchestration strategy covering:

1. **Inbound Processing**: Partner → Platform (event-driven)
2. **Routing and Transformation**: Platform routing layer
3. **Outbound Delivery**: Platform → Partner (time-based or responsive)
4. **Reconciliation**: Daily, weekly, monthly jobs
5. **Acknowledgment Generation**: TA1, 999, 271, 277, 835 responses

**Key Questions:**

- Should all workflows use the same orchestration mechanism?
- How do we handle both partner-initiated and platform-initiated flows?
- What tooling provides the best balance of capability and simplicity?

### Decision

**Adopt a hybrid orchestration pattern using:**

1. **Azure Data Factory (ADF)** for data movement and batch orchestration
2. **Azure Functions** for lightweight transformation and routing logic
3. **Azure Service Bus** for durable message queuing and fan-out
4. **Enterprise Scheduler** (ADF + Function) for time-based workflows

**Workflow Assignment:**

| Workflow Type | Orchestration Tool | Trigger Type | Example |
|---------------|-------------------|--------------|---------|
| Inbound Validation | ADF Pipeline | Event Grid | File arrival → validation → raw storage |
| Transaction Routing | Azure Function | Blob Created | Parse envelope → publish routing message |
| Transaction Processing | Azure Function | Service Bus | Transform 270 → partner format |
| Outbound Assembly | ADF Pipeline | Scheduled | Daily acknowledgment file generation |
| Reconciliation | ADF Pipeline | Scheduled | Weekly control number audit |

### Rationale

#### Why Hybrid vs. Single Tool?

**Strengths by Tool:**

| Tool | Best For | Example Use Case |
|------|----------|------------------|
| **ADF** | Data movement, orchestration, dependency management | Copy blob, execute notebook, conditional branching |
| **Functions** | Transformation logic, API integration, envelope parsing | X12 parser, JSON transformation, HTTP callout |
| **Service Bus** | Durable queuing, fan-out, retry policies | Route message to 5 partners with different retry SLAs |

**Weakness of Single-Tool Approach:**

- **ADF-only**: Poor fit for complex transformation logic (limited expression language)
- **Functions-only**: Requires custom orchestration code for data pipelines
- **Logic Apps-only**: Cost prohibitive at scale; limited local dev/test

#### Why Not Durable Functions for Everything?

**Durable Functions** were considered for all orchestration:

**Pros:**

- Code-based orchestration (full C# expressiveness)
- Built-in retry and timeout handling
- Strong developer experience (local debugging)

**Cons:**

- **No visual designer**: Harder for ops teams to understand workflows
- **Storage overhead**: Orchestration state in Azure Storage tables (cost, latency)
- **Complexity for simple pipelines**: Overkill for "copy blob from A to B"
- **ADF integration**: Would still need ADF for data movement; Durable Functions can't replace

**Decision:** Use Durable Functions selectively for complex stateful orchestrations (e.g., saga patterns), not as primary orchestration layer.

### Alternatives Considered

#### Option 1: ADF-Only Architecture

**Approach**: All workflows implemented as ADF pipelines with data flows.

**Pros:**

- Single orchestration tool
- Visual pipeline designer
- Built-in monitoring

**Cons:**

- **Limited transformation expressiveness**: ADF data flows complex for X12 parsing
- **Cold start latency**: 30-60 seconds for event-triggered pipelines
- **Cost**: Data flow compute expensive for lightweight transformations
- **Testing**: Difficult to unit test ADF expressions

**Decision:** ❌ Rejected - Not suitable for lightweight transformations

---

#### Option 2: Functions-Only Architecture

**Approach**: All workflows orchestrated with Durable Functions.

**Pros:**

- Full C# programming model
- Excellent local dev experience
- Fine-grained control

**Cons:**

- **Reinventing data movement**: Would need custom blob copy code
- **Ops complexity**: No visual workflow representation
- **Monitoring overhead**: Custom dashboards needed
- **Team skillset**: Requires advanced C# knowledge

**Decision:** ❌ Rejected - Poor fit for data-centric pipelines

---

#### Option 3: Logic Apps Standard

**Approach**: Use Logic Apps Standard for all orchestration.

**Pros:**

- Visual designer + code-based development
- Built-in connectors for Azure services
- Hybrid cloud capabilities

**Cons:**

- **Cost**: $0.20/execution = $20K/month at 100K files/month
- **Performance**: Slower than Functions for high-throughput scenarios
- **Vendor lock-in**: Workflow definition language not portable
- **Limited local testing**: Emulator not feature-complete

**Decision:** ❌ Rejected - Cost prohibitive

### Consequences

#### Benefits

| Benefit | Description |
|---------|-------------|
| **Right Tool for Job** | Each component uses optimal technology for its purpose |
| **Performance** | Functions provide <100ms routing, ADF handles bulk data movement |
| **Cost Efficiency** | Avoid expensive data flow compute for simple transformations |
| **Maintainability** | Visual pipelines for data ops, code for business logic |
| **Testability** | Unit test Functions; integration test ADF |

#### Trade-offs

| Trade-off | Description | Mitigation |
|-----------|-------------|------------|
| **Multiple Tools** | Team must learn ADF, Functions, Service Bus | Cross-training; clear pattern guidelines |
| **Integration Testing** | Must test across tool boundaries | End-to-end test harness with synthetic events |
| **Debugging Complexity** | Trace workflows across multiple services | Unified logging with correlation IDs |

### Implementation

#### Routing Function Example

```csharp
[FunctionName("RoutingFunction")]
public async Task Run(
    [BlobTrigger("raw/{partner}/{filename}")] Stream blob,
    [ServiceBus("edi-routing", Connection = "ServiceBusConnection")] IAsyncCollector<ServiceBusMessage> output,
    ILogger log)
{
    // Parse envelope (first 1KB)
    var envelope = await _x12Parser.ParseEnvelopeAsync(blob, maxBytes: 1024);
    
    // Create routing message per transaction
    foreach (var transaction in envelope.Transactions)
    {
        var routingMsg = new ServiceBusMessage(JsonSerializer.Serialize(new {
            routingId = Guid.NewGuid(),
            ingestionId = envelope.IngestionId,
            transactionSet = transaction.TransactionSetIdentifier,
            partnerCode = envelope.SenderId,
            fileBlobPath = blobTrigger,
            stPosition = transaction.Position
        }));
        
        routingMsg.ApplicationProperties["transactionSet"] = transaction.TransactionSetIdentifier;
        routingMsg.ApplicationProperties["partnerCode"] = envelope.SenderId;
        
        await output.AddAsync(routingMsg);
    }
}
```

#### ADF Outbound Pipeline

```json
{
  "name": "pl_outbound_acknowledgment",
  "activities": [
    {
      "name": "FetchPendingAcknowledgments",
      "type": "Lookup",
      "typeProperties": {
        "source": { "type": "AzureSqlSource", "query": "SELECT * FROM PendingAcknowledgments" }
      }
    },
    {
      "name": "GenerateX12Files",
      "type": "AzureFunctionActivity",
      "dependsOn": [{ "activity": "FetchPendingAcknowledgments" }],
      "typeProperties": {
        "functionName": "GenerateAcknowledgment",
        "body": { "@activity('FetchPendingAcknowledgments').output" }
      }
    },
    {
      "name": "CopyToSFTP",
      "type": "Copy",
      "dependsOn": [{ "activity": "GenerateX12Files" }]
    }
  ]
}
```

### Monitoring

```kql
// Cross-component latency tracking
union 
  (ADFPipelineRun | where PipelineName == "pl_inbound_validation"),
  (FunctionExecutions | where FunctionName == "RoutingFunction"),
  (ServiceBusLogs | where Topic == "edi-routing")
| where CorrelationId == "<ingestionId>"
| project Timestamp, Component = case(
    isnotempty(PipelineName), "ADF",
    isnotempty(FunctionName), "Function",
    "ServiceBus"
  ), Duration
| order by Timestamp asc
```

### References

- [ADR-001: Event-Driven Architecture](#3-adr-001-event-driven-architecture)
- [Document 08: Transaction Routing](./08-transaction-routing-outbound-spec.md)
- [Azure Functions Documentation](https://docs.microsoft.com/azure/azure-functions/)

---

## 5. ADR-003: X12 Parser Library Selection

**Status:** ✅ Accepted  
**Date:** October 5, 2025  
**Decision Makers:** Platform Engineering Team  
**Technical Area:** Shared Libraries

### Context

The Healthcare EDI Platform requires a robust X12 EDI parser to handle HIPAA-compliant healthcare transactions (270, 271, 834, 835, 837, 277). The parser must support parsing X12 format, generating X12 format, healthcare transactions (HIPAA 5010), .NET 9 compatibility, NuGet availability, high performance, active maintenance, and clear error handling.

### Decision

**Use OopFactory.X12 as the primary X12 parsing library**, wrapped in a custom abstraction layer (`HealthcareEDI.X12`) to provide healthcare-specific helpers and enable future migration if needed.

**NuGet Package:** `OopFactory.X12` (Version 3.0.0)  
**License:** MIT License (permissive, commercial use allowed)  
**Repository:** https://github.com/Eddy-Guido/OopFactory.X12

### Rationale

#### Pros

- **Open Source & Free**: MIT license, no licensing costs
- **Healthcare Support**: Built-in HIPAA 5010 transaction support
- **Strong Parsing**: Handles complex nested loops and hierarchical structures
- **X12 Generation**: Creates syntactically valid EDI files
- **Active Community**: Ongoing maintenance and bug fixes
- **.NET 9 Compatible**: Works with current platform target
- **Intuitive API**: LINQ-friendly query patterns

#### Cons

- **Less Feature-Rich**: Not as comprehensive as commercial options (BizTalk, Edifecs)
- **Documentation**: Limited official documentation, relies on community examples
- **Performance**: No official benchmarks (requires testing)
- **Breaking Changes**: Open-source project may introduce breaking changes

### Alternatives Considered

**Custom Parser** ❌ Rejected: 6-8 weeks development, ongoing maintenance burden, compliance risk

**Edifecs XEngine** ❌ Rejected: $50K+ licensing, overkill for use case, vendor lock-in

**BizTalk Server** ❌ Rejected: Legacy technology, not cloud-native, Microsoft deprecating

**Eddy.NET** ⏸️ Monitor: Newer library, less battle-tested, keep as backup option

### Implementation

Created `HealthcareEDI.X12` shared library with wrapper API:

```csharp
// Parsing
var envelope = X12EnvelopeParser.Parse(x12Content);
var transactionType = envelope.GetTransactionType(); // "270", "837", etc.

// Healthcare-specific helpers
var patient = eligibilityTransaction.GetPatient();
var memberId = patient.GetMemberId();

// Generation
var outboundFile = X12FileGenerator.Create()
    .WithInterchangeControlNumber(12345)
    .AddTransaction(transactionData)
    .Build();
```

### Monitoring

```kql
// Parsing success rate and performance
requests
| where name startswith "X12Parser"
| summarize 
    success_rate = round(100.0 * countif(success == true) / count(), 2),
    p95_duration_ms = percentile(duration, 95)
  by transactionType = tostring(customDimensions.TransactionType)
```

### References

- [Full ADR-003 Document](../decisions/adr-003-x12-parser-selection.md)
- [OopFactory.X12 GitHub](https://github.com/Eddy-Guido/OopFactory.X12)

---

## 6. ADR-004: Event Sourcing for 834 Enrollment

**Status:** ✅ Accepted  
**Date:** September 20, 2025  
**Decision Makers:** Platform Architecture Team  
**Technical Area:** Architecture  
**Scope:** Enrollment Management Partner (Internal Trading Partner)

### Context

The EDI 834 Benefit Enrollment and Maintenance transaction represents complex member lifecycle events (enrollment, termination, changes). Requirements include:

1. **Reversibility**: Ability to reverse entire file batches if partner sends corrections
2. **Auditability**: Complete history of all enrollment changes for compliance
3. **Temporal Queries**: Answer "what was member status on date X?"
4. **Idempotency**: Reprocessing files must produce identical results
5. **Data Evolution**: Track how member data changes over time

**Traditional CRUD Challenges:**

- Reversals require complex compensation logic
- Lost history (updates overwrite previous values)
- No temporal query capability
- Difficult to debug (can't reproduce historical state)

### Decision

**Implement event sourcing architecture for the Enrollment Management Partner (configured as internal trading partner `INTERNAL-ENROLLMENT`).**

**Key Design:**

- **Event Store**: Immutable append-only log of all enrollment events
- **Projections**: Read models (current state) rebuilt from events
- **Reversal**: Compensating events that negate previous transactions
- **Snapshotting**: Performance optimization for large event streams

**Note**: Event sourcing is an implementation choice for the Enrollment Management Partner only. Other trading partners (internal or external) may use different architectural patterns (CRUD, document store, etc.).

### Rationale

#### Why Event Sourcing?

| Benefit | Traditional CRUD | Event Sourcing |
|---------|-----------------|----------------|
| **Reversibility** | Complex SQL compensation | Natural via reversal events |
| **Audit Trail** | Separate audit tables | Built-in via event log |
| **Temporal Queries** | Difficult/impossible | Native capability |
| **Debugging** | Can't reproduce state | Replay events to any point |
| **Compliance** | Extra work | Automatic lineage |

#### Why Not Event Sourcing?

| Challenge | Description | Mitigation |
|-----------|-------------|------------|
| **Complexity** | Steeper learning curve | Training, documentation, code examples |
| **Storage** | Larger footprint (all history) | Snapshotting, archival strategy |
| **Query Performance** | Projection rebuilds | Materialized views, indexes |
| **Eventual Consistency** | Projections lag events | Acceptable for enrollment (not real-time) |

### Alternatives Considered

#### Option 1: Traditional CRUD with Audit Tables

**Approach**: Standard SQL tables with separate audit/history tables.

**Pros:**

- Familiar pattern
- Simpler query model
- Proven at scale

**Cons:**

- **Reversibility**: Requires complex compensation logic with data integrity risks
- **Audit gaps**: Easy to miss capturing certain updates
- **Temporal queries**: Requires complex SQL with history tables
- **Debugging**: Can't replay historical state accurately

**Decision:** ❌ Rejected - Reversibility requirement drives event sourcing

---

#### Option 2: Temporal Tables (SQL Server)

**Approach**: Use SQL Server temporal tables for automatic versioning.

**Pros:**

- Built-in time-travel queries
- Automatic history tracking
- SQL-native feature

**Cons:**

- **Reversibility**: Still requires compensation logic
- **Limited to SQL Server**: Not portable to other stores
- **Schema changes**: Temporal table alterations complex
- **Event semantics**: Doesn't capture business events, only table changes

**Decision:** ❌ Rejected - Doesn't solve reversibility; loses event semantics

#### Option 3: Change Data Capture (CDC)

**Approach**: Use CDC to track all database changes.

**Pros:**

- Automatic change tracking
- No application code changes

**Cons:**

- **Technical focus**: Captures DB changes, not business events
- **Reversibility**: No built-in reversal mechanism
- **Storage overhead**: High volume of technical events
- **Complexity**: CDC setup and management overhead

**Decision:** ❌ Rejected - Technical focus doesn't align with business event model

### Consequences

#### Benefits

| Benefit | Impact | Example |
|---------|--------|---------|
| **Complete Reversibility** | High | Reverse 834 file with 10,000 members in single operation |
| **Full Audit Trail** | High | Regulatory compliance for member enrollment history |
| **Temporal Queries** | Medium | "Show member coverage as of June 1, 2024" |
| **Debugging Power** | High | Replay events to reproduce production issues |

#### Trade-offs

| Trade-off | Description | Mitigation |
|-----------|-------------|------------|
| **Complexity** | Event sourcing learning curve | Training, examples, pair programming |
| **Storage Cost** | ~3x storage vs. CRUD (estimate) | Snapshotting reduces event replay; archival |
| **Projection Lag** | Eventual consistency (seconds) | Acceptable for enrollment batch processing |
| **Migration Effort** | Cannot use standard ORM | Custom event store implementation; EF Core for projections |

### Implementation

#### Event Store Schema

```sql
CREATE TABLE DomainEvent (
    EventId UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    AggregateId UNIQUEIDENTIFIER NOT NULL,
    AggregateType VARCHAR(100) NOT NULL, -- 'Member', 'Enrollment'
    EventType VARCHAR(100) NOT NULL, -- 'MemberEnrolled', 'MemberTerminated'
    EventData NVARCHAR(MAX) NOT NULL, -- JSON payload
    EventTimestamp DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    EventVersion INT NOT NULL,
    CorrelationId UNIQUEIDENTIFIER, -- Transaction batch ID
    CausationId UNIQUEIDENTIFIER, -- Originating event
    UserId VARCHAR(100),
    CONSTRAINT UQ_Aggregate_Version UNIQUE (AggregateId, EventVersion)
);

CREATE CLUSTERED INDEX IX_AggregateId_Version ON DomainEvent(AggregateId, EventVersion);
CREATE NONCLUSTERED INDEX IX_CorrelationId ON DomainEvent(CorrelationId);
```

#### Event Example

```json
{
  "eventId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "aggregateId": "member-123456",
  "aggregateType": "Member",
  "eventType": "MemberEnrolled",
  "eventData": {
    "memberId": "123456",
    "subscriberId": "123456",
    "firstName": "John",
    "lastName": "Doe",
    "dateOfBirth": "1980-05-15",
    "effectiveDate": "2025-01-01",
    "transactionBatchId": "batch-834-20250901"
  },
  "eventTimestamp": "2025-09-01T10:30:00Z",
  "eventVersion": 1,
  "correlationId": "batch-834-20250901"
}
```

#### Reversal Pattern

```csharp
public async Task ReverseTransactionBatch(string batchId)
{
    // Fetch all events for batch
    var events = await _eventStore.GetEventsByCorrelation(batchId);
    
    // Create reversal events
    foreach (var originalEvent in events)
    {
        var reversalEvent = new DomainEvent
        {
            AggregateId = originalEvent.AggregateId,
            EventType = GetReversalEventType(originalEvent.EventType),
            EventData = originalEvent.EventData,
            CorrelationId = $"reversal-{batchId}",
            CausationId = originalEvent.EventId
        };
        
        await _eventStore.AppendEvent(reversalEvent);
    }
    
    // Rebuild projections
    await _projectionManager.RebuildProjections(affectedAggregateIds);
}
```

### Monitoring

```kql
// Event append rate
DomainEvents_CL
| summarize event_count = count() by bin(EventTimestamp, 5m), EventType
| render timechart

// Projection lag
ProjectionLag_CL
| where ProjectionName == "MemberCurrentState"
| summarize max_lag_seconds = max(LagSeconds) by bin(TimeGenerated, 1m)
| render timechart
```

### References

- [Document 11: Event Sourcing Architecture](../11-event-sourcing-architecture-spec.md)
- [Event Sourcing Pattern (Microsoft)](https://docs.microsoft.com/azure/architecture/patterns/event-sourcing)
- [CQRS Pattern (Microsoft)](https://docs.microsoft.com/azure/architecture/patterns/cqrs)

---

## 7. ADR-005: Multi-Zone Data Lake Pattern

**Status:** ✅ Accepted  
**Date:** September 16, 2025  
**Decision Makers:** Platform Architecture Team, Data Team  
**Technical Area:** Infrastructure

### Context

The platform must store EDI files and processed data for:

1. **Compliance**: Retain original files for audit (7-10 years)
2. **Reprocessing**: Ability to rerun pipelines from source
3. **Analytics**: Transformed data for reporting and ML
4. **Performance**: Fast access to current/recent data
5. **Cost**: Optimize storage costs for historical data

**Storage Considerations:**

- Azure Data Lake Storage Gen2 (ADLS Gen2) hierarchical namespace
- Hot, Cool, Archive tiers with different cost/performance profiles
- Immutability requirements for compliance
- Query performance for analytics workloads

### Decision

**Implement a multi-zone data lake pattern with:**

1. **Raw Zone**: Immutable original files (as received)
2. **Staging Zone**: Validated and decompressed files
3. **Curated Zone**: Transformed, enriched, analytics-ready data
4. **Archive Zone**: Long-term retention (Cool/Archive tier)

**Zone Policies:**

| Zone | Purpose | Retention | Tier | Immutable |
|------|---------|-----------|------|-----------|
| **Raw** | Original files | 10 years | Hot → Cool (30d) | Yes |
| **Staging** | Validated files | 90 days | Hot | No |
| **Curated** | Analytics data | 7 years | Hot → Cool (90d) | No |
| **Archive** | Compliance | 10 years | Archive | Yes |

### Rationale

#### Why Multi-Zone vs. Single Storage?

**Multi-Zone Benefits:**

- **Separation of Concerns**: Ingestion, processing, analytics isolated
- **Performance**: Curated zone optimized for queries (Parquet, partitioning)
- **Compliance**: Raw zone immutability without impacting dev/test
- **Cost**: Lifecycle policies reduce storage costs by 50-70%
- **Reprocessability**: Raw zone provides replay capability

**Single Storage Drawbacks:**

- **Conflicting Requirements**: Immutability vs. development flexibility
- **Performance**: Mixing raw files and query-optimized formats
- **Cost**: No lifecycle optimization
- **Complexity**: Ad-hoc zoning leads to inconsistent patterns

#### Zone Responsibilities

```text
┌─────────────────────────────────────────────────────────────┐
│                         RAW ZONE                             │
│  - Original files (X12, CSV, JSON)                          │
│  - Immutable (WORM optional)                                │
│  - Partitioned: /partner/transaction/year/month/day/file    │
│  - Hot → Cool after 30 days                                 │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      STAGING ZONE                            │
│  - Validated files                                          │
│  - Decompressed (if needed)                                 │
│  - Checksum verified                                        │
│  - Temporary (90 days)                                      │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      CURATED ZONE                            │
│  - Parquet format (columnar, compressed)                    │
│  - Partitioned for query performance                        │
│  - Enriched with metadata                                   │
│  - Hot → Cool after 90 days                                 │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼ (after 7 years)
┌─────────────────────────────────────────────────────────────┐
│                      ARCHIVE ZONE                            │
│  - Long-term retention                                      │
│  - Archive tier (lowest cost)                               │
│  - Rehydration for compliance requests                      │
└─────────────────────────────────────────────────────────────┘
```

### Alternatives Considered

#### Option 1: Single Zone with Folders

**Approach**: One container with /raw, /staging, /curated subfolders.

**Pros:**

- Simpler structure
- Fewer containers to manage

**Cons:**

- **No tier optimization**: All data at same tier
- **No immutability**: Can't selectively apply WORM
- **No access control**: Harder to apply least-privilege
- **Lifecycle complexity**: Policies must match folder patterns

**Decision:** ❌ Rejected - Insufficient isolation

---

#### Option 2: Database-Centric (SQL + Blob)

**Approach**: Store metadata in SQL, raw files in blob, no curated zone.

**Pros:**

- SQL query performance
- Strong ACID guarantees

**Cons:**

- **Analytics performance**: SQL not optimized for large analytical queries
- **Scalability**: SQL limits at PB scale
- **Cost**: SQL storage more expensive than ADLS Gen2
- **Lock-in**: Less portable than open formats (Parquet)

**Decision:** ❌ Rejected - Not suitable for analytics at scale

#### Option 3: Hot-Only Storage

**Approach**: Keep all data in Hot tier for fast access.

**Pros:**

- Maximum performance
- Simpler lifecycle management

**Cons:**

- **Cost**: $0.0184/GB/month vs. $0.01 (Cool) or $0.002 (Archive)
- **Waste**: 90% of data rarely accessed after 90 days
- **Budget impact**: 5x storage cost vs. multi-tier

**Decision:** ❌ Rejected - Cost prohibitive

### Consequences

#### Benefits

| Benefit | Impact | Annual Savings |
|---------|--------|----------------|
| **Cost Optimization** | Lifecycle policies reduce storage cost | ~$15K (estimated) |
| **Compliance** | Immutable raw zone meets audit requirements | High |
| **Reprocessability** | Raw zone enables pipeline replay | High |
| **Query Performance** | Curated zone optimized for analytics | Medium |

#### Trade-offs

| Trade-off | Description | Mitigation |
|-----------|-------------|------------|
| **Complexity** | More zones to understand and manage | Documentation, training |
| **Data Movement** | Pipeline orchestration across zones | ADF pipelines handle movement |
| **Storage Duplication** | Same data in multiple zones temporarily | Staging zone auto-cleanup (90d) |

### Implementation

#### Container Structure

```text
stedi{env}001/
├── raw/
│   └── partner={code}/
│       └── transaction={set}/
│           └── year={yyyy}/month={mm}/day={dd}/
│               └── {filename}
├── staging/
│   └── ingestion_date={yyyy-mm-dd}/
│       └── {filename}
├── curated/
│   └── transaction={set}/
│       └── year={yyyy}/month={mm}/
│           └── {filename}.parquet
└── archive/
    └── year={yyyy}/
        └── {filename}.gz
```

#### Lifecycle Policy (Bicep)

```bicep
resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2021-09-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    policy: {
      rules: [
        {
          name: 'MoveRawToCool'
          type: 'Lifecycle'
          definition: {
            filters: { blobTypes: ['blockBlob'], prefixMatch: ['raw/'] }
            actions: {
              baseBlob: { tierToCool: { daysAfterModificationGreaterThan: 30 } }
            }
          }
        }
        {
          name: 'DeleteStaging'
          type: 'Lifecycle'
          definition: {
            filters: { blobTypes: ['blockBlob'], prefixMatch: ['staging/'] }
            actions: {
              baseBlob: { delete: { daysAfterModificationGreaterThan: 90 } }
            }
          }
        }
        {
          name: 'ArchiveCurated'
          type: 'Lifecycle'
          definition: {
            filters: { blobTypes: ['blockBlob'], prefixMatch: ['curated/'] }
            actions: {
              baseBlob: {
                tierToCool: { daysAfterModificationGreaterThan: 90 }
                tierToArchive: { daysAfterModificationGreaterThan: 2555 } // 7 years
              }
            }
          }
        }
      ]
    }
  }
}
```

### Monitoring

```kql
// Storage cost by zone
StorageBlobLogs
| where AccountName == "stediprod001"
| summarize total_gb = sum(ResponseBodySize) / (1024*1024*1024) by Container
| extend estimated_monthly_cost = case(
    Container == "raw", total_gb * 0.0184,
    Container == "staging", total_gb * 0.0184,
    Container == "curated", total_gb * 0.01,
    Container == "archive", total_gb * 0.002,
    0
  )
```

### References

- [Document 01: Architecture Specification](../01-architecture-spec.md)
- [Document 12: Raw File Storage Strategy](../12-raw-file-storage-strategy-spec.md)
- [Azure Data Lake Storage Gen2 Best Practices](https://docs.microsoft.com/azure/storage/blobs/data-lake-storage-best-practices)

---

## 8. ADR-006: Unified Trading Partner Model

**Status:** ✅ Accepted  
**Date:** September 22, 2025  
**Decision Makers:** Platform Architecture Team  
**Technical Area:** Architecture

### Context

The platform must integrate with multiple types of systems:

1. **External Trading Partners**: Payers, providers, clearinghouses via SFTP
2. **Internal Subsystems**: Claims processing, eligibility services, enrollment management
3. **Outbound Delivery**: Acknowledgments and responses to both external and internal partners

**Initial Design Assumption**: External partners are "special" and need different integration patterns than internal systems.

**Challenges with Separate Models:**

- Duplicate integration code (SFTP client for partners, API client for internal)
- Inconsistent configuration (partner metadata vs. internal system config)
- Complex routing logic (if external vs. if internal)
- Difficult to add new internal systems (requires new integration pattern)

### Decision

**Adopt a unified trading partner model where all data sources and destinations (external and internal) are configured as trading partners with standardized integration adapters.**

**Key Principles:**

1. **Every system is a trading partner** (external payer, internal claims processor, enrollment management)
2. **Each partner has a unique partner code** (`AETNA-001`, `INTERNAL-CLAIMS`, `INTERNAL-ENROLLMENT`)
3. **Each partner has an endpoint configuration** (SFTP, REST API, Service Bus, database)
4. **Each partner has an integration adapter** handling format transformation and protocol adaptation
5. **Routing layer treats all partners identically** (no special cases for "internal")

### Rationale

#### Why Unified Model?

**Benefits:**

- **Consistent Configuration**: Single partner configuration schema for all systems
- **Simplified Routing**: No conditional logic for internal vs. external
- **Reusable Adapters**: Same SFTP adapter works for internal SFTP endpoints
- **Easy Onboarding**: Add new partner (internal or external) without code changes
- **Loose Coupling**: Internal systems don't have special privileges
- **Testability**: Mock external partners same as internal for testing

**Before (Separate Models):**

```text
External Partners → SFTP Ingestion → Routing → Internal System Integration
                                                 ├─ Claims System (direct API)
                                                 ├─ Eligibility System (Service Bus)
                                                 └─ Enrollment System (database)
```

**After (Unified Model):**

```text
All Trading Partners → Routing → Partner Adapters
                                  ├─ Adapter: SFTP (external payer)
                                  ├─ Adapter: REST API (internal claims)
                                  ├─ Adapter: Service Bus (internal eligibility)
                                  └─ Adapter: Service Bus (internal enrollment)
```

#### Internal System Example: Enrollment Management

**Configuration:**

```json
{
  "partnerCode": "INTERNAL-ENROLLMENT",
  "partnerName": "Enrollment Management System",
  "partnerType": "INTERNAL",
  "direction": "INBOUND",
  "endpointType": "SERVICE_BUS_SUBSCRIPTION",
  "endpointConfig": {
    "subscriptionName": "sub-enrollment-834",
    "topicName": "edi-routing",
    "filter": "transactionSet = '834' AND partnerCode = 'INTERNAL-ENROLLMENT'"
  },
  "adapter": {
    "type": "EventSourcingProcessor",
    "assemblyName": "EnrollmentManagement.Functions"
  }
}
```

**Benefits:**

- Enrollment system subscribes to Service Bus like any other partner
- Can switch to different endpoint (API, database) without routing changes
- Same configuration pattern as external partners
- Easy to add new internal partners (remittance, prior auth, etc.)

### Alternatives Considered

#### Option 1: Separate Internal System Integration

**Approach**: Direct integration with internal systems (API calls, database connections) separate from partner routing.

**Pros:**

- Potentially lower latency (no Service Bus hop)
- Simpler initial implementation

**Cons:**

- **Tight coupling**: Routing layer depends on internal system APIs
- **Duplicate code**: Separate integration logic for each system
- **Scalability**: Internal system responsiveness affects ingestion throughput
- **Testing**: Difficult to mock internal systems
- **Configuration**: Inconsistent patterns across partners and internal systems

**Decision:** ❌ Rejected - Creates tight coupling and technical debt

---

#### Option 2: API Gateway for Internal Systems

**Approach**: All internal systems behind API Management gateway with standardized APIs.

**Pros:**

- Consistent API layer
- API Management features (throttling, caching)

**Cons:**

- **Cost**: API Management adds $250+/month
- **Latency**: Additional network hop
- **Complexity**: API Management configuration overhead
- **Still separate**: Doesn't unify with external partner model

**Decision:** ❌ Rejected - Doesn't achieve unified model goal

### Consequences

#### Benefits

| Benefit | Description | Impact |
|---------|-------------|--------|
| **Consistency** | Single configuration model for all partners | High |
| **Loose Coupling** | Routing decoupled from partner implementation | High |
| **Scalability** | Service Bus buffers throughput spikes | Medium |
| **Testability** | Mock any partner type identically | Medium |
| **Extensibility** | Add partners without routing changes | High |

#### Trade-offs

| Trade-off | Description | Mitigation |
|-----------|-------------|------------|
| **Service Bus Latency** | Additional hop (~50-100ms) | Acceptable for batch workflows |
| **Configuration Overhead** | All systems need partner config | Templates, automation |
| **Message Size Limits** | Service Bus 256KB limit | Store large payloads in blob, pass reference |

### Implementation

#### Partner Configuration Schema

```json
{
  "partnerCode": "string (unique identifier)",
  "partnerName": "string (display name)",
  "partnerType": "EXTERNAL | INTERNAL",
  "direction": "INBOUND | OUTBOUND | BIDIRECTIONAL",
  "endpointType": "SFTP | REST_API | SERVICE_BUS | DATABASE | FILE_SHARE",
  "endpointConfig": {
    // Type-specific configuration
  },
  "adapter": {
    "type": "string (adapter implementation)",
    "assemblyName": "string (for Functions)",
    "configuration": {}
  },
  "supportedTransactions": ["270", "271", "834", "837", "835"],
  "sla": {
    "maxLatencyMinutes": 30,
    "retryPolicy": "exponential"
  }
}
```

#### Routing Function (Partner-Agnostic)

```csharp
// No special cases for internal vs. external
foreach (var transaction in envelope.Transactions)
{
    var routingMsg = new ServiceBusMessage(JsonSerializer.Serialize(new {
        routingId = Guid.NewGuid(),
        transactionSet = transaction.TransactionSetIdentifier,
        partnerCode = envelope.SenderId,
        fileBlobPath = blobTrigger,
        stPosition = transaction.Position
    }));
    
    // Same routing for all partners
    routingMsg.ApplicationProperties["transactionSet"] = transaction.TransactionSetIdentifier;
    routingMsg.ApplicationProperties["partnerCode"] = envelope.SenderId;
    
    await output.AddAsync(routingMsg);
}
```

### Monitoring

```kql
// Partner message processing (internal and external)
ServiceBusLogs
| where Topic == "edi-routing"
| extend PartnerType = case(
    PartnerCode startswith "INTERNAL-", "Internal",
    "External"
  )
| summarize 
    message_count = count(),
    avg_latency_ms = avg(ProcessingTimeMs)
  by PartnerType, PartnerCode, TransactionSet
| order by message_count desc
```

### References

- [Document 08: Transaction Routing](./08-transaction-routing-outbound-spec.md)
- [Document 10: Trading Partner Configuration](./10-trading-partner-config.md)
- [Document 13: Partner Integration Adapters](../13-mapper-connector-spec.md)

---

## 9. ADR-007: Azure Functions for Integration

**Status:** ✅ Accepted  
**Date:** September 25, 2025  
**Decision Makers:** Platform Engineering Team  
**Technical Area:** Infrastructure

### Context

The platform requires lightweight integration components for:

1. **Transaction Routing**: Parse envelope, publish routing messages
2. **Format Transformation**: X12 → Partner format, Partner → X12
3. **API Integration**: HTTP callouts to partner APIs
4. **Event Processing**: React to Service Bus and blob events

**Requirements:**

- Fast startup (<1 second cold start target)
- Cost-effective at scale (100K+ transactions/day)
- Strong developer experience (local debugging, unit testing)
- Native Azure integration (Service Bus, Blob, Key Vault)

### Decision

**Standardize on Azure Functions (C#, .NET 8) for all Mapper and Connector implementations.**

**Function App Structure:**

- **edi-routing**: Envelope parsing and routing message publication
- **edi-mappers**: Transaction transformation functions (by type)
- **edi-connectors**: Partner delivery functions (by partner)
- **edi-scheduler**: Enterprise scheduler execution functions

### Rationale

#### Why Azure Functions?

| Factor | Azure Functions | Logic Apps | Container Apps |
|--------|----------------|------------|----------------|
| **Cold Start** | <1s (Consumption) | 2-5s | <2s |
| **Cost** | $0.20/million executions | $0.20/execution | ~$50/month minimum |
| **Dev Experience** | Excellent (local F5 debug) | Limited | Good (container dev) |
| **Azure Integration** | Native bindings | 500+ connectors | Custom code |
| **Team Skillset** | C# (existing) | Low-code | Containers (learning curve) |

#### C# vs. Other Languages

**Why C#?**

- Existing team expertise
- Strong type safety for EDI parsing
- Best performance in .NET runtime
- Rich ecosystem (X12 libraries, JSON, XML)
- Easy unit testing (xUnit, Moq)

**Considered Alternatives:**

- **Python**: Good for data science, slower for EDI parsing
- **Node.js**: Limited healthcare EDI libraries
- **Java**: No team expertise

### Alternatives Considered

#### Option 1: Logic Apps Standard

**Approach**: Use Logic Apps for all integration flows.

**Pros:**

- Visual designer
- 500+ built-in connectors
- Workflow orchestration

**Cons:**

- **Cost**: $0.20/execution = $20K/month at 100K/day
- **Testing**: Difficult to unit test
- **Complexity**: Custom code requires inline JavaScript or Functions
- **Performance**: Slower than Functions

**Decision:** ❌ Rejected - Cost prohibitive, poor testability

---

#### Option 2: Azure Container Apps

**Approach**: Deploy integration logic as containers.

**Pros:**

- Full control over runtime
- Portable (any cloud)
- Advanced scaling options

**Cons:**

- **Complexity**: Container management overhead
- **Cold start**: Slower than Functions
- **Development**: Requires container tooling
- **Cost**: Higher baseline cost

**Decision:** ❌ Rejected - Unnecessary complexity for integration workloads

---

#### Option 3: Durable Functions for All Orchestration

**Approach**: Use Durable Functions for multi-step workflows.

**Pros:**

- Code-based orchestration
- Built-in retry and timeout
- Local debugging

**Cons:**

- **Storage overhead**: Orchestration state in tables
- **Complexity**: Overkill for simple transformations
- **Cost**: Higher than stateless Functions

**Decision:** ⏸️ Selective Use - Use Durable Functions only for complex sagas, not simple transformations

### Consequences

#### Benefits

| Benefit | Impact |
|---------|--------|
| **Fast Development** | Local debugging, hot reload |
| **Cost-Effective** | Consumption plan: pay-per-execution |
| **Scalability** | Automatic scaling to thousands of instances |
| **Testability** | Unit test Functions without Azure dependencies |
| **Monitoring** | Built-in Application Insights integration |

#### Trade-offs

| Trade-off | Description | Mitigation |
|-----------|-------------|------------|
| **Cold Start** | First invocation latency (1-3s) | Premium plan for critical paths |
| **Execution Time Limit** | 10 min (Consumption) | Use Durable Functions for long-running |
| **State Management** | Functions are stateless | Externalize state to Blob/SQL |

### Implementation

#### Routing Function Example

```csharp
[FunctionName("EnvelopeRouter")]
public async Task Run(
    [BlobTrigger("raw/{partner}/{filename}", Connection = "StorageConnection")] Stream blob,
    [ServiceBus("edi-routing", Connection = "ServiceBusConnection")] IAsyncCollector<ServiceBusMessage> output,
    ILogger log)
{
    var envelope = await _x12Parser.ParseEnvelopeAsync(blob, maxBytes: 1024);
    
    foreach (var transaction in envelope.Transactions)
    {
        var routingMsg = CreateRoutingMessage(envelope, transaction);
        await output.AddAsync(routingMsg);
    }
    
    log.LogInformation($"Routed {envelope.Transactions.Count} transactions from {envelope.SenderId}");
}
```

#### Mapper Function Example

```csharp
[FunctionName("Mapper270")]
public async Task Run(
    [ServiceBusTrigger("edi-routing", "sub-eligibility-270", Connection = "ServiceBusConnection")] string message,
    [Blob("{fileBlobPath}", FileAccess.Read, Connection = "StorageConnection")] Stream blob,
    ILogger log)
{
    var routingMsg = JsonSerializer.Deserialize<RoutingMessage>(message);
    var transaction = await _x12Parser.ParseTransactionAsync(blob, routingMsg.StPosition);
    
    var partnerFormat = _mapper.Transform270ToPartnerFormat(transaction);
    await _connector.DeliverToPartner(partnerFormat);
    
    log.LogInformation($"Processed 270 transaction {routingMsg.RoutingId}");
}
```

#### Function App Configuration (Bicep)

```bicep
resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: 'func-edi-routing-${env}'
  location: location
  kind: 'functionapp'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'dotnet-isolated' }
        { name: 'AzureWebJobsStorage', value: storageAccountConnectionString }
        { name: 'ServiceBusConnection__fullyQualifiedNamespace', value: '${serviceBusNamespace}.servicebus.windows.net' }
      ]
      netFrameworkVersion: 'v8.0'
    }
  }
}
```

### Monitoring

```kql
// Function execution success rate
requests
| where cloud_RoleName startswith "func-edi-"
| summarize 
    total = count(),
    failures = countif(success == false),
    success_rate = round(100.0 * countif(success == true) / count(), 2)
  by cloud_RoleName, operation_Name
| order by total desc
```

### References

- [ADR-002: Hybrid Orchestration Pattern](#4-adr-002-hybrid-orchestration-pattern)
- [Document 13: Partner Integration Adapters](../13-mapper-connector-spec.md)
- [Azure Functions Best Practices](https://docs.microsoft.com/azure/azure-functions/functions-best-practices)

---

## 10. ADR-008: Service Bus Topic-Based Routing

**Status:** ✅ Accepted  
**Date:** September 19, 2025  
**Decision Makers:** Platform Architecture Team  
**Technical Area:** Architecture

### Context

After ingestion and validation, transactions must be routed to appropriate partner systems. Requirements include:

1. **Fan-Out**: Single transaction may go to multiple partners
2. **Filtering**: Each partner receives only relevant transaction types
3. **Durability**: Messages must survive system failures
4. **Retry Logic**: Partner-specific retry policies
5. **Dead-Lettering**: Isolate failed messages for investigation
6. **Loose Coupling**: Ingestion throughput independent of partner processing

### Decision

**Use Azure Service Bus Topics with subscription filters for transaction routing.**

**Architecture:**

- **Topic**: `edi-routing` (central routing hub)
- **Subscriptions**: One per partner (e.g., `sub-claims-system1`, `sub-eligibility-aetna`)
- **Filters**: SQL-like filters on message properties (`transactionSet = '837' AND partnerCode = 'CLAIMS-01'`)
- **Dead-Letter Queues**: Automatic DLQ per subscription for failed messages

### Rationale

#### Why Service Bus Topics?

**Benefits:**

- **Publish-Subscribe**: One message → many subscribers (fan-out)
- **Filtering**: SQL filters avoid wasted message delivery
- **Durability**: Guaranteed delivery with transactions
- **Retry Policies**: Per-subscription retry configuration
- **Dead-Lettering**: Automatic isolation of poison messages
- **Ordering**: Optional FIFO within sessions
- **Throughput**: 2,000 messages/second (Standard tier)

#### Service Bus vs. Alternatives

| Feature | Service Bus | Event Grid | Storage Queue |
|---------|-------------|------------|---------------|
| **Pub-Sub** | ✅ Topics | ✅ Topics | ❌ Point-to-point |
| **Filtering** | ✅ SQL filters | ✅ Event types | ❌ No filtering |
| **Ordering** | ✅ Sessions | ❌ No guarantee | ❌ No guarantee |
| **DLQ** | ✅ Automatic | ⚠️ Manual | ✅ Poison queue |
| **Message Size** | 256 KB / 1 MB | 64 KB | 64 KB |
| **Transactions** | ✅ Full support | ❌ No | ❌ No |

### Alternatives Considered

#### Option 1: Event Grid with Event Subscriptions

**Approach**: Publish routing events to Event Grid, partners subscribe to event types.

**Pros:**

- Massive scale (millions of events/second)
- Low cost ($0.60/million operations)
- Built-in retry and dead-letter

**Cons:**

- **No SQL filtering**: Must filter in subscriber code
- **64 KB limit**: Too small for transaction metadata
- **No ordering**: Cannot guarantee sequence
- **Limited durability**: Best-effort delivery for event-driven scenarios

**Decision:** ❌ Rejected - Insufficient filtering and message size

---

#### Option 2: Direct Function-to-Function Invocation

**Approach**: Routing function directly invokes partner functions via HTTP.

**Pros:**

- Lower latency (no queue hop)
- Simpler architecture

**Cons:**

- **Tight coupling**: Routing depends on partner function availability
- **No buffering**: Slow partner affects ingestion throughput
- **No retry**: Must implement custom retry logic
- **No DLQ**: Manual poison message handling

**Decision:** ❌ Rejected - Creates tight coupling

---

#### Option 3: Kafka on Azure (Event Hubs with Kafka API)

**Approach**: Publish to Kafka topics, partners consume with consumer groups.

**Pros:**

- High throughput (millions of events/second)
- Message replay capability
- Strong ordering guarantees

**Cons:**

- **Complexity**: Kafka operational overhead
- **Cost**: Event Hubs Dedicated ($8,760/month minimum)
- **Overkill**: Don't need message replay or streaming analytics
- **Learning curve**: Team not experienced with Kafka

**Decision:** ❌ Rejected - Unnecessary complexity and cost

### Consequences

#### Benefits

| Benefit | Impact |
|---------|--------|
| **Loose Coupling** | Partners process at own pace |
| **Scalability** | Buffer absorbs throughput spikes |
| **Reliability** | Automatic retry and dead-lettering |
| **Flexibility** | Add/remove partners without routing changes |
| **Observability** | Built-in metrics and message tracking |

#### Trade-offs

| Trade-off | Description | Mitigation |
|-----------|-------------|------------|
| **Latency** | ~50-100ms queue hop | Acceptable for batch workflows |
| **Message Size** | 256 KB limit (Standard tier) | Store large payloads in blob, pass reference |
| **Cost** | $0.05/million operations (Standard tier) | Budget alerts; optimize message frequency |

### Implementation

#### Topic Creation (Bicep)

```bicep
resource serviceBusTopic 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' = {
  name: 'edi-routing'
  parent: serviceBusNamespace
  properties: {
    maxSizeInMegabytes: 5120
    defaultMessageTimeToLive: 'P14D' // 14 days
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enablePartitioning: true
  }
}
```

#### Subscription with Filter (Bicep)

```bicep
resource subscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-11-01' = {
  name: 'sub-claims-system1'
  parent: serviceBusTopic
  properties: {
    maxDeliveryCount: 10
    defaultMessageTimeToLive: 'P7D'
    deadLetteringOnMessageExpiration: true
    deadLetteringOnFilterEvaluationExceptions: true
  }
}

resource subscriptionRule 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2021-11-01' = {
  name: 'ClaimsFilter'
  parent: subscription
  properties: {
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression: "transactionSet IN ('837', '835') AND partnerCode = 'CLAIMS-01'"
    }
  }
}
```

#### Publishing Routing Message (C#)

```csharp
var routingMsg = new ServiceBusMessage(JsonSerializer.Serialize(new {
    routingId = Guid.NewGuid(),
    ingestionId = envelope.IngestionId,
    transactionSet = transaction.TransactionSetIdentifier,
    partnerCode = envelope.SenderId,
    fileBlobPath = blobTrigger,
    stPosition = transaction.Position
}))
{
    MessageId = Guid.NewGuid().ToString(),
    CorrelationId = envelope.IngestionId,
    ContentType = "application/json"
};

// Application properties for filtering
routingMsg.ApplicationProperties["transactionSet"] = transaction.TransactionSetIdentifier;
routingMsg.ApplicationProperties["partnerCode"] = envelope.SenderId;
routingMsg.ApplicationProperties["priority"] = "normal";

await sender.SendMessageAsync(routingMsg);
```

### Monitoring

```kql
// Message flow by subscription
ServiceBusLogs
| where EntityName == "edi-routing"
| summarize 
    messages_delivered = count(),
    avg_latency_ms = avg(Duration),
    dead_lettered = countif(Status == "DeadLetter")
  by SubscriptionName, TransactionSet
| order by messages_delivered desc
```

### References

- [Document 08: Transaction Routing](./08-transaction-routing-outbound-spec.md)
- [Azure Service Bus Documentation](https://docs.microsoft.com/azure/service-bus-messaging/)
- [Topic Filters and Actions](https://docs.microsoft.com/azure/service-bus-messaging/topic-filters)

---

## 11. ADR-009: Control Number Management Strategy

**Status:** ✅ Accepted  
**Date:** September 28, 2025  
**Decision Makers:** Platform Engineering Team  
**Technical Area:** Infrastructure

### Context

X12 EDI transactions require unique control numbers for:

1. **ISA Interchange Control Number**: Unique per interchange (file level)
2. **GS Group Control Number**: Unique per functional group
3. **ST Transaction Control Number**: Unique per transaction

**Requirements:**

- **Uniqueness**: No duplicate control numbers per partner per direction
- **Sequential**: Numbers must increase sequentially (EDI standard)
- **Concurrency**: Multiple functions generating numbers simultaneously
- **Performance**: Low latency (target <10ms)
- **Auditability**: Track number assignment history

### Decision

**Implement centralized control number management using SQL Server stored procedures with row-level locking.**

**Architecture:**

- **Database**: `edi-database-controlnumbers` (SQL Server)
- **Table**: `ControlNumberSequence` with unique constraint on (PartnerId, ControlNumberType, Direction)
- **Stored Procedure**: `usp_GetNextControlNumber` with atomic increment
- **Function**: Lightweight wrapper calling stored procedure

### Rationale

#### Why SQL Server with Stored Procedures?

| Approach | Concurrency | Performance | Complexity | Cost |
|----------|-------------|-------------|------------|------|
| **SQL Server SP** | ✅ Row locks | <5ms | Low | Included |
| **Redis Counter** | ✅ INCR atomic | <2ms | Medium | $70+/month |
| **Cosmos DB** | ⚠️ Optimistic concurrency | ~10ms | High | $25+/month |
| **Blob Lease** | ❌ Lease timeout issues | ~50ms | High | Included |

**SQL Server Advantages:**

- Transactional guarantees (ACID)
- Existing skillset (no Redis/Cosmos learning curve)
- Low latency (<5ms P95)
- Included in existing SQL database footprint
- Easy backup and restore

#### Why Not Redis?

**Redis INCR Command:**

```redis
INCR control:number:partner:aetna:isa:outbound
```

**Pros:**

- Extremely fast (<2ms)
- Atomic operations built-in
- Pub/sub capabilities for auditing

**Cons:**

- **Additional cost**: Azure Cache for Redis $70+/month
- **New dependency**: Another service to monitor
- **Persistence**: Requires snapshot/AOF configuration
- **Skills gap**: Team less familiar with Redis

**Decision:** Not worth the complexity for 2-3ms latency improvement.

### Alternatives Considered

#### Option 1: Cosmos DB with Optimistic Concurrency

**Approach**: Store control numbers in Cosmos DB documents with `_etag` for optimistic concurrency.

**Pros:**

- Global distribution (multi-region)
- Automatic scaling

**Cons:**

- **Retry complexity**: Optimistic concurrency requires application retry logic
- **Cost**: ~$25/month minimum (400 RU/s)
- **Latency**: ~10ms (higher than SQL)
- **Overkill**: Don't need global distribution for control numbers

**Decision:** ❌ Rejected - Unnecessary complexity

---

#### Option 2: Azure Storage Blob Lease

**Approach**: Use blob lease to acquire lock, read/increment/write control number.

**Pros:**

- No additional cost (storage account already exists)
- Simple concept

**Cons:**

- **Lease timeout issues**: 60-second lease can cause delays
- **High latency**: ~50ms for lease acquire + read + write
- **No transactions**: Race conditions possible
- **Complexity**: Manual retry and timeout handling

**Decision:** ❌ Rejected - Poor performance and reliability

---

#### Option 3: Application-Level Counter (In-Memory)

**Approach**: Each function instance maintains in-memory counter, periodically syncs to storage.

**Pros:**

- Extremely fast (<1ms)
- No network calls

**Cons:**

- **Gaps on restart**: Function recycle loses counter state
- **Concurrency issues**: Multiple instances could generate duplicates
- **Audit trail**: Difficult to track number assignment
- **Compliance risk**: EDI standards require no gaps or duplicates

**Decision:** ❌ Rejected - Unacceptable compliance risk

### Consequences

#### Benefits

| Benefit | Impact |
|---------|--------|
| **Transactional Safety** | ACID guarantees prevent duplicates |
| **Performance** | <5ms P95 latency adequate for batch workflows |
| **Simplicity** | Stored procedure encapsulates complexity |
| **Auditability** | SQL audit logs track all increments |
| **Cost-Effective** | No additional infrastructure |

#### Trade-offs

| Trade-off | Description | Mitigation |
|-----------|-------------|------------|
| **Single Point of Contention** | All control numbers from one database | Acceptable; not a high-frequency operation |
| **SQL Dependency** | Functions depend on SQL availability | SQL HA with failover; retry logic |
| **Not Multi-Region** | Control numbers not globally distributed | Not required; partners are regional |

### Implementation

#### Database Schema

```sql
CREATE TABLE ControlNumberSequence (
    SequenceId INT IDENTITY(1,1) PRIMARY KEY,
    PartnerId VARCHAR(50) NOT NULL,
    ControlNumberType VARCHAR(10) NOT NULL, -- 'ISA', 'GS', 'ST'
    Direction VARCHAR(10) NOT NULL, -- 'INBOUND', 'OUTBOUND'
    CurrentValue INT NOT NULL DEFAULT 1,
    LastUpdated DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Partner_Type_Direction UNIQUE (PartnerId, ControlNumberType, Direction)
);

CREATE INDEX IX_PartnerId ON ControlNumberSequence(PartnerId);
```

#### Stored Procedure

```sql
CREATE PROCEDURE usp_GetNextControlNumber
    @PartnerId VARCHAR(50),
    @ControlNumberType VARCHAR(10),
    @Direction VARCHAR(10),
    @NextValue INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Acquire row-level lock and increment
    UPDATE ControlNumberSequence WITH (ROWLOCK)
    SET 
        CurrentValue = CurrentValue + 1,
        LastUpdated = SYSUTCDATETIME(),
        @NextValue = CurrentValue + 1
    WHERE 
        PartnerId = @PartnerId
        AND ControlNumberType = @ControlNumberType
        AND Direction = @Direction;
    
    -- If no row exists, insert with initial value
    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO ControlNumberSequence (PartnerId, ControlNumberType, Direction, CurrentValue)
        VALUES (@PartnerId, @ControlNumberType, @Direction, 1);
        
        SET @NextValue = 1;
    END
    
    RETURN 0;
END
```

#### Function Wrapper (C#)

```csharp
public async Task<int> GetNextControlNumberAsync(
    string partnerId,
    ControlNumberType type,
    Direction direction)
{
    using var connection = new SqlConnection(_connectionString);
    using var command = new SqlCommand("usp_GetNextControlNumber", connection)
    {
        CommandType = CommandType.StoredProcedure
    };
    
    command.Parameters.AddWithValue("@PartnerId", partnerId);
    command.Parameters.AddWithValue("@ControlNumberType", type.ToString());
    command.Parameters.AddWithValue("@Direction", direction.ToString());
    
    var outputParam = new SqlParameter("@NextValue", SqlDbType.Int)
    {
        Direction = ParameterDirection.Output
    };
    command.Parameters.Add(outputParam);
    
    await connection.OpenAsync();
    await command.ExecuteNonQueryAsync();
    
    return (int)outputParam.Value;
}
```

#### Usage Example

```csharp
// Generate outbound 271 response
var isaControlNumber = await _controlNumberService.GetNextControlNumberAsync(
    partnerId: "AETNA-001",
    type: ControlNumberType.ISA,
    direction: Direction.OUTBOUND
);

var x12Envelope = $"ISA*00*          *00*          *ZZ*{senderId.PadRight(15)}*ZZ*{receiverId.PadRight(15)}*{date}*{time}*^*00501*{isaControlNumber:D9}*0*P*:~";
```

### Monitoring

```kql
// Control number generation latency
dependencies
| where target contains "edi-database-controlnumbers"
| where name contains "usp_GetNextControlNumber"
| summarize 
    count = count(),
    avg_duration_ms = avg(duration),
    p95_duration_ms = percentile(duration, 95),
    max_duration_ms = max(duration)
  by bin(timestamp, 5m)
| render timechart
```

### References

- [X12 Control Number Standards](https://www.x12.org/)
- [Document 08: Transaction Routing](./08-transaction-routing-outbound-spec.md)

---

## 12. ADR-010: Infrastructure as Code with Bicep

**Status:** ✅ Accepted  
**Date:** September 10, 2025  
**Decision Makers:** Platform Team, DevOps Team  
**Technical Area:** DevOps

### Context

The platform requires consistent, repeatable infrastructure across environments (dev, test, prod). Requirements include:

1. **Repeatability**: Identical infrastructure across environments
2. **Version Control**: Infrastructure changes tracked in Git
3. **CI/CD Integration**: Automated deployment via GitHub Actions
4. **Azure-Native**: Leverage Azure Resource Manager capabilities
5. **Modularity**: Reusable components across projects

### Decision

**Use Azure Bicep as the Infrastructure as Code (IaC) language.**

**Repository Structure:**

```text
infra/
├── bicep/
│   ├── main.bicep           # Entry point
│   ├── modules/
│   │   ├── storage.bicep
│   │   ├── datafactory.bicep
│   │   ├── servicebus.bicep
│   │   └── keyvault.bicep
│   └── parameters/
│       ├── dev.parameters.json
│       ├── test.parameters.json
│       └── prod.parameters.json
```

### Rationale

#### Why Bicep vs. Alternatives?

| Factor | Bicep | ARM JSON | Terraform | Pulumi |
|--------|-------|----------|-----------|--------|
| **Azure Native** | ✅ First-party | ✅ First-party | ⚠️ Third-party | ⚠️ Third-party |
| **Readability** | ✅ Excellent | ❌ Verbose | ✅ Good | ✅ Good |
| **Azure Resource Coverage** | ✅ Same-day | ✅ Same-day | ⚠️ Lag (weeks) | ⚠️ Lag |
| **State Management** | ✅ Azure handles | ✅ Azure handles | ❌ Separate state file | ❌ Separate state |
| **Learning Curve** | ✅ Low | ⚠️ Medium | ⚠️ Medium | ⚠️ High |
| **Multi-Cloud** | ❌ Azure only | ❌ Azure only | ✅ Yes | ✅ Yes |

**Bicep Advantages:**

- **Azure Resource Manager First-Party**: New resources available immediately
- **No State File**: ARM tracks state automatically
- **Clean Syntax**: Less verbose than ARM JSON
- **Strong Typing**: Compile-time validation
- **VS Code Extension**: IntelliSense, validation, visualization

### Alternatives Considered

#### Option 1: ARM JSON Templates

**Approach**: Use native ARM JSON templates.

**Pros:**

- Fully supported by Azure
- Mature tooling
- No compilation step

**Cons:**

- **Verbosity**: 3-5x more lines than Bicep for same resources
- **Readability**: JSON syntax difficult to read/maintain
- **No intellisense**: Limited editor support

**Decision:** ❌ Rejected - Bicep compiles to ARM JSON, no reason to write JSON directly

---

#### Option 2: Terraform (HashiCorp)

**Approach**: Use Terraform with Azure provider.

**Pros:**

- Multi-cloud support
- Large community
- Mature ecosystem (modules, providers)

**Cons:**

- **State management**: Requires Azure Storage backend configuration
- **Resource lag**: New Azure resources available weeks/months after GA
- **Additional complexity**: Terraform state locking, drift detection
- **Cost**: Terraform Cloud pricing for team collaboration
- **Learning curve**: HCL syntax, Terraform concepts

**Decision:** ❌ Rejected - No multi-cloud requirement; Bicep simpler for Azure-only

---

#### Option 3: Pulumi (Programming Language IaC)

**Approach**: Define infrastructure in C#, Python, or TypeScript.

**Pros:**

- Full programming language expressiveness
- Strong typing (TypeScript/C#)
- Unit testing infrastructure code

**Cons:**

- **Complexity**: Requires understanding Pulumi SDK + Azure SDK
- **State management**: Pulumi state backend configuration
- **Team skillset**: Steeper learning curve
- **Debugging**: More complex than declarative IaC

**Decision:** ❌ Rejected - Overkill for infrastructure deployment

### Consequences

#### Benefits

| Benefit | Impact |
|---------|--------|
| **Repeatability** | Identical infrastructure across environments |
| **Version Control** | Git history tracks all infrastructure changes |
| **CI/CD Integration** | GitHub Actions deploys via Bicep |
| **Fast Iteration** | Compile-time validation catches errors early |
| **Azure Latest Features** | Same-day support for new resources |

#### Trade-offs

| Trade-off | Description | Mitigation |
|-----------|-------------|------------|
| **Azure-Only** | Cannot deploy to other clouds | Acceptable; no multi-cloud plans |
| **Bicep Learning Curve** | Team must learn Bicep syntax | Documentation, examples, training |
| **Module Management** | No central registry like Terraform | Git submodules or template specs |

### Implementation

#### Main Bicep File

```bicep
targetScope = 'resourceGroup'

@description('Environment name (dev, test, prod)')
param environment string

@description('Azure region')
param location string = resourceGroup().location

@description('Resource tags')
param tags object = {
  Environment: environment
  Project: 'EDI-Platform'
  ManagedBy: 'Bicep'
}

// Storage Account
module storage 'modules/storage.bicep' = {
  name: 'storage-deployment'
  params: {
    environment: environment
    location: location
    tags: tags
  }
}

// Service Bus
module serviceBus 'modules/servicebus.bicep' = {
  name: 'servicebus-deployment'
  params: {
    environment: environment
    location: location
    tags: tags
  }
}

// Data Factory
module dataFactory 'modules/datafactory.bicep' = {
  name: 'datafactory-deployment'
  params: {
    environment: environment
    location: location
    storageAccountName: storage.outputs.storageAccountName
    tags: tags
  }
}
```

#### GitHub Actions Deployment

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths: ['infra/bicep/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy Bicep
        uses: azure/arm-deploy@v1
        with:
          subscriptionId: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          resourceGroupName: rg-edi-prod
          template: ./infra/bicep/main.bicep
          parameters: ./infra/bicep/parameters/prod.parameters.json
```

### Monitoring

```kql
// ARM deployment success rate
AzureActivity
| where OperationNameValue == "MICROSOFT.RESOURCES/DEPLOYMENTS/WRITE"
| summarize 
    total = count(),
    failures = countif(ActivityStatusValue == "Failure"),
    success_rate = round(100.0 * countif(ActivityStatusValue == "Success") / count(), 2)
  by bin(TimeGenerated, 1d)
| render timechart
```

### References

- [Document 04: IaC Strategy](../04-iac-strategy-spec.md)
- [Azure Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Bicep Best Practices](https://docs.microsoft.com/azure/azure-resource-manager/bicep/best-practices)

---

## 13. ADR-011: GitHub Actions for CI/CD

**Status:** ✅ Accepted  
**Date:** September 12, 2025  
**Decision Makers:** DevOps Team, Platform Team  
**Technical Area:** DevOps

### Context

The platform requires automated CI/CD for:

1. **Infrastructure**: Bicep template validation and deployment
2. **Application Code**: Function Apps, .NET projects
3. **Configuration**: Partner configs, schedule definitions
4. **Testing**: Unit tests, integration tests, security scans
5. **Multi-Environment**: Dev, Test, Prod deployments

### Decision

**Standardize on GitHub Actions for all CI/CD workflows.**

**Workflow Structure:**

- `.github/workflows/ci-functions.yml` - Function App builds and tests
- `.github/workflows/cd-infrastructure.yml` - Bicep deployments
- `.github/workflows/cd-functions-dev.yml` - Dev deployments
- `.github/workflows/cd-functions-prod.yml` - Prod deployments

### Rationale

#### Why GitHub Actions?

| Factor | GitHub Actions | Azure DevOps | Jenkins |
|--------|---------------|--------------|---------|
| **Integration** | ✅ Native GitHub | ⚠️ Separate service | ⚠️ Self-hosted |
| **Cost** | ✅ 2,000 min/month free | ⚠️ $40/user/month | ⚠️ Infrastructure cost |
| **Marketplace** | ✅ 10,000+ actions | ⚠️ Limited extensions | ⚠️ Plugin ecosystem |
| **Learning Curve** | ✅ Low (YAML) | ⚠️ Medium | ❌ High |
| **Hosted Runners** | ✅ Free for public | ✅ Included | ❌ Self-manage |

**GitHub Actions Advantages:**

- **Native integration**: PRs, issues, commits trigger workflows
- **Marketplace**: Reusable actions (Azure login, Bicep deploy, test reports)
- **Matrix builds**: Test across multiple .NET versions
- **Secrets management**: GitHub secrets integration
- **Cost-effective**: Generous free tier

### Alternatives Considered

#### Option 1: Azure DevOps Pipelines

**Approach**: Use Azure Pipelines for all CI/CD.

**Pros:**

- Azure-native service
- Strong Azure integrations
- Mature platform

**Cons:**

- **Separate UI**: Different from GitHub
- **Cost**: $40/user/month (after free tier)
- **Complexity**: YAML + classic pipelines
- **Learning curve**: Different mental model from GitHub

**Decision:** ❌ Rejected - GitHub Actions sufficient; avoid separate tool

---

#### Option 2: Jenkins (Self-Hosted)

**Approach**: Deploy Jenkins on Azure VM or AKS.

**Pros:**

- Full control
- Extensive plugin ecosystem
- On-premises support (if needed)

**Cons:**

- **Operational burden**: Manage Jenkins infrastructure
- **Cost**: VM/AKS hosting costs
- **Security**: Patch management, credential storage
- **Complexity**: Groovy pipelines, plugin management

**Decision:** ❌ Rejected - Not worth operational overhead

---

#### Option 3: GitLab CI/CD

**Approach**: Migrate to GitLab for integrated CI/CD.

**Pros:**

- Integrated platform (source + CI/CD)
- Strong Kubernetes support

**Cons:**

- **Migration effort**: Move all repos from GitHub
- **Team familiarity**: Team already knows GitHub
- **Cost**: GitLab Premium $19/user/month
- **Azure integration**: Less mature than GitHub Actions

**Decision:** ❌ Rejected - No compelling reason to migrate

### Consequences

#### Benefits

| Benefit | Impact |
|---------|--------|
| **Developer Experience** | Workflows in same repo as code |
| **Cost-Effective** | 2,000 minutes/month free tier |
| **Marketplace** | Reusable community actions |
| **Security** | Dependabot, CodeQL scanning built-in |
| **Visibility** | PR checks, status badges, deployment tracking |

#### Trade-offs

| Trade-off | Description | Mitigation |
|-----------|-------------|------------|
| **Vendor Lock-In** | GitHub-specific workflow syntax | Document workflows; avoid GitHub-specific features |
| **Minutes Limit** | Free tier: 2,000 min/month | Monitor usage; optimize workflows |
| **Runner Availability** | Shared runners can queue during peak | Self-hosted runners for critical paths |

### Implementation

#### Function App CI Workflow

```yaml
name: CI - Functions

on:
  pull_request:
    branches: [main, develop]
    paths:
      - 'src/**'
      - 'tests/**'

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        dotnet-version: ['8.0.x']
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: ${{ matrix.dotnet-version }}
      
      - name: Restore dependencies
        run: dotnet restore
      
      - name: Build
        run: dotnet build --configuration Release --no-restore
      
      - name: Test
        run: dotnet test --configuration Release --no-build --verbosity normal --collect:"XPlat Code Coverage"
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.cobertura.xml
```

#### Infrastructure CD Workflow

```yaml
name: CD - Infrastructure (Prod)

on:
  push:
    branches: [main]
    paths:
      - 'infra/bicep/**'

jobs:
  deploy-infrastructure:
    runs-on: ubuntu-latest
    environment: production
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy Bicep
        uses: azure/arm-deploy@v1
        with:
          subscriptionId: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          resourceGroupName: rg-edi-prod
          template: ./infra/bicep/main.bicep
          parameters: ./infra/bicep/parameters/prod.parameters.json
          failOnStdErr: false
```

### Monitoring

```kql
// GitHub Actions workflow success rate (from webhook/API logs)
GitHubWorkflowRuns_CL
| summarize 
    total = count(),
    failures = countif(Conclusion == "failure"),
    success_rate = round(100.0 * countif(Conclusion == "success") / count(), 2)
  by WorkflowName, bin(TimeGenerated, 1d)
| render timechart
```

### References

- [Document 04a: GitHub Actions Implementation](../04a-github-actions-implementation.md)
- [Document 05: SDLC & DevOps](../05-sdlc-devops-spec.md)
- [GitHub Actions Documentation](https://docs.github.com/actions)

---

## 14. ADR-012: Multi-Repository Strategy

**Status:** ✅ Accepted  
**Date:** September 8, 2025  
**Decision Makers:** Platform Team, Architecture Team  
**Technical Area:** DevOps

### Context

The EDI Platform consists of multiple components:

1. **Shared Libraries**: Core functionality (X12 parser, utilities)
2. **Function Apps**: Routing, mappers, connectors
3. **Infrastructure**: Bicep templates
4. **Databases**: SQL schemas, migrations
5. **Configuration**: Partner configs, schedules

**Questions:**

- Should all components live in a single monorepo?
- Or should we use separate repositories per component?
- How do we manage dependencies and versioning?

### Decision

**Adopt a multi-repository strategy with:**

1. **edi-platform-core**: Shared libraries (NuGet packages)
2. **edi-routing**: Routing Function App
3. **edi-mappers**: Mapper Function Apps
4. **edi-connectors**: Connector Function Apps
5. **edi-database-controlnumbers**: SQL project (DACPAC)
6. **edi-partner-configs**: Partner metadata (JSON)
7. **ai-adf-edi-spec**: Specifications and documentation

**Workspace Management:** `edi-platform` workspace repo coordinates multi-repo development.

### Rationale

#### Why Multi-Repo?

**Benefits:**

| Benefit | Description |
|---------|-------------|
| **Independent Releases** | Deploy shared libraries without deploying functions |
| **Smaller PRs** | Focused changes to specific components |
| **Clear Ownership** | Each repo has dedicated team |
| **CI/CD Efficiency** | Build only changed components |
| **Security** | Different access controls per repo |

**Monorepo Drawbacks (for this project):**

- Large repo size (slower clones)
- All-or-nothing deployments (higher risk)
- Complex CI/CD (conditionally build subprojects)
- Conflicting dependency versions

### Alternatives Considered

#### Option 1: Monorepo (Single Repository)

**Approach**: All code in one repository with folder structure:

```text
edi-platform/
├── shared/
│   └── HealthcareEDI.X12/
├── functions/
│   ├── routing/
│   ├── mappers/
│   └── connectors/
├── infra/
└── config/
```

**Pros:**

- Single place for all code
- Atomic commits across components
- No cross-repo dependency management

**Cons:**

- **Large repo**: Slower clones, searches
- **Complex CI/CD**: Must detect which components changed
- **Deployment coupling**: Changes to docs trigger function builds
- **Access control**: Harder to grant per-component access

**Decision:** ❌ Rejected - Too large, deployment coupling

---

#### Option 2: Micro-Repos (Per Function)

**Approach**: Separate repo for every single function.

**Pros:**

- Maximum isolation
- Very focused changes

**Cons:**

- **Repo sprawl**: 20+ repositories to manage
- **Dependency hell**: Shared code duplicated or versioned 20+ times
- **Cross-cutting changes**: Update 20 repos for shared library change
- **Cognitive overhead**: Developers lose context switching repos

**Decision:** ❌ Rejected - Too granular

### Consequences

#### Benefits

| Benefit | Impact |
|---------|--------|
| **Independent Releases** | Deploy shared library without deploying functions |
| **CI/CD Efficiency** | Build only changed components (faster) |
| **Clear Ownership** | Repo = team responsibility |
| **Security** | Granular access control per repo |

#### Trade-offs

| Trade-off | Description | Mitigation |
|-----------|-------------|------------|
| **Dependency Management** | Track NuGet package versions | Dependabot auto-updates |
| **Cross-Repo Changes** | Breaking changes require multiple PRs | Versioning strategy; changelog |
| **Workspace Setup** | Developers clone multiple repos | `edi-platform` workspace setup script |

### Implementation

#### Repository Structure

**edi-platform-core** (Shared Libraries):

```text
src/
├── HealthcareEDI.X12/          # X12 parser wrapper
├── HealthcareEDI.Common/       # Utilities, Result pattern
└── HealthcareEDI.Configuration/ # Partner config models
```

**edi-routing** (Routing Function):

```text
src/
├── EnvelopeRouter/             # Function code
└── EnvelopeRouter.Tests/       # Unit tests
```

**Dependency Flow:**

```text
edi-platform-core (NuGet)
    ↓
edi-routing (consumes NuGet package)
    ↓
edi-mappers (consumes NuGet + routing messages)
```

#### NuGet Package Versioning

```xml
<PropertyGroup>
  <PackageId>HealthcareEDI.X12</PackageId>
  <Version>1.2.3</Version>
  <Authors>Platform Team</Authors>
  <PackageLicenseExpression>MIT</PackageLicenseExpression>
</PropertyGroup>
```

#### Workspace Setup Script

```powershell
# edi-platform/setup-core.ps1
$repos = @(
    "edi-platform-core",
    "edi-routing",
    "edi-mappers",
    "edi-connectors",
    "edi-partner-configs"
)

foreach ($repo in $repos) {
    git clone "https://github.com/PointCHealth/$repo.git" "../$repo"
}
```

### Monitoring

```yaml
# Dependabot configuration (.github/dependabot.yml)
version: 2
updates:
  - package-ecosystem: "nuget"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
```

### References

- [GITHUB_REPOS_CREATED.md](../../GITHUB_REPOS_CREATED.md)
- [Document 03: Repository Setup Guide](../implementation-plan/03-repository-setup-guide.md)
- [Monorepo vs. Multi-Repo (Martin Fowler)](https://martinfowler.com/bliki/MonolithFirst.html)

---

## 15. ADR Review Schedule

### 15.1 Regular Review Cadence

Architecture Decision Records should be reviewed periodically to ensure they remain valid as technology, business requirements, and team expertise evolve.

**Review Schedule:**

| ADR | Initial Review Date | Review Frequency | Next Review Due | Owner |
|-----|---------------------|------------------|-----------------|-------|
| ADR-001 | 2026-03-15 | 6 months | 2026-09-15 | Platform Team |
| ADR-002 | 2026-03-18 | 6 months | 2026-09-18 | Platform Team |
| ADR-003 | 2026-04-05 | 6 months | 2026-10-05 | Engineering Team |
| ADR-004 | 2026-03-20 | 12 months | 2027-03-20 | Architecture Team |
| ADR-005 | 2026-03-16 | 12 months | 2027-03-16 | Data Team |
| ADR-006 | 2026-03-22 | 6 months | 2026-09-22 | Platform Team |
| ADR-007 | 2026-03-25 | 6 months | 2026-09-25 | Engineering Team |
| ADR-008 | 2026-03-19 | 6 months | 2026-09-19 | Platform Team |
| ADR-009 | 2026-03-28 | 12 months | 2027-03-28 | Engineering Team |
| ADR-010 | 2026-03-10 | 12 months | 2027-03-10 | DevOps Team |
| ADR-011 | 2026-03-12 | 12 months | 2027-03-12 | DevOps Team |
| ADR-012 | 2026-03-08 | 12 months | 2027-03-08 | Platform Team |

### 15.2 Review Triggers

In addition to scheduled reviews, ADRs should be reviewed when:

1. **Technology Changes**: New Azure services, library updates, platform deprecations
2. **Business Requirements**: New regulations, partner requirements, transaction types
3. **Performance Issues**: Current decisions not meeting SLAs or cost targets
4. **Team Feedback**: Developers identify pain points or improvement opportunities
5. **Security Incidents**: Vulnerabilities or compliance gaps discovered
6. **Vendor Announcements**: Microsoft deprecations, roadmap changes

### 15.3 Review Process

**Review Steps:**

1. **Gather Metrics**: Collect performance, cost, reliability data since last review
2. **Assess Current State**: Does decision still meet requirements?
3. **Evaluate Alternatives**: Have better options emerged?
4. **Document Findings**: Update ADR with review notes
5. **Take Action**: Confirm, modify, or supersede decision

**Review Template:**

```markdown
## Review: [Date]

**Reviewer:** [Name/Team]

**Metrics Since Last Review:**
- Performance: [data]
- Cost: [data]
- Reliability: [data]

**Assessment:**
- [ ] Decision still valid and optimal
- [ ] Minor adjustments needed
- [ ] Major revision required
- [ ] Should be superseded

**Action Items:**
- [List any follow-up actions]

**Next Review:** [Date]
```

### 15.4 Superseding ADRs

When a decision is no longer optimal, create a new ADR that supersedes the original:

1. Create new ADR (e.g., ADR-013) with updated decision
2. Update original ADR status to "Superseded by ADR-013"
3. Reference original ADR in new document ("Supersedes ADR-XXX")
4. Explain what changed and why

**Example:**

```markdown
# ADR-013: Redis for Control Number Management

**Status:** ✅ Accepted
**Supersedes:** ADR-009
**Date:** 2026-08-15

## Context

Since implementing SQL-based control numbers (ADR-009), we have experienced:
- High concurrency contention at peak load (>10,000 transactions/hour)
- P95 latency increased from 5ms to 50ms
- Database CPU consistently >80% during peak hours

[... rest of new ADR ...]
```

### 15.5 ADR Metrics Dashboard

Track ADR health and review compliance:

```kql
// ADR review compliance
ADRReviews_CL
| summarize 
    total_adrs = dcount(ADRNumber),
    overdue_reviews = countif(NextReviewDue < now()),
    upcoming_reviews = countif(NextReviewDue between (now() .. 30d))
| extend compliance_rate = round(100.0 * (total_adrs - overdue_reviews) / total_adrs, 2)
```

---

## 16. References

### 16.1 Related EDI Platform Documentation

**Architecture Specifications:**

- [Document 01: Architecture Specification](../01-architecture-spec.md)
- [Document 02: Data Flow Specification](../02-data-flow-spec.md)
- [Document 03: Security & Compliance](../03-security-compliance-spec.md)
- [Document 04: Infrastructure as Code Strategy](../04-iac-strategy-spec.md)
- [Document 04a: GitHub Actions Implementation](../04a-github-actions-implementation.md)
- [Document 05: SDLC & DevOps](../05-sdlc-devops-spec.md)
- [Document 06: Operations](../06-operations-spec.md)
- [Document 07: NFRs & Risks](../07-nfr-risks-spec.md)

**Implementation Guides:**

- [Document 08: Transaction Routing & Outbound](./08-transaction-routing-outbound-spec.md)
- [Document 09: Tagging & Governance](../09-tagging-governance-spec.md)
- [Document 10: Trading Partner Configuration](./10-trading-partner-config.md)
- [Document 11: Event Sourcing Architecture](../11-event-sourcing-architecture-spec.md)
- [Document 12: Raw File Storage Strategy](../12-raw-file-storage-strategy-spec.md)
- [Document 13: Partner Integration Adapters](../13-mapper-connector-spec.md)
- [Document 14: Enterprise Scheduler](../14-enterprise-scheduler-spec.md)
- [Document 15: Solution Structure Implementation](../15-solution-structure-implementation-guide.md)

**Transaction Flow Documentation:**

- [Document 11: Transaction Flow 270/271 (Eligibility)](./13-transaction-flow-270-271.md)
- [Document 12: Transaction Flow 835 (Remittance)](./14-transaction-flow-835.md)

**Testing and Validation:**

- [Document 15: Implementation Validation Guide](./15-implementation-validation.md)

**Terminology:**

- [Document 16: Glossary and Terminology](./16-glossary-terminology.md)

### 16.2 External References

**Architecture Patterns:**

- [Martin Fowler: Architecture Decision Records](https://martinfowler.com/bliki/ArchitectureDecisionRecord.html)
- [Michael Nygard: Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [Azure Architecture Center](https://docs.microsoft.com/azure/architecture/)
- [Microsoft Cloud Adoption Framework](https://docs.microsoft.com/azure/cloud-adoption-framework/)

**Azure Service Documentation:**

- [Azure Data Factory](https://docs.microsoft.com/azure/data-factory/)
- [Azure Functions](https://docs.microsoft.com/azure/azure-functions/)
- [Azure Service Bus](https://docs.microsoft.com/azure/service-bus-messaging/)
- [Azure Storage](https://docs.microsoft.com/azure/storage/)
- [Azure Bicep](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Event Grid](https://docs.microsoft.com/azure/event-grid/)
- [Azure Key Vault](https://docs.microsoft.com/azure/key-vault/)
- [Azure Monitor](https://docs.microsoft.com/azure/azure-monitor/)

**EDI and Healthcare Standards:**

- [X12 Standards](https://x12.org/)
- [HIPAA Implementation Guides](https://www.cms.gov/regulations-and-guidance/hipaa-administrative-simplification)
- [Washington Publishing Company (WPC)](https://www.wpc-edi.com/)
- [OopFactory.X12 GitHub](https://github.com/Eddy-Guido/OopFactory.X12)

**Development Practices:**

- [GitHub Actions Documentation](https://docs.github.com/actions)
- [.NET Documentation](https://docs.microsoft.com/dotnet/)
- [xUnit Documentation](https://xunit.net/)
- [Semantic Versioning](https://semver.org/)

### 16.3 ADR Template Location

The standard ADR template used by this project is located at:

```text
docs/decisions/adr-template.md
```

Use this template when creating new ADRs to ensure consistency across all architectural decisions.

### 16.4 Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-06 | EDI Platform Team | Initial ADR compilation document |

---

## Document Series Navigation

**Previous Document:** [Document 16: Glossary and Terminology](./16-glossary-terminology.md)  
**Next Document:** N/A (Final document in series)  
**Return to:** [System Documentation Index](./README.md)

---

**Document Maintained By:** Platform Architecture Team  
**Last Reviewed:** October 6, 2025  
**Next Review Due:** April 6, 2026  
**Status:** Active

---

*This document is part of the Healthcare EDI Platform system documentation series. For questions or suggestions, please contact the Platform Architecture Team.*
