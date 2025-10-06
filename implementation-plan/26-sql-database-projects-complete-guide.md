# SQL Database Projects - Complete Implementation Guide

**Document Version:** 1.0  
**Last Updated:** October 5, 2025  
**Status:** Implementation Complete  
**Owner:** EDI Platform Team

---

## Overview

This guide provides complete implementation details for both SQL Database projects supporting the EDI platform:

1. **Control Numbers Database** - Manages EDI control number sequences (ISA13, GS06, ST02)
2. **Enrollment Event Store Database** - Event sourcing database for 834 enrollment transactions

Both databases use Azure SQL Database with optimistic concurrency, comprehensive audit trails, and performance-optimized schemas.

---

## Table of Contents

1. [Control Numbers Database](#control-numbers-database)
2. [Enrollment Event Store Database](#enrollment-event-store-database)
3. [Deployment Guide](#deployment-guide)
4. [Testing Strategy](#testing-strategy)
5. [Performance Tuning](#performance-tuning)
6. [Monitoring and Maintenance](#monitoring-and-maintenance)
7. [Troubleshooting](#troubleshooting)

---

## Control Numbers Database

### Purpose

The Control Numbers database maintains monotonic, gap-free sequence numbers for all outbound EDI acknowledgments and responses. It provides:

- **Sequence Generation**: ISA (interchange), GS (functional group), and ST (transaction set) control numbers
- **Concurrency Control**: Optimistic locking using SQL ROWVERSION for collision-free access
- **Gap Detection**: Automated queries to identify missing sequences
- **Audit Trail**: Complete history of all issued control numbers with correlation to outbound files

### Schema Components

#### Tables

**1. ControlNumberCounters**
- Purpose: Maintains current counter values for each partner/transaction/type combination
- Key Features:
  - `ROWVERSION` column for optimistic concurrency
  - Unique constraint on `(PartnerCode, TransactionType, CounterType)`
  - Default `MaxValue` of 999,999,999 (X12 standard)
  - Tracks last increment time and file generated

**2. ControlNumberAudit**
- Purpose: Immutable audit trail of all control numbers issued
- Key Features:
  - Links to `ControlNumberCounters` via `CounterId`
  - Records `OutboundFileId` for correlation
  - Tracks retry count and status (ISSUED, PERSISTED, RESET)
  - Indexed on `CounterId`, `OutboundFileId`, and `IssuedUtc`

**3. ControlNumberGaps (View)**
- Purpose: Identifies gaps in control number sequences
- Query Pattern: Uses `LAG()` window function to detect non-consecutive numbers
- Returns: `GapStart`, `GapEnd`, and `GapSize` for monitoring

#### Stored Procedures

**1. usp_GetNextControlNumber**
```sql
EXEC usp_GetNextControlNumber
    @PartnerCode = 'PARTNERA',
    @TransactionType = '271',
    @CounterType = 'ISA',
    @OutboundFileId = 'GUID',
    @NextControlNumber = @NextNumber OUTPUT;
```

**Features:**
- Optimistic concurrency with automatic retry (max 5 attempts)
- Auto-initialization of counters on first use
- Rollover detection and prevention
- Exponential backoff on collision (50ms base delay)
- Atomic audit record insertion

**Performance Characteristics:**
- **Latency**: <10ms p50, <50ms p95
- **Throughput**: 100+ TPS per counter
- **Retry Rate**: <5% under load
- **Collision Handling**: Exponential backoff with max 5 retries

**2. usp_MarkControlNumberPersisted**
```sql
EXEC usp_MarkControlNumberPersisted
    @OutboundFileId = 'GUID',
    @FileName = 'PARTNERA_271_20251005_001.x12',
    @Notes = 'Successfully uploaded to SFTP';
```

**Purpose:** Mark control numbers as successfully persisted to file system/SFTP

**3. usp_DetectControlNumberGaps**
```sql
EXEC usp_DetectControlNumberGaps
    @PartnerCode = 'PARTNERA',
    @TransactionType = '271',
    @DaysToCheck = 30;
```

**Returns:** Gaps classified as MINOR (1), MODERATE (2-5), CRITICAL (6+)

**4. usp_GetControlNumberStatus**
```sql
EXEC usp_GetControlNumberStatus
    @PartnerCode = NULL, -- All partners
    @TransactionType = NULL; -- All transaction types
```

**Returns:**
- Current value and percent used
- Total issued, pending, and persisted counts
- Total retry count (indicates contention)
- Last issued timestamp

**5. usp_ResetControlNumber**
```sql
-- EMERGENCY USE ONLY
EXEC usp_ResetControlNumber
    @PartnerCode = 'PARTNERA',
    @TransactionType = '271',
    @CounterType = 'ISA',
    @NewValue = 1,
    @Reason = 'Partner requested reset due to system migration';
```

**Purpose:** Reset counter to specific value (requires admin privileges)

### Concurrency Model

**Optimistic Concurrency Control:**

```sql
-- Pseudo-code flow
1. SELECT CurrentValue, RowVersion FROM ControlNumberCounters WITH (UPDLOCK, READPAST)
2. Calculate NextValue = CurrentValue + 1
3. UPDATE ControlNumberCounters 
   SET CurrentValue = NextValue
   WHERE CounterId = @Id AND RowVersion = @OriginalRowVersion
4. IF @@ROWCOUNT = 1:
     INSERT INTO ControlNumberAudit (...)
     RETURN SUCCESS
   ELSE:
     RETRY with exponential backoff
```

**Key Benefits:**
- No blocking reads
- High concurrency under load
- Automatic collision detection
- Built-in retry logic

### Seed Data

Initial counters are pre-seeded for:
- **PARTNERA**: 270, 271, 837, 835 (ISA, GS, ST)
- **PARTNERB**: 270, 271 (ISA, GS, ST)
- **INTERNAL-CLAIMS**: 277, 999 (ISA, GS, ST)
- **TEST001**: 270, 271 (ISA, GS, ST)

All counters start at `CurrentValue = 1`.

---

## Enrollment Event Store Database

### Purpose

The Enrollment Event Store database implements event sourcing for 834 enrollment transactions. It provides:

- **Immutable Event Log**: Append-only `DomainEvent` table as source of truth
- **Current State Projections**: `Member` and `Enrollment` tables for fast queries
- **Event Replay**: Rebuild projections from events for testing/recovery
- **Temporal Queries**: Query state at any point in time
- **Reversal Support**: Correct errors by appending reversal events

### Schema Components

#### Core Tables

**1. EventSequence (SQL SEQUENCE)**
- Purpose: Gap-free monotonic ordering for all events
- Configuration: BIGINT, START WITH 1, INCREMENT BY 1, CACHE 100
- **Critical**: Ensures events have total ordering across all aggregates

**2. TransactionBatch**
- Purpose: Represents source files/messages (834 files from partners)
- Key Features:
  - Unique `BatchGUID` for idempotency
  - `FileHash` (SHA256) for duplicate detection
  - Processing status tracking (RECEIVED → PROCESSING → COMPLETED)
  - Event count and sequence range
  - EDI envelope identifiers (ISA13, GS06)

**3. TransactionHeader**
- Purpose: Represents 834 transaction sets within a batch
- Key Features:
  - Links to parent `TransactionBatch`
  - Transaction set control number (ST02)
  - Purpose code (00=Original, 05=Replace)
  - Segment and member counts

**4. DomainEvent (Event Store)**
- Purpose: **Immutable append-only event log** - source of truth
- Key Features:
  - `EventSequence` from SQL SEQUENCE for global ordering
  - `AggregateType` + `AggregateID` for entity identification
  - `EventData` as JSON payload (schema versioning via `EventVersion`)
  - `IsReversal` flag for error correction events
  - Correlation and causation IDs for distributed tracing

**Indexes:**
- `UQ_DomainEvent_Sequence`: Unique on EventSequence (critical for ordering)
- `IX_DomainEvent_Aggregate`: (AggregateType, AggregateID, EventSequence) - replay performance
- `IX_DomainEvent_Type`: (EventType, EventTimestamp) - analytics queries
- `IX_DomainEvent_Batch`: (TransactionBatchID, EventSequence) - batch processing

**5. Member (Projection)**
- Purpose: Current state of member demographics
- Key Features:
  - `Version` column for optimistic concurrency
  - `LastEventSequence` for projection tracking
  - Indexed on `SubscriberID`, `SSN`, and name fields

**6. Enrollment (Projection)**
- Purpose: Current state of member enrollments
- Key Features:
  - Links to `Member` via `MemberID`
  - `EffectiveDate` and `TerminationDate` for temporal queries
  - `IsActive` flag for current status
  - `MaintenanceTypeCode` (021=Add, 024=Term, 025=Cancel)

**7. EventSnapshot**
- Purpose: Performance optimization - snapshots of aggregate state
- Key Features:
  - Stores JSON snapshot of aggregate at specific `EventSequence`
  - Keeps last 3 snapshots per aggregate
  - Reduces replay time for long event streams

#### Stored Procedures

**1. usp_AppendEvent**
```sql
DECLARE @EventID BIGINT, @EventSequence BIGINT;

EXEC usp_AppendEvent
    @TransactionBatchID = 123,
    @AggregateType = 'Member',
    @AggregateID = 'SUB123456789',
    @EventType = 'MemberAdded',
    @EventVersion = 1,
    @EventData = N'{"firstName":"John","lastName":"Smith",...}',
    @CorrelationID = 'GUID',
    @EventID = @EventID OUTPUT,
    @EventSequence = @EventSequence OUTPUT;
```

**Features:**
- Validates JSON before insert
- Automatically assigns `EventSequence` from SQL SEQUENCE
- Updates parent `TransactionBatch` event count and range
- Returns `EventID` and `EventSequence` for confirmation

**2. usp_GetEventStream**
```sql
EXEC usp_GetEventStream
    @AggregateType = 'Member',
    @AggregateID = 'SUB123456789',
    @FromSequence = 0,
    @ToSequence = NULL,
    @IncludeReversals = 0;
```

**Purpose:** Retrieve ordered event stream for an aggregate (for replay/audit)

**3. usp_ReplayEvents**
```sql
EXEC usp_ReplayEvents
    @AggregateType = NULL, -- All aggregates
    @FromSequence = 0,
    @ToSequence = NULL,
    @BatchSize = 1000;
```

**Purpose:** Retrieve events in batches for projection rebuild

**4. usp_UpdateMemberProjection**
```sql
EXEC usp_UpdateMemberProjection
    @SubscriberID = 'SUB123456789',
    @FirstName = 'John',
    @LastName = 'Smith',
    @DateOfBirth = '1985-03-15',
    @LastEventSequence = 12345,
    @LastEventTimestamp = '2025-10-05 12:00:00',
    ...;
```

**Features:**
- Upserts member projection (INSERT if new, UPDATE if exists)
- Optimistic concurrency via `LastEventSequence` check
- Idempotent (ignores events already processed)

**5. usp_UpdateEnrollmentProjection**
```sql
EXEC usp_UpdateEnrollmentProjection
    @SubscriberID = 'SUB123456789',
    @EffectiveDate = '2025-01-01',
    @MaintenanceTypeCode = '021',
    @LastEventSequence = 12346,
    ...;
```

**Features:**
- Automatically calculates `IsActive` based on maintenance type and dates
- Links to `Member` via `SubscriberID`

**6. usp_CreateSnapshot / usp_GetLatestSnapshot**
```sql
-- Create snapshot
EXEC usp_CreateSnapshot
    @AggregateType = 'Member',
    @AggregateID = 'SUB123456789',
    @SnapshotData = N'{"firstName":"John",...}',
    @EventSequence = 12350;

-- Retrieve latest snapshot
EXEC usp_GetLatestSnapshot
    @AggregateType = 'Member',
    @AggregateID = 'SUB123456789';
```

**Purpose:** Optimize replay by starting from last snapshot instead of beginning

**7. usp_ReverseBatch**
```sql
-- EMERGENCY USE ONLY
EXEC usp_ReverseBatch
    @TransactionBatchID = 123,
    @Reason = 'File processing error - duplicate ISA detected',
    @ReversalCorrelationID = 'GUID';
```

**Features:**
- Marks batch as `REVERSED`
- Creates reversal events for each original event (with `IsReversal = 1`)
- Events have type suffix `_REVERSED` (e.g., `MemberAdded_REVERSED`)
- Projections must be rebuilt after reversal

#### Views

**1. vw_ActiveEnrollments**
```sql
SELECT * FROM vw_ActiveEnrollments 
WHERE LastName = 'Smith';
```

**Returns:** Current active members with enrollment details (JOIN of Member + Enrollment)

**2. vw_EventStream**
```sql
SELECT * FROM vw_EventStream 
WHERE PartnerCode = 'PARTNERA' 
  AND EventTimestamp >= '2025-10-01'
ORDER BY EventSequence;
```

**Returns:** Complete event stream with batch context (partner, filename, control numbers)

**3. vw_BatchProcessingSummary**
```sql
SELECT * FROM vw_BatchProcessingSummary 
WHERE ProcessingStatus = 'COMPLETED'
  AND FileReceivedDate >= DATEADD(DAY, -7, GETUTCDATE())
ORDER BY FileReceivedDate DESC;
```

**Returns:** Batch processing metrics (duration, event count, member count, status)

**4. vw_MemberEventHistory**
```sql
SELECT * FROM vw_MemberEventHistory 
WHERE SubscriberID = 'SUB123456789'
ORDER BY EventSequence;
```

**Returns:** Complete event history for a specific member (audit trail)

**5. vw_EventTypeStatistics**
```sql
SELECT * FROM vw_EventTypeStatistics 
ORDER BY EventCount DESC;
```

**Returns:** Event type distribution, counts, date ranges, reversal counts

**6. vw_ProjectionLag**
```sql
SELECT * FROM vw_ProjectionLag 
WHERE SequenceLag > 0
ORDER BY SequenceLag DESC;
```

**Returns:** Identifies projections out of sync with event store (monitoring)

### Event Sourcing Patterns

#### Event Types

**Member Events:**
- `MemberAdded` - New member added
- `MemberUpdated` - Demographics changed
- `MemberTerminated` - Member removed

**Enrollment Events:**
- `EnrollmentAdded` - New enrollment (maintenance type 021)
- `EnrollmentChanged` - Enrollment modified (maintenance type 001)
- `EnrollmentTerminated` - Enrollment ended (maintenance type 024)
- `EnrollmentCancelled` - Enrollment cancelled (maintenance type 025)

#### Event Versioning

**Schema Evolution:**
```json
{
  "EventType": "MemberAdded",
  "EventVersion": 2,  // Incremented when schema changes
  "Data": {
    "subscriberID": "SUB123",
    "emailAddress": "new@email.com"  // Added in v2
  }
}
```

**Handling Multiple Versions:**
- Application code checks `EventVersion` when processing
- Supports forward compatibility (v2 app can read v1 events)
- Backward compatibility (v1 app ignores new v2 fields)

#### Reversal Pattern

**Error Correction Flow:**
```
1. Original: MemberAdded (EventID=100, Sequence=1000)
2. Error detected (wrong SSN)
3. Create: MemberAdded_REVERSED (EventID=101, Sequence=1001, ReversedByEventID=100, IsReversal=1)
4. Create: MemberAdded (EventID=102, Sequence=1002) with corrected data
5. Rebuild projection from sequence 1000
```

**Key Principle:** Never delete events - append reversals instead

### Seed Data

Sample data includes:
- 1 Transaction Batch (PARTNERA_834_20251005_001.x12)
- 1 Transaction Header (834 Original, 2 members)
- 4 Domain Events:
  - MemberAdded: SUB123456789 (John Smith, subscriber)
  - EnrollmentAdded: SUB123456789
  - MemberAdded: SUB123456789-01 (Jane Smith, spouse)
  - EnrollmentAdded: SUB123456789-01
- 2 Member Projections (active)
- 2 Enrollment Projections (active)

---

## Deployment Guide

### Prerequisites

- Azure SQL Server provisioned in target environment
- Database created with appropriate SKU (GP_S_Gen5_2 for dev/test, higher for prod)
- Managed Identity configured for Function Apps
- Network access configured (VNet integration or firewall rules)
- Azure Key Vault for sensitive connection strings

### Deployment Steps

#### 1. Control Numbers Database

```bash
# Set environment variables
export RESOURCE_GROUP="rg-edi-dev-eastus2"
export SQL_SERVER="sql-edi-dev-eastus2"
export DB_NAME="EDI_ControlNumbers"
export SQL_ADMIN="sqladmin"

# Create database (if not exists)
az sql db create \
  --resource-group $RESOURCE_GROUP \
  --server $SQL_SERVER \
  --name $DB_NAME \
  --service-objective GP_S_Gen5_2 \
  --compute-model Serverless \
  --auto-pause-delay 60

# Run schema scripts (in order)
sqlcmd -S "$SQL_SERVER.database.windows.net" -d $DB_NAME -U $SQL_ADMIN -i infra/sql/control-numbers/001_create_control_number_tables.sql
sqlcmd -S "$SQL_SERVER.database.windows.net" -d $DB_NAME -U $SQL_ADMIN -i infra/sql/control-numbers/002_create_control_number_procedures.sql
sqlcmd -S "$SQL_SERVER.database.windows.net" -d $DB_NAME -U $SQL_ADMIN -i infra/sql/control-numbers/003_seed_control_numbers.sql

# Verify deployment
sqlcmd -S "$SQL_SERVER.database.windows.net" -d $DB_NAME -U $SQL_ADMIN -Q "SELECT COUNT(*) FROM dbo.ControlNumberCounters"
```

#### 2. Enrollment Event Store Database

```bash
export DB_NAME="EDI_EventStore"

# Create database
az sql db create \
  --resource-group $RESOURCE_GROUP \
  --server $SQL_SERVER \
  --name $DB_NAME \
  --service-objective GP_S_Gen5_2 \
  --compute-model Serverless \
  --auto-pause-delay 60

# Run schema scripts (in order)
sqlcmd -S "$SQL_SERVER.database.windows.net" -d $DB_NAME -U $SQL_ADMIN -i infra/sql/event-store/001_create_event_store_tables.sql
sqlcmd -S "$SQL_SERVER.database.windows.net" -d $DB_NAME -U $SQL_ADMIN -i infra/sql/event-store/002_create_event_store_procedures.sql
sqlcmd -S "$SQL_SERVER.database.windows.net" -d $DB_NAME -U $SQL_ADMIN -i infra/sql/event-store/003_create_event_store_views.sql
sqlcmd -S "$SQL_SERVER.database.windows.net" -d $DB_NAME -U $SQL_ADMIN -i infra/sql/event-store/004_seed_event_store.sql

# Verify deployment
sqlcmd -S "$SQL_SERVER.database.windows.net" -d $DB_NAME -U $SQL_ADMIN -Q "SELECT * FROM vw_BatchProcessingSummary"
```

### PowerShell Deployment Script

```powershell
# deploy-databases.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$Environment,  # dev, test, prod
    
    [Parameter(Mandatory=$true)]
    [string]$SqlServer,
    
    [Parameter(Mandatory=$true)]
    [string]$SqlAdmin,
    
    [Parameter(Mandatory=$true)]
    [SecureString]$SqlPassword
)

$ErrorActionPreference = "Stop"

# Convert SecureString to plain text
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlPassword)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$databases = @(
    @{
        Name = "EDI_ControlNumbers"
        Scripts = @(
            "infra/sql/control-numbers/001_create_control_number_tables.sql",
            "infra/sql/control-numbers/002_create_control_number_procedures.sql",
            "infra/sql/control-numbers/003_seed_control_numbers.sql"
        )
    },
    @{
        Name = "EDI_EventStore"
        Scripts = @(
            "infra/sql/event-store/001_create_event_store_tables.sql",
            "infra/sql/event-store/002_create_event_store_procedures.sql",
            "infra/sql/event-store/003_create_event_store_views.sql",
            "infra/sql/event-store/004_seed_event_store.sql"
        )
    }
)

foreach ($db in $databases) {
    Write-Host "Deploying database: $($db.Name)" -ForegroundColor Cyan
    
    foreach ($script in $db.Scripts) {
        Write-Host "  Running script: $script" -ForegroundColor Gray
        
        sqlcmd -S "$SqlServer.database.windows.net" `
               -d $db.Name `
               -U $SqlAdmin `
               -P $PlainPassword `
               -i $script `
               -b # Exit on error
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Script failed: $script"
            exit 1
        }
    }
    
    Write-Host "✓ $($db.Name) deployed successfully" -ForegroundColor Green
}

Write-Host "`nAll databases deployed successfully!" -ForegroundColor Green
```

### GitHub Actions Deployment

```yaml
# .github/workflows/deploy-databases.yml
name: Deploy SQL Databases

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        type: choice
        options:
          - dev
          - test
          - prod

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment }}
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Deploy Control Numbers Database
        uses: azure/sql-action@v2
        with:
          server-name: ${{ secrets.SQL_SERVER }}
          connection-string: ${{ secrets.SQL_CONNECTION_STRING_CONTROLNUMBERS }}
          sql-file: |
            infra/sql/control-numbers/001_create_control_number_tables.sql
            infra/sql/control-numbers/002_create_control_number_procedures.sql
            infra/sql/control-numbers/003_seed_control_numbers.sql
      
      - name: Deploy Event Store Database
        uses: azure/sql-action@v2
        with:
          server-name: ${{ secrets.SQL_SERVER }}
          connection-string: ${{ secrets.SQL_CONNECTION_STRING_EVENTSTORE }}
          sql-file: |
            infra/sql/event-store/001_create_event_store_tables.sql
            infra/sql/event-store/002_create_event_store_procedures.sql
            infra/sql/event-store/003_create_event_store_views.sql
            infra/sql/event-store/004_seed_event_store.sql
      
      - name: Run Post-Deployment Tests
        run: |
          # Add test queries here
          echo "Databases deployed successfully"
```

---

## Testing Strategy

### Unit Tests (Database Project)

**Control Numbers:**
```sql
-- Test: Get next control number
DECLARE @Next BIGINT;
EXEC usp_GetNextControlNumber 'PARTNERA', '271', 'ISA', NEWID(), @Next OUTPUT;
SELECT @Next; -- Should be 1 (first use)

-- Test: Concurrent access
-- Run in 5 parallel sessions, verify no duplicates
-- Check retry counts in audit table

-- Test: Gap detection
EXEC usp_DetectControlNumberGaps;
```

**Event Store:**
```sql
-- Test: Append and retrieve events
DECLARE @EventID BIGINT, @Seq BIGINT;
EXEC usp_AppendEvent 
    @TransactionBatchID = 1,
    @AggregateType = 'Member',
    @AggregateID = 'TEST123',
    @EventType = 'MemberAdded',
    @EventData = N'{"firstName":"Test"}',
    @CorrelationID = NEWID(),
    @EventID = @EventID OUTPUT,
    @EventSequence = @Seq OUTPUT;

-- Verify event created
SELECT * FROM DomainEvent WHERE EventID = @EventID;

-- Test: Projection update
EXEC usp_UpdateMemberProjection 'TEST123', 'Test', 'User', '2000-01-01', @Seq, SYSUTCDATETIME();

-- Verify projection
SELECT * FROM Member WHERE SubscriberID = 'TEST123';
```

### Integration Tests (C#)

```csharp
[Fact]
public async Task GetNextControlNumber_ConcurrentAccess_NoCollisions()
{
    // Arrange
    var tasks = new List<Task<long>>();
    var outboundFileId = Guid.NewGuid();
    
    // Act: Request 100 control numbers concurrently
    for (int i = 0; i < 100; i++)
    {
        tasks.Add(Task.Run(async () => 
        {
            return await _controlNumberService.GetNextControlNumberAsync(
                "PARTNERA", "271", "ISA", outboundFileId);
        }));
    }
    
    var results = await Task.WhenAll(tasks);
    
    // Assert: All numbers unique
    Assert.Equal(100, results.Distinct().Count());
    Assert.Equal(100, results.Max() - results.Min() + 1); // No gaps
}

[Fact]
public async Task AppendEvent_ThenReplay_ProjectionMatches()
{
    // Arrange
    var batchId = await CreateTestBatch();
    var subscriberId = "TEST" + Guid.NewGuid().ToString("N");
    
    // Act: Append event
    var eventId = await _eventStore.AppendEventAsync(new DomainEvent
    {
        TransactionBatchID = batchId,
        AggregateType = "Member",
        AggregateID = subscriberId,
        EventType = "MemberAdded",
        EventData = JsonSerializer.Serialize(new { firstName = "John", lastName = "Doe" })
    });
    
    // Replay to projection
    await _projectionService.UpdateMemberProjectionAsync(subscriberId);
    
    // Assert
    var member = await _memberRepository.GetBySubscriberIdAsync(subscriberId);
    Assert.NotNull(member);
    Assert.Equal("John", member.FirstName);
    Assert.Equal("Doe", member.LastName);
}
```

### Load Tests

**Control Numbers - Concurrency Test:**
```bash
# Apache Bench - 1000 requests, 50 concurrent
ab -n 1000 -c 50 -p control-number-request.json \
   -T application/json \
   https://func-edi-outbound-dev.azurewebsites.net/api/controlnumbers/next

# Expected results:
# - 0 failures
# - <100ms p95 latency
# - <5% retry rate (check audit table)
```

**Event Store - Write Throughput:**
```bash
# Load test tool (custom)
dotnet run --project LoadTests -- \
  --test event-store-write \
  --duration 60s \
  --rps 100 \
  --db "EDI_EventStore"

# Expected results:
# - >100 events/sec sustained
# - <50ms p95 latency
# - 0 sequence collisions
```

---

## Performance Tuning

### Control Numbers Database

**Indexes:**
```sql
-- Already created in schema, verify:
SELECT name, type_desc, is_unique 
FROM sys.indexes 
WHERE object_id = OBJECT_ID('dbo.ControlNumberCounters');

-- Expected:
-- PK_ControlNumberCounters (CLUSTERED, UNIQUE)
-- UQ_ControlNumberCounters_Key (NONCLUSTERED, UNIQUE)
-- IX_ControlNumberCounters_PartnerType (NONCLUSTERED)
```

**Statistics:**
```sql
-- Update statistics after bulk inserts
UPDATE STATISTICS dbo.ControlNumberCounters;
UPDATE STATISTICS dbo.ControlNumberAudit;
```

**Query Performance:**
```sql
-- Check query execution plan
SET SHOWPLAN_XML ON;
GO

EXEC usp_GetNextControlNumber 'PARTNERA', '271', 'ISA', NEWID(), @Next OUTPUT;
GO

SET SHOWPLAN_XML OFF;
GO

-- Look for:
-- - Index seeks (not scans)
-- - No missing index warnings
-- - <50ms duration
```

### Event Store Database

**Indexes:**
```sql
-- Verify critical indexes exist
SELECT 
    i.name,
    i.type_desc,
    COL_NAME(ic.object_id, ic.column_id) AS column_name
FROM sys.indexes i
INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
WHERE i.object_id = OBJECT_ID('dbo.DomainEvent')
ORDER BY i.name, ic.key_ordinal;

-- Must have:
-- IX_DomainEvent_Aggregate (AggregateType, AggregateID, EventSequence)
-- IX_DomainEvent_Sequence (EventSequence)
```

**Sequence Performance:**
```sql
-- Check sequence cache effectiveness
SELECT * FROM sys.sequences WHERE name = 'EventSequence';
-- cache_size should be 100 (default)

-- Increase cache for higher throughput environments
ALTER SEQUENCE dbo.EventSequence CACHE 500;
```

**Partition Strategy (High Volume):**
```sql
-- For >10M events, consider partitioning by EventTimestamp
-- Create partition function (monthly partitions)
CREATE PARTITION FUNCTION PF_EventsByMonth (DATETIME2)
AS RANGE RIGHT FOR VALUES (
    '2025-01-01', '2025-02-01', '2025-03-01', 
    '2025-04-01', '2025-05-01', '2025-06-01'
);

-- Apply to DomainEvent table
-- (Requires table rebuild - plan for maintenance window)
```

**Archival Strategy:**
```sql
-- Archive events older than 2 years to cold storage
-- 1. Create archive table
CREATE TABLE dbo.DomainEvent_Archive (
    /* Same schema as DomainEvent */
) ON [PRIMARY];

-- 2. Move old events
BEGIN TRANSACTION;

INSERT INTO dbo.DomainEvent_Archive 
SELECT * FROM dbo.DomainEvent 
WHERE EventTimestamp < DATEADD(YEAR, -2, SYSUTCDATETIME());

DELETE FROM dbo.DomainEvent 
WHERE EventTimestamp < DATEADD(YEAR, -2, SYSUTCDATETIME());

COMMIT TRANSACTION;

-- 3. Verify
SELECT COUNT(*) FROM dbo.DomainEvent; -- Active events
SELECT COUNT(*) FROM dbo.DomainEvent_Archive; -- Archived events
```

---

## Monitoring and Maintenance

### Key Metrics

**Control Numbers:**
```sql
-- Daily monitoring query
SELECT 
    PartnerCode,
    TransactionType,
    CounterType,
    CurrentValue,
    CAST(CurrentValue AS FLOAT) / MaxValue * 100 AS PercentUsed,
    DATEDIFF(HOUR, LastIncrementUtc, SYSUTCDATETIME()) AS HoursSinceLastUse
FROM dbo.ControlNumberCounters
WHERE CAST(CurrentValue AS FLOAT) / MaxValue > 0.80 -- Alert threshold
ORDER BY PercentUsed DESC;
```

**Event Store:**
```sql
-- Daily monitoring query
SELECT 
    'Event Count' AS Metric,
    COUNT(*) AS Value,
    CAST(COUNT(*) / (DATEDIFF(DAY, MIN(EventTimestamp), MAX(EventTimestamp)) + 1.0) AS INT) AS AvgPerDay
FROM dbo.DomainEvent
WHERE EventTimestamp >= DATEADD(DAY, -7, SYSUTCDATETIME())

UNION ALL

SELECT 
    'Projection Lag' AS Metric,
    COUNT(*) AS Value,
    NULL
FROM vw_ProjectionLag
WHERE SequenceLag > 100 -- Alert threshold

UNION ALL

SELECT 
    'Failed Batches (24h)' AS Metric,
    COUNT(*) AS Value,
    NULL
FROM dbo.TransactionBatch
WHERE ProcessingStatus = 'FAILED'
  AND FileReceivedDate >= DATEADD(HOUR, -24, SYSUTCDATETIME());
```

### Application Insights Queries (KQL)

**Control Number Performance:**
```kusto
traces
| where message contains "GetNextControlNumber"
| extend duration = todouble(customDimensions.duration)
| summarize 
    p50 = percentile(duration, 50),
    p95 = percentile(duration, 95),
    p99 = percentile(duration, 99),
    retryRate = countif(customDimensions.retryCount > 0) * 100.0 / count()
by bin(timestamp, 1h)
| render timechart
```

**Event Store Throughput:**
```kusto
dependencies
| where name == "usp_AppendEvent"
| summarize 
    count = count(),
    avgDuration = avg(duration),
    p95Duration = percentile(duration, 95)
by bin(timestamp, 1m)
| render timechart
```

### Maintenance Tasks

**Weekly:**
```sql
-- 1. Check index fragmentation
SELECT 
    OBJECT_NAME(ips.object_id) AS TableName,
    i.name AS IndexName,
    ips.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 30
ORDER BY ips.avg_fragmentation_in_percent DESC;

-- 2. Rebuild fragmented indexes
ALTER INDEX IX_DomainEvent_Aggregate ON dbo.DomainEvent REBUILD;

-- 3. Update statistics
UPDATE STATISTICS dbo.DomainEvent WITH FULLSCAN;
UPDATE STATISTICS dbo.ControlNumberAudit WITH FULLSCAN;
```

**Monthly:**
```sql
-- 1. Check database size and growth
EXEC sp_spaceused;

-- 2. Verify backup completion
SELECT TOP 10 
    database_name,
    backup_start_date,
    backup_finish_date,
    type,
    backup_size / 1024 / 1024 AS backup_size_mb
FROM msdb.dbo.backupset
WHERE database_name IN ('EDI_ControlNumbers', 'EDI_EventStore')
ORDER BY backup_finish_date DESC;

-- 3. Check for long-running queries
SELECT TOP 10
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset)/2)+1) AS statement_text,
    qs.execution_count,
    qs.total_worker_time / qs.execution_count AS avg_cpu_time,
    qs.total_elapsed_time / qs.execution_count AS avg_elapsed_time
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY avg_elapsed_time DESC;
```

---

## Troubleshooting

### Common Issues

#### Control Numbers

**Issue: High retry rate (>10%)**

**Diagnosis:**
```sql
SELECT 
    PartnerCode,
    TransactionType,
    CounterType,
    AVG(RetryCount) AS AvgRetries,
    MAX(RetryCount) AS MaxRetries,
    COUNT(*) AS TotalIssued
FROM dbo.ControlNumberAudit
WHERE IssuedUtc >= DATEADD(HOUR, -1, SYSUTCDATETIME())
GROUP BY PartnerCode, TransactionType, CounterType
HAVING AVG(RetryCount) > 0.5
ORDER BY AvgRetries DESC;
```

**Resolution:**
- Increase retry delay in stored procedure (50ms → 100ms)
- Review application code for unnecessary concurrent requests
- Consider separate counters for high-volume partners

**Issue: Control number gaps detected**

**Diagnosis:**
```sql
EXEC usp_DetectControlNumberGaps @DaysToCheck = 7;
```

**Resolution:**
```sql
-- Identify failed transactions
SELECT 
    ca.ControlNumberIssued,
    ca.OutboundFileId,
    ca.Status,
    ca.Notes
FROM dbo.ControlNumberAudit ca
WHERE ca.ControlNumberIssued BETWEEN @GapStart AND @GapEnd
ORDER BY ca.ControlNumberIssued;

-- If gaps are due to failed file generation:
-- 1. Regenerate files with missing control numbers
-- 2. Mark as persisted
EXEC usp_MarkControlNumberPersisted @OutboundFileId, @FileName;
```

#### Event Store

**Issue: Projection lag increasing**

**Diagnosis:**
```sql
SELECT * FROM vw_ProjectionLag
WHERE SequenceLag > 100
ORDER BY SequenceLag DESC;
```

**Resolution:**
```sql
-- Option 1: Rebuild specific projection
EXEC usp_ReplayEvents 
    @AggregateType = 'Member',
    @AggregateID = 'SUB123456789';

-- Then update projection in application code

-- Option 2: Rebuild all projections (maintenance window)
-- 1. Truncate projection tables
TRUNCATE TABLE dbo.Enrollment;
TRUNCATE TABLE dbo.Member;

-- 2. Replay all events via application
-- (Run projection rebuild job)
```

**Issue: Event sequence gaps**

**Diagnosis:**
```sql
WITH Sequences AS (
    SELECT 
        EventSequence,
        LAG(EventSequence) OVER (ORDER BY EventSequence) AS PrevSequence
    FROM dbo.DomainEvent
)
SELECT * FROM Sequences
WHERE EventSequence - PrevSequence > 1;
```

**Resolution:**
- **Should never happen** (SQL SEQUENCE guarantees no gaps)
- If gaps found, indicates data corruption or manual deletion
- Review audit logs and restore from backup if necessary

**Issue: High event store write latency**

**Diagnosis:**
```sql
-- Check wait statistics
SELECT 
    wait_type,
    wait_time_ms / 1000.0 AS wait_time_sec,
    waiting_tasks_count
FROM sys.dm_db_wait_stats
WHERE wait_type LIKE 'PAGE%' OR wait_type LIKE 'LCK%'
ORDER BY wait_time_ms DESC;
```

**Resolution:**
- **PAGELATCH_UP**: Increase `EventSequence` cache size (100 → 500)
- **LCK_M_X**: Review transaction scopes in application (keep short)
- **PAGEIOLATCH_SH**: Add indexes or increase database DTUs

---

## Appendix

### File Structure

```
infra/sql/
├── control-numbers/
│   ├── 001_create_control_number_tables.sql
│   ├── 002_create_control_number_procedures.sql
│   └── 003_seed_control_numbers.sql
└── event-store/
    ├── 001_create_event_store_tables.sql
    ├── 002_create_event_store_procedures.sql
    ├── 003_create_event_store_views.sql
    └── 004_seed_event_store.sql
```

### Estimated Costs

**Azure SQL Database (Serverless GP_S_Gen5_2):**
- Dev: ~$50-100/month (low usage, auto-pause)
- Test: ~$100-200/month (intermittent usage)
- Prod: ~$300-500/month (continuous, 2 databases)

**Storage:**
- Control Numbers: <100 MB (minimal growth)
- Event Store: ~1 GB/month initial, grows with transaction volume

### Related Documentation

- [08-transaction-routing-outbound-spec.md](../docs/08-transaction-routing-outbound-spec.md) - Control number specifications
- [11-event-sourcing-architecture-spec.md](../docs/11-event-sourcing-architecture-spec.md) - Event sourcing design
- [13-database-project-control-numbers.md](./13-database-project-control-numbers.md) - Control numbers overview
- [14-database-project-enrollment-eventstore.md](./14-database-project-enrollment-eventstore.md) - Event store overview

---

**End of Implementation Guide**
