# Messaging Architecture Alignment Summary

**Document Version:** 1.0  
**Date:** October 5, 2025  
**Status:** Aligned  

---

## Purpose

This document clarifies the aligned messaging architecture across Azure Event Grid, Azure Service Bus, and Azure Event Hubs for the Healthcare EDI Ingestion & Routing Platform. It provides the rationale for each service selection and guidance for future development.

---

## Executive Summary

The platform has been aligned to use **three distinct Azure messaging services**, each serving a specific architectural purpose:

1. **Azure Event Grid** - Blob event triggers only
2. **Azure Service Bus** - Transaction routing and message distribution
3. **Azure Event Hubs** - NOT USED (previously mentioned incorrectly)

**Key Change**: All references to "Event Hub" in routing contexts have been replaced with "Service Bus" to reflect the correct architectural choice.

---

## Service Selection Matrix

| Service | Primary Use Case | Architecture Layer | Rationale | Used? |
|---------|-----------------|-------------------|-----------|-------|
| **Event Grid** | Blob Created events from SFTP storage | Core Platform (Trigger) | Low-latency, lightweight event notification; perfect for triggering ADF pipelines on file arrival | ✅ YES |
| **Service Bus** | Transaction routing, message distribution | Routing & Service Bus Layer | Ordering guarantees, rich SQL filtering, sessions, dead-letter queues, durable message storage | ✅ YES |
| **Event Hubs** | High-throughput telemetry streaming | (N/A) | NOT needed for this architecture; Service Bus handles all routing and lineage event needs | ❌ NO |

---

## Detailed Service Usage

### 1. Azure Event Grid (Trigger Mechanism)

**Purpose**: Detect file arrival and trigger processing pipelines

**Usage Pattern**:
```text
Partner SFTP Upload → Blob Storage → Event Grid (Blob Created Event) → ADF Pipeline Trigger
```

**Configuration**:
- Event Grid System Topic on SFTP-enabled storage account
- Subject filter: `/inbound/` paths only
- Event subscription delivers to ADF managed trigger

**Key Benefits**:
- Sub-second latency for event detection
- Automatic retry with exponential backoff
- No polling overhead
- Built-in dead-letter handling

**Limitations Accepted**:
- At-least-once delivery (handled by idempotency in pipelines)
- Event Grid does NOT provide ordering guarantees (not needed for file arrival detection)

---

### 2. Azure Service Bus (Routing & Distribution)

**Purpose**: Route EDI transactions to trading partners and orchestrate message processing

**Usage Pattern**:
```text
Validated EDI File → Router Function (Envelope Parse) 
  → Service Bus Topic: edi-routing 
    → Subscriptions (Filtered by transactionSet, partnerCode, direction)
      → Trading Partner Integration Adapters
        → Partner Endpoints (SFTP, API, Database, Queue)
```

**Configuration**:
- **Topics**:
  - `edi-routing` - Primary transaction routing fan-out
  - `edi-outbound-ready` - Signals for acknowledgment assembly
  - `edi-deadletter` - Poison message handling

- **Subscriptions** (examples):
  - `sub-enrollment-partner` - Filter: `transactionSet = '834'`
  - `sub-claims-partner` - Filter: `transactionSet LIKE '837%'`
  - `sub-eligibility-partner` - Filter: `transactionSet IN ('270','271')`
  - `sub-remittance-partner` - Filter: `transactionSet = '835'`

- **Subscription Rules**:
  - SQL-based filters on message properties
  - Correlation filters for complex routing logic
  - Action rules for message enrichment

**Key Benefits**:
1. **Ordering Guarantees**: FIFO processing with sessions (per partner/transaction)
2. **Rich Filtering**: SQL expressions on message properties (no code changes for routing updates)
3. **Dead Letter Queues**: Automatic isolation of poison messages per subscription
4. **Sessions**: Conversation-based processing for transaction correlation
5. **Peek-Lock Semantics**: Reliable message processing with retry/abandon
6. **Duplicate Detection**: Time-based duplicate message suppression
7. **Scheduled Messages**: Future delivery for delayed processing
8. **Transactions**: Cross-entity transaction support

**Performance Targets**:
- Routing latency p95 < 2 seconds (envelope parse to message publish)
- Message throughput: 100+ messages/second (Standard tier)
- Subscription filter evaluation: < 5ms per message

**Why Service Bus over Event Hub?**

| Requirement | Service Bus | Event Hub | Winner |
|-------------|------------|-----------|--------|
| Message ordering (per partition/session) | ✅ Strong (Sessions) | ✅ Strong (Partitions) | TIE |
| Rich SQL filtering on properties | ✅ Yes | ❌ No (consume all) | **Service Bus** |
| Dead letter queue per subscription | ✅ Yes | ❌ No (manual) | **Service Bus** |
| Message TTL & expiration | ✅ Yes | ✅ Yes (retention) | TIE |
| Peek-Lock semantics | ✅ Yes | ❌ No (checkpoint) | **Service Bus** |
| Subscription model (1:N fan-out) | ✅ Native | ❌ Manual (consumer groups) | **Service Bus** |
| Transaction support | ✅ Yes | ❌ No | **Service Bus** |
| Throughput (Standard tier) | 100s/sec | Millions/sec | Event Hub (not needed) |
| Cost (low volume) | Lower | Higher | **Service Bus** |

**Decision**: Service Bus is the correct choice because:
- **Rich filtering eliminates code**: Routing rules configured in subscription filters, not application code
- **Dead letter isolation**: Failed messages don't block healthy processing
- **Lower operational complexity**: No manual partition management or consumer group coordination
- **Throughput is sufficient**: Standard tier (100+ msg/sec) handles projected volume (peak 200 routing messages/minute)

---

### 3. Azure Event Hubs (NOT USED)

**Previous Incorrect Mention**: Doc 13 (mapper-connector-spec.md) mentioned emitting lineage events to Event Hub

**Correction**: Service Bus handles lineage events with the same topic-subscription model

**Why Event Hubs Not Needed**:
- Projected lineage event volume: ~500 events/hour (low)
- Service Bus throughput is more than sufficient
- Avoids adding another messaging service to the architecture
- Service Bus provides better integration with existing routing topology

**When Event Hubs WOULD Be Appropriate** (future consideration):
- High-throughput telemetry streaming (millions of events/second)
- Real-time analytics pipelines (Stream Analytics, Databricks)
- Log aggregation from thousands of sources
- IoT device telemetry

**Platform Guidance**: Do not introduce Event Hubs unless sustained throughput exceeds 1,000 messages/second or streaming analytics is required.

---

## Alignment Changes Made

The following documents were updated to replace "Event Hub" references with "Service Bus":

| Document | Change | Rationale |
|----------|--------|-----------|
| `README.md` | "Routing & Event Hub Layer" → "Routing & Service Bus Layer" | Corrects layer naming in architecture diagram |
| `implementation-plan/00-implementation-overview.md` | "Routing & Event Hub Layer" → "Routing & Service Bus Layer" | Aligns implementation roadmap terminology |
| `docs/15-solution-structure-implementation-guide.md` | "Routing & Event Hub Layer" → "Routing & Service Bus Layer" | Updates layer responsibility matrix and section headers |
| `docs/13-mapper-connector-spec.md` | "emit lineage events to Event Hub" → "emit lineage events to Service Bus topic" | Corrects lineage event destination |

---

## Event Grid Usage Confirmed Correct

**Event Grid continues to be used ONLY for**:
- Blob Created events from SFTP storage (trigger ADF pipelines)
- Optional future use: File change notifications for configuration reload

**Event Grid is NOT used for**:
- Transaction routing (Service Bus handles this)
- Message distribution to partners (Service Bus handles this)
- Acknowledgment orchestration (Service Bus handles this)

This separation is correct:
- Event Grid excels at lightweight event notification
- Service Bus excels at durable message routing with filtering

---

## Implementation Guidance

### For Platform Engineers

**When to use Event Grid**:
```csharp
// Triggering pipelines on external events
// Example: File arrival, configuration change
storageAccount.eventGridSystemTopic
  .createSubscription("blob-created-trigger")
  .withSubjectFilter("/inbound/")
  .deliverTo(adfPipelineTrigger);
```

**When to use Service Bus**:
```csharp
// Routing transactions with filtering
// Example: Send 834 enrollment transactions to enrollment service
serviceBusTopic.createSubscription("sub-enrollment-partner")
  .withSqlFilter("transactionSet = '834' AND direction = 'INBOUND'")
  .withDeadLetterQueue(enabled: true);

// Publishing routing messages
await serviceBusClient
  .CreateSender("edi-routing")
  .SendMessageAsync(new ServiceBusMessage(routingPayload)
  {
      ApplicationProperties = 
      {
          ["transactionSet"] = "834",
          ["partnerCode"] = "PARTNERA",
          ["priority"] = "standard"
      }
  });
```

**When NOT to add Event Hubs**:
- Current architecture does not require Event Hubs
- Only consider if sustained throughput exceeds 1,000 msg/sec
- Only consider if streaming analytics (Stream Analytics, real-time dashboards) is required

### For AI Code Generation

**Prompts should specify**:
- "Use Service Bus topics for transaction routing"
- "Use Event Grid for blob event triggers only"
- "Do not use Event Hubs unless streaming analytics is explicitly required"

**Example correct prompt**:
> "Generate an Azure Function that parses EDI envelope headers and publishes routing messages to a Service Bus topic with filtered subscriptions per trading partner"

**Example incorrect prompt** (avoid):
> "Generate an Azure Function that streams routing events to Event Hub for partner consumption"

---

## Configuration Reference

### Service Bus Namespace Configuration

```bicep
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2021-11-01' = {
  name: 'sb-edi-${environment}'
  location: location
  sku: {
    name: 'Standard' // Premium for production (if throughput > 500 msg/sec)
    tier: 'Standard'
  }
  properties: {
    zoneRedundant: true // Production only
  }
}

resource routingTopic 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' = {
  parent: serviceBusNamespace
  name: 'edi-routing'
  properties: {
    enablePartitioning: true
    defaultMessageTimeToLive: 'P1D' // 1 day
    maxSizeInMegabytes: 5120
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'PT10M' // 10 minutes
  }
}

resource enrollmentSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-11-01' = {
  parent: routingTopic
  name: 'sub-enrollment-partner'
  properties: {
    deadLetteringOnMessageExpiration: true
    maxDeliveryCount: 5
    defaultMessageTimeToLive: 'P1D'
  }
}

resource enrollmentFilter 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2021-11-01' = {
  parent: enrollmentSubscription
  name: 'enrollmentFilter'
  properties: {
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression: "transactionSet = '834' AND direction IN ('INBOUND', 'INTERNAL')"
    }
  }
}
```

### Event Grid Configuration

```bicep
resource eventGridSystemTopic 'Microsoft.EventGrid/systemTopics@2021-12-01' = {
  name: 'evgt-edi-${environment}'
  location: location
  properties: {
    source: storageAccount.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

resource blobCreatedSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2021-12-01' = {
  parent: eventGridSystemTopic
  name: 'blob-created-trigger'
  properties: {
    destination: {
      endpointType: 'AzureFunction' // or 'WebHook' for ADF
      properties: {
        resourceId: adfPipelineTrigger.id
      }
    }
    filter: {
      subjectBeginsWith: '/blobServices/default/containers/sftp-root/blobs/inbound/'
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
    retryPolicy: {
      maxDeliveryAttempts: 30
      eventTimeToLiveInMinutes: 1440 // 24 hours
    }
    deadLetterDestination: {
      endpointType: 'StorageBlob'
      properties: {
        resourceId: storageAccount.id
        blobContainerName: 'eventgrid-deadletter'
      }
    }
  }
}
```

---

## Monitoring & Observability

### Service Bus Metrics to Track

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Incoming Messages | ~76,000/month | N/A (informational) |
| Active Messages | < 100 (draining) | > 1,000 (investigate backlog) |
| Dead Letter Messages | 0 | > 10 (investigate failures) |
| Server Errors | 0 | > 5/hour (alert platform team) |
| Throttled Requests | 0 | > 1 (consider Premium tier) |
| Message Size Average | < 10 KB | N/A |
| Routing Latency p95 | < 2 sec | > 5 sec (performance degradation) |

### Event Grid Metrics to Track

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Delivered Events | ~21,700/month | N/A |
| Matched Events | ~21,700/month | N/A |
| Unmatched Events | 0 | > 10 (filter misconfiguration) |
| Dead Letter Events | 0 | > 5 (delivery failures) |
| Publish Latency p95 | < 100ms | > 500ms (investigate) |

---

## Cost Implications

### Service Bus (Standard Tier)

**Monthly Estimate (Projected Volume)**:
- Base charge: ~$9.86/month (730 hours @ $0.0135/hour)
- Operations: ~400,000 (publish + deliveries + management)
- Billable operations: First 12.5M included
- **Total: $10/month (Low scenario), $40/month (High scenario)**

### Event Grid

**Monthly Estimate**:
- Operations: ~21,700 (blob created events)
- First 100,000 operations free
- **Total: $0/month (under free tier)**

### Cost Comparison vs. Event Hubs

If Event Hubs were incorrectly used:
- Basic tier: ~$11/month (730 hours @ $0.015/hour) + ingress
- Standard tier: ~$22/month + throughput units
- **Event Hubs would be MORE expensive for low-volume routing**

**Decision Validation**: Service Bus is cost-effective for current scale (< 1M messages/month)

---

## Future Considerations

### When to Upgrade Service Bus to Premium

**Consider Premium tier when**:
- Sustained throughput > 500 messages/second
- Need dedicated capacity and guaranteed IOPS
- Require private endpoints with no public access
- Need geo-disaster recovery with automatic failover
- **Cost**: ~$672/month (1 messaging unit)

**Current Recommendation**: Stay on Standard tier until volume projections exceed 1M messages/month

### When to Introduce Event Hubs

**Consider Event Hubs when**:
- Real-time analytics required (Stream Analytics, Databricks Structured Streaming)
- Sustained ingestion rate > 1,000 events/second
- Need long-term event replay (> 7 days retention)
- Building event sourcing with temporal queries
- IoT telemetry aggregation from thousands of devices

**Current Recommendation**: Not needed; revisit if streaming analytics requirements emerge

---

## Conclusion

The Healthcare EDI platform messaging architecture is now **fully aligned**:

✅ **Event Grid**: File arrival triggers only  
✅ **Service Bus**: Transaction routing, message distribution, lineage events  
❌ **Event Hubs**: Not used (previously incorrect references removed)

This alignment provides:
- **Clarity**: Each service has a single, well-defined purpose
- **Simplicity**: Fewer services to manage and monitor
- **Cost-effectiveness**: No over-engineering for current scale
- **Scalability**: Clear upgrade paths when volume increases
- **Maintainability**: Consistent patterns across the platform

All documentation has been updated to reflect this aligned architecture.

---

**Document Owner**: Platform Architecture Team  
**Review Date**: October 5, 2025  
**Next Review**: Q1 2026 (after Phase 2 deployment)
