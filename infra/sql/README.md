# SQL Database Projects - Quick Reference

This directory contains complete SQL database implementations for the EDI platform.

## Databases

### 1. Control Numbers Database (`EDI_ControlNumbers`)
**Purpose:** Manages EDI control number sequences (ISA13, GS06, ST02) for outbound acknowledgments

**Files:**
- `001_create_control_number_tables.sql` - Schema (tables, indexes, views)
- `002_create_control_number_procedures.sql` - Stored procedures
- `003_seed_control_numbers.sql` - Initial seed data

**Key Features:**
- Optimistic concurrency control (ROWVERSION)
- Automatic gap detection
- Comprehensive audit trail
- Rollover protection

**Primary Stored Procedure:**
```sql
EXEC usp_GetNextControlNumber 
    @PartnerCode = 'PARTNERA',
    @TransactionType = '271', 
    @CounterType = 'ISA',
    @OutboundFileId = @FileId,
    @NextControlNumber = @Next OUTPUT;
```

### 2. Enrollment Event Store Database (`EDI_EventStore`)
**Purpose:** Event sourcing database for 834 enrollment transactions

**Files:**
- `001_create_event_store_tables.sql` - Schema (tables, indexes, sequence)
- `002_create_event_store_procedures.sql` - Stored procedures
- `003_create_event_store_views.sql` - Views for querying
- `004_seed_event_store.sql` - Sample data

**Key Features:**
- Immutable event log (append-only `DomainEvent` table)
- Gap-free event ordering (SQL SEQUENCE)
- Current state projections (`Member`, `Enrollment`)
- Event replay capability
- Reversal support for error correction

**Primary Stored Procedures:**
```sql
-- Append event
EXEC usp_AppendEvent 
    @AggregateType = 'Member',
    @AggregateID = 'SUB123',
    @EventType = 'MemberAdded',
    @EventData = N'{"firstName":"John",...}',
    @CorrelationID = @CorrelationId,
    @EventID = @EventId OUTPUT;

-- Get event stream
EXEC usp_GetEventStream 
    @AggregateType = 'Member',
    @AggregateID = 'SUB123';

-- Update projection
EXEC usp_UpdateMemberProjection 
    @SubscriberID = 'SUB123',
    @FirstName = 'John',
    @LastName = 'Smith',
    ...;
```

## Deployment

### Quick Deploy (Azure CLI)

```bash
# Control Numbers Database
az sql db create --resource-group rg-edi-dev --server sql-edi-dev --name EDI_ControlNumbers --service-objective GP_S_Gen5_2
sqlcmd -S sql-edi-dev.database.windows.net -d EDI_ControlNumbers -U admin -i control-numbers/001_*.sql
sqlcmd -S sql-edi-dev.database.windows.net -d EDI_ControlNumbers -U admin -i control-numbers/002_*.sql
sqlcmd -S sql-edi-dev.database.windows.net -d EDI_ControlNumbers -U admin -i control-numbers/003_*.sql

# Event Store Database
az sql db create --resource-group rg-edi-dev --server sql-edi-dev --name EDI_EventStore --service-objective GP_S_Gen5_2
sqlcmd -S sql-edi-dev.database.windows.net -d EDI_EventStore -U admin -i event-store/001_*.sql
sqlcmd -S sql-edi-dev.database.windows.net -d EDI_EventStore -U admin -i event-store/002_*.sql
sqlcmd -S sql-edi-dev.database.windows.net -d EDI_EventStore -U admin -i event-store/003_*.sql
sqlcmd -S sql-edi-dev.database.windows.net -d EDI_EventStore -U admin -i event-store/004_*.sql
```

### PowerShell Deploy

```powershell
# See implementation-plan/26-sql-database-projects-complete-guide.md
.\deploy-databases.ps1 -Environment dev -SqlServer sql-edi-dev -SqlAdmin admin
```

### GitHub Actions

```yaml
# .github/workflows/deploy-databases.yml
# See implementation-plan/26-sql-database-projects-complete-guide.md
```

## Testing

### Verify Deployment

```sql
-- Control Numbers
USE EDI_ControlNumbers;
SELECT * FROM dbo.ControlNumberCounters;
EXEC usp_GetControlNumberStatus;

-- Event Store
USE EDI_EventStore;
SELECT * FROM vw_BatchProcessingSummary;
SELECT * FROM vw_ActiveEnrollments;
SELECT * FROM vw_EventTypeStatistics;
```

### Performance Tests

```sql
-- Control Numbers: Concurrent access
-- Run in 10 parallel sessions:
DECLARE @Next BIGINT;
EXEC usp_GetNextControlNumber 'PARTNERA', '271', 'ISA', NEWID(), @Next OUTPUT;
SELECT @Next;

-- Event Store: Write throughput
-- Run 1000 times:
DECLARE @EventID BIGINT, @Seq BIGINT;
EXEC usp_AppendEvent 
    @TransactionBatchID = 1,
    @AggregateType = 'Member',
    @AggregateID = CAST(NEWID() AS VARCHAR(100)),
    @EventType = 'MemberAdded',
    @EventData = N'{"test":true}',
    @CorrelationID = NEWID(),
    @EventID = @EventID OUTPUT,
    @EventSequence = @Seq OUTPUT;
```

## Monitoring

### Key Queries

**Control Numbers:**
```sql
-- Check for high utilization
SELECT * FROM dbo.ControlNumberCounters 
WHERE CAST(CurrentValue AS FLOAT) / MaxValue > 0.80;

-- Detect gaps
EXEC usp_DetectControlNumberGaps @DaysToCheck = 7;

-- Retry rate (should be <5%)
SELECT 
    PartnerCode, 
    AVG(RetryCount) AS AvgRetries,
    COUNT(*) AS Total
FROM dbo.ControlNumberAudit
WHERE IssuedUtc >= DATEADD(HOUR, -1, SYSUTCDATETIME())
GROUP BY PartnerCode;
```

**Event Store:**
```sql
-- Check projection lag
SELECT * FROM vw_ProjectionLag WHERE SequenceLag > 100;

-- Failed batches
SELECT * FROM vw_BatchProcessingSummary WHERE ProcessingStatus = 'FAILED';

-- Event throughput
SELECT 
    CAST(EventTimestamp AS DATE) AS EventDate,
    COUNT(*) AS EventCount
FROM dbo.DomainEvent
WHERE EventTimestamp >= DATEADD(DAY, -7, SYSUTCDATETIME())
GROUP BY CAST(EventTimestamp AS DATE)
ORDER BY EventDate DESC;
```

## Documentation

**Complete Guide:** [26-sql-database-projects-complete-guide.md](../../implementation-plan/26-sql-database-projects-complete-guide.md)

**Contents:**
- Detailed schema documentation
- Stored procedure reference
- Performance tuning guide
- Deployment automation
- Testing strategy
- Troubleshooting

**Related Specs:**
- [08-transaction-routing-outbound-spec.md](../../docs/08-transaction-routing-outbound-spec.md) - Control number design
- [11-event-sourcing-architecture-spec.md](../../docs/11-event-sourcing-architecture-spec.md) - Event sourcing patterns

## Troubleshooting

**Control Numbers:**
- High retry rate → Increase backoff delay or separate counters
- Gaps detected → Check `ControlNumberAudit` for failed transactions
- Max value approaching → Plan rollover procedure

**Event Store:**
- Projection lag → Run `usp_ReplayEvents` to rebuild
- Sequence gaps → Should never happen (SQL SEQUENCE guarantees)
- High write latency → Increase `EventSequence` cache size

## Support

**Issues:** Open GitHub issue with label `database` and `phase-3`  
**Owner:** EDI Platform Team  
**Last Updated:** October 5, 2025
