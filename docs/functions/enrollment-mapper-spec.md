# Function Specification: EnrollmentMapper (834)

**Repository:** edi-mappers  
**Project Path:** `/functions/EnrollmentMapper.Function`  
**Azure Function Name:** `func-edi-enrollment-{env}-eastus2`  
**Runtime:** .NET 9 Isolated  
**Last Updated:** 2025-10-05

---

## Overview

The EnrollmentMapper function transforms healthcare enrollment/benefit transactions (X12 834) between X12 format and partner-specific formats. It implements **event sourcing** to maintain a complete history of enrollment changes for audit compliance and data reconciliation.

---

## Responsibilities

1. **834 Parsing:** Parse incoming 834 transactions (inbound from payers)
2. **834 Generation:** Generate outbound 834 transactions (to partners)
3. **Transformation:** Apply partner-specific mapping rules
4. **Event Sourcing:** Store enrollment events for audit trail
5. **State Projection:** Maintain current enrollment state from event stream
6. **Validation:** Enforce business rules and data quality checks
7. **Error Handling:** Capture and report mapping errors

**Key Feature:** Event sourcing enables temporal queries ("What was member's coverage on date X?")

---

## Triggers

### 1. Service Bus Queue (Primary)

**Trigger Type:** `ServiceBusTrigger`  
**Queue Name:** `enrollment-mapper-queue`  
**Message Source:** InboundRouter function or Partner API

**Message Schema:**

```json
{
  "messageId": "guid",
  "correlationId": "guid",
  "direction": "inbound | outbound",
  "transactionType": "834",
  "data": {
    "blobUrl": "https://storage.../raw/inbound/partner001/834_20251005.x12",
    "partnerId": "partner001",
    "mappingProfile": "partner001-834-inbound-v1"
  }
}
```

### 2. HTTP Manual Mapping (Secondary)

**Route:** `POST /api/map/834`  
**Auth Level:** Function (requires key)

**Request Body:**

```json
{
  "x12Content": "ISA*00*...",
  "partnerId": "partner001",
  "direction": "inbound",
  "validateOnly": false
}
```

**Response:**

```json
{
  "success": true,
  "eventsCreated": 3,
  "enrollmentId": "ENR-2025-001234",
  "memberId": "M123456789",
  "effectiveDate": "2025-01-01",
  "errors": []
}
```

---

## Processing Logic

### Main Flow

```csharp
[Function("EnrollmentMapper")]
public async Task Run(
    [ServiceBusTrigger("enrollment-mapper-queue")] ServiceBusReceivedMessage message,
    ServiceBusMessageActions messageActions,
    FunctionContext context)
{
    var logger = context.GetLogger<EnrollmentMapper>();
    var correlationId = message.CorrelationId;
    
    try
    {
        // 1. Parse incoming message
        var routingMessage = JsonSerializer.Deserialize<RoutingMessage>(message.Body);
        
        // 2. Download file content
        var x12Content = await DownloadBlobAsync(routingMessage.Data.BlobUrl);
        
        // 3. Parse 834 transaction
        var transaction834 = _x12Parser.Parse834(x12Content);
        
        // 4. Load mapping rules for partner
        var mappingRules = await _configService.GetMappingRulesAsync(
            routingMessage.Data.PartnerId,
            "834",
            routingMessage.Direction);
        
        // 5. Transform to canonical model
        var enrollmentEvents = Transform834ToEvents(transaction834, mappingRules);
        
        // 6. Validate events
        var validationResult = ValidateEnrollmentEvents(enrollmentEvents);
        if (!validationResult.IsValid)
        {
            await HandleValidationErrors(validationResult);
            return;
        }
        
        // 7. Store events (event sourcing)
        await _eventStore.AppendEventsAsync(enrollmentEvents, correlationId);
        
        // 8. Project current state
        var currentState = await _stateProjector.ProjectEnrollmentStateAsync(
            enrollmentEvents.First().MemberId);
        
        // 9. Publish state change notification
        await _notificationService.PublishEnrollmentChangedAsync(currentState);
        
        // 10. Complete Service Bus message
        await messageActions.CompleteMessageAsync(message);
        
        logger.LogInformation(
            "Processed 834 for {MemberId}, created {EventCount} events",
            currentState.MemberId,
            enrollmentEvents.Count);
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Failed to process 834 transaction");
        await messageActions.DeadLetterMessageAsync(message, ex.Message);
    }
}
```

### 834 Parsing

```csharp
private Transaction834 Parse834(string x12Content)
{
    // Use OopFactory.X12 via HealthcareEDI.X12 wrapper
    var parser = new X12Parser();
    var interchange = parser.ParseMultiple(x12Content).First();
    var transaction = interchange.FunctionalGroups[0].Transactions[0];
    
    // Extract 834-specific segments
    return new Transaction834
    {
        // Header
        TransactionSetControlNumber = transaction.ControlNumber,
        TransactionDate = ParseDate(transaction.GetSegment("BGN").GetElement(4)),
        
        // Sponsor (Loop 1000A)
        SponsorName = transaction.GetLoop("1000A")?.GetSegment("N1")?.GetElement(2),
        SponsorId = transaction.GetLoop("1000A")?.GetSegment("N1")?.GetElement(4),
        
        // Payer (Loop 1000B)
        PayerName = transaction.GetLoop("1000B")?.GetSegment("N1")?.GetElement(2),
        PayerId = transaction.GetLoop("1000B")?.GetSegment("N1")?.GetElement(4),
        
        // Members (Loop 2000)
        Members = transaction.GetLoops("2000").Select(memberLoop => new Member834
        {
            // Member level (Loop 2000)
            SubscriberIndicator = memberLoop.GetSegment("INS").GetElement(2),
            MaintenanceTypeCode = memberLoop.GetSegment("INS").GetElement(3),
            MaintenanceReasonCode = memberLoop.GetSegment("INS").GetElement(4),
            
            // Member name (Loop 2100A)
            LastName = memberLoop.GetLoop("2100A").GetSegment("NM1").GetElement(3),
            FirstName = memberLoop.GetLoop("2100A").GetSegment("NM1").GetElement(4),
            MiddleName = memberLoop.GetLoop("2100A").GetSegment("NM1").GetElement(5),
            MemberId = memberLoop.GetLoop("2100A").GetSegment("NM1").GetElement(9),
            
            // Demographics
            DateOfBirth = ParseDate(memberLoop.GetLoop("2100A").GetSegment("DMG")?.GetElement(2)),
            Gender = memberLoop.GetLoop("2100A").GetSegment("DMG")?.GetElement(3),
            
            // Coverage (Loop 2300)
            CoverageLines = memberLoop.GetLoops("2300").Select(covLoop => new Coverage834
            {
                MaintenanceTypeCode = covLoop.GetSegment("HD").GetElement(1),
                InsuranceLineCode = covLoop.GetSegment("HD").GetElement(3),
                PlanCoverageDescription = covLoop.GetSegment("HD").GetElement(4),
                CoverageLevelCode = covLoop.GetSegment("HD").GetElement(5),
                
                // Dates (DTP segments)
                EffectiveDate = ParseDate(covLoop.GetSegment("DTP", "348")?.GetElement(3)),
                TerminationDate = ParseDate(covLoop.GetSegment("DTP", "349")?.GetElement(3))
            }).ToList()
        }).ToList()
    };
}
```

### Transformation to Events

```csharp
private List<EnrollmentEvent> Transform834ToEvents(
    Transaction834 transaction,
    MappingRules mappingRules)
{
    var events = new List<EnrollmentEvent>();
    
    foreach (var member in transaction.Members)
    {
        // Determine event type from maintenance codes
        var eventType = DetermineEventType(
            member.MaintenanceTypeCode,
            member.MaintenanceReasonCode);
        
        switch (eventType)
        {
            case EnrollmentEventType.MemberAdded:
                events.Add(new MemberAddedEvent
                {
                    EventId = Guid.NewGuid(),
                    Timestamp = transaction.TransactionDate,
                    MemberId = member.MemberId,
                    FirstName = member.FirstName,
                    LastName = member.LastName,
                    DateOfBirth = member.DateOfBirth,
                    Gender = member.Gender,
                    EffectiveDate = member.CoverageLines.First().EffectiveDate
                });
                break;
            
            case EnrollmentEventType.MemberTerminated:
                events.Add(new MemberTerminatedEvent
                {
                    EventId = Guid.NewGuid(),
                    Timestamp = transaction.TransactionDate,
                    MemberId = member.MemberId,
                    TerminationDate = member.CoverageLines.First().TerminationDate,
                    TerminationReason = member.MaintenanceReasonCode
                });
                break;
            
            case EnrollmentEventType.CoverageAdded:
                foreach (var coverage in member.CoverageLines)
                {
                    events.Add(new CoverageAddedEvent
                    {
                        EventId = Guid.NewGuid(),
                        Timestamp = transaction.TransactionDate,
                        MemberId = member.MemberId,
                        InsuranceLineCode = coverage.InsuranceLineCode,
                        PlanName = coverage.PlanCoverageDescription,
                        CoverageLevel = coverage.CoverageLevelCode,
                        EffectiveDate = coverage.EffectiveDate
                    });
                }
                break;
            
            case EnrollmentEventType.CoverageTerminated:
                foreach (var coverage in member.CoverageLines)
                {
                    events.Add(new CoverageTerminatedEvent
                    {
                        EventId = Guid.NewGuid(),
                        Timestamp = transaction.TransactionDate,
                        MemberId = member.MemberId,
                        InsuranceLineCode = coverage.InsuranceLineCode,
                        TerminationDate = coverage.TerminationDate
                    });
                }
                break;
        }
    }
    
    return events;
}

private EnrollmentEventType DetermineEventType(
    string maintenanceTypeCode, 
    string maintenanceReasonCode)
{
    // Maintenance Type Code:
    // 001 = Change
    // 021 = Addition
    // 024 = Termination or Cancellation
    // 030 = Audit or Compare
    
    // Maintenance Reason Code:
    // 25 = Change in Identifying Data Elements
    // 32 = Termination of Coverage
    // AI = Add Insurance
    // EC = Benefit Selection
    // etc.
    
    return (maintenanceTypeCode, maintenanceReasonCode) switch
    {
        ("021", _) => EnrollmentEventType.MemberAdded,
        ("024", _) => EnrollmentEventType.MemberTerminated,
        ("001", "AI") => EnrollmentEventType.CoverageAdded,
        ("001", "32") => EnrollmentEventType.CoverageTerminated,
        ("001", "25") => EnrollmentEventType.DemographicsChanged,
        _ => EnrollmentEventType.MemberChanged
    };
}
```

---

## Event Sourcing Implementation

### Event Store Schema (SQL Database)

**Table:** `EnrollmentEvents`

```sql
CREATE TABLE EnrollmentEvents (
    EventId UNIQUEIDENTIFIER PRIMARY KEY,
    MemberId VARCHAR(50) NOT NULL,
    EventType VARCHAR(50) NOT NULL,
    EventTimestamp DATETIME2 NOT NULL,
    EventData NVARCHAR(MAX) NOT NULL, -- JSON
    CorrelationId UNIQUEIDENTIFIER NOT NULL,
    PartnerId VARCHAR(50) NOT NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    INDEX IX_MemberId (MemberId),
    INDEX IX_EventTimestamp (EventTimestamp),
    INDEX IX_CorrelationId (CorrelationId)
);
```

**Sample Event Data (JSON):**

```json
{
  "eventType": "MemberAdded",
  "eventId": "guid",
  "timestamp": "2025-01-01T00:00:00Z",
  "memberId": "M123456789",
  "firstName": "John",
  "lastName": "Doe",
  "dateOfBirth": "1985-03-15",
  "gender": "M",
  "effectiveDate": "2025-01-01",
  "metadata": {
    "source": "834_transaction",
    "partnerId": "partner001",
    "transactionControlNumber": "0001"
  }
}
```

### State Projection

**Table:** `CurrentEnrollmentState`

```sql
CREATE TABLE CurrentEnrollmentState (
    MemberId VARCHAR(50) PRIMARY KEY,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    DateOfBirth DATE,
    Gender CHAR(1),
    EnrollmentStatus VARCHAR(20), -- Active, Terminated, Pending
    EffectiveDate DATE,
    TerminationDate DATE,
    LastUpdated DATETIME2,
    CoverageLines NVARCHAR(MAX) -- JSON array of coverage
);
```

**Projection Logic:**

```csharp
public async Task<EnrollmentState> ProjectEnrollmentStateAsync(string memberId)
{
    // Fetch all events for member
    var events = await _eventStore.GetEventsForMemberAsync(memberId);
    
    // Replay events to build current state
    var state = new EnrollmentState { MemberId = memberId };
    
    foreach (var evt in events.OrderBy(e => e.Timestamp))
    {
        state = ApplyEvent(state, evt);
    }
    
    // Cache projected state
    await _cache.SetAsync($"enrollment:{memberId}", state, TimeSpan.FromHours(1));
    
    return state;
}

private EnrollmentState ApplyEvent(EnrollmentState state, EnrollmentEvent evt)
{
    switch (evt)
    {
        case MemberAddedEvent e:
            state.FirstName = e.FirstName;
            state.LastName = e.LastName;
            state.DateOfBirth = e.DateOfBirth;
            state.Gender = e.Gender;
            state.EffectiveDate = e.EffectiveDate;
            state.Status = EnrollmentStatus.Active;
            break;
        
        case MemberTerminatedEvent e:
            state.TerminationDate = e.TerminationDate;
            state.Status = EnrollmentStatus.Terminated;
            break;
        
        case CoverageAddedEvent e:
            state.CoverageLines.Add(new CoverageLine
            {
                InsuranceLineCode = e.InsuranceLineCode,
                PlanName = e.PlanName,
                EffectiveDate = e.EffectiveDate
            });
            break;
        
        // ... other event types
    }
    
    return state;
}
```

### Temporal Queries

```csharp
// Query: "What was member's coverage on 2025-03-01?"
public async Task<EnrollmentState> GetStateAtPointInTimeAsync(
    string memberId, 
    DateTime asOfDate)
{
    var events = await _eventStore.GetEventsForMemberAsync(memberId);
    
    // Replay only events before asOfDate
    var relevantEvents = events
        .Where(e => e.Timestamp <= asOfDate)
        .OrderBy(e => e.Timestamp);
    
    var state = new EnrollmentState { MemberId = memberId };
    foreach (var evt in relevantEvents)
    {
        state = ApplyEvent(state, evt);
    }
    
    return state;
}
```

---

## Configuration

### Application Settings

```json
{
  "ServiceBus__ConnectionString": "@Microsoft.KeyVault(...)",
  "ServiceBus__EnrollmentQueueName": "enrollment-mapper-queue",
  "SqlDatabase__ConnectionString": "@Microsoft.KeyVault(...)",
  "PartnerConfig__StorageAccount": "stediprodeastus2",
  "PartnerConfig__Container": "config/partners",
  "EventStore__BatchSize": 1000,
  "EventStore__RetentionDays": 2555,
  "Cache__RedisConnectionString": "@Microsoft.KeyVault(...)"
}
```

---

## Performance

### Targets

| Metric | Target |
|--------|--------|
| Latency (P95) | < 5 seconds per transaction |
| Throughput | 500 834 transactions/hour |
| Event Store Write | < 100ms per event |
| State Projection | < 500ms per member |

### Optimization

1. **Batch Event Writes:** Insert events in batches (SQL bulk insert)
2. **Cache Projections:** Cache current state for 1 hour
3. **Snapshot Strategy:** Store state snapshots every 100 events to speed replay
4. **Async Projection:** Project state asynchronously after event storage

---

## Dependencies

```xml
<ItemGroup>
  <PackageReference Include="Microsoft.Azure.Functions.Worker" Version="1.21.0" />
  <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.ServiceBus" Version="5.16.0" />
  <PackageReference Include="Microsoft.Data.SqlClient" Version="5.1.0" />
  <PackageReference Include="StackExchange.Redis" Version="2.7.0" />
</ItemGroup>

<ItemGroup>
  <ProjectReference Include="..\..\src\HealthcareEDI.X12\HealthcareEDI.X12.csproj" />
  <ProjectReference Include="..\..\src\HealthcareEDI.EventSourcing\HealthcareEDI.EventSourcing.csproj" />
</ItemGroup>
```

---

**Last Updated:** 2025-10-05  
**Owner:** Platform Engineering Team
