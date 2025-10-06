# SFTP Tracking Database - EF Core Migration Project

**Date:** October 6, 2025  
**Repository:** https://github.com/PointCHealth/edi-database-sftptracking  
**Status:** ✅ Complete - Initial migration generated  
**Commit:** 1db63fb

---

## Overview

Created Entity Framework Core 9.0 migration project for the **EDISftpTracking** database, which tracks all file transfers for the edi-sftp-connector function app. This replaces the standalone SQL script approach with a modern, version-controlled migration strategy.

## Repository Structure

```
edi-database-sftptracking/
├── README.md (comprehensive guide)
├── .gitignore
└── EDI.SftpTracking.Migrations/
    ├── EDI.SftpTracking.Migrations.csproj (.NET 9.0)
    ├── SftpTrackingDbContext.cs
    ├── Entities/
    │   └── FileTracking.cs
    └── Migrations/
        ├── 20251006132201_InitialCreate.cs
        ├── 20251006132201_InitialCreate.Designer.cs
        └── SftpTrackingDbContextModelSnapshot.cs
```

## Database Schema

### FileTracking Table

**Purpose:** Tracks all SFTP file operations (inbound downloads and outbound uploads)

**Columns:**

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `Id` | INT IDENTITY | No | Primary key |
| `PartnerCode` | NVARCHAR(50) | No | Trading partner identifier |
| `FileName` | NVARCHAR(500) | No | Original file name |
| `FileHash` | NVARCHAR(100) | No | SHA256 hash for duplicate detection |
| `FileSize` | BIGINT | No | File size in bytes |
| `Direction` | NVARCHAR(20) | No | "Inbound" or "Outbound" |
| `Status` | NVARCHAR(20) | No | "Downloaded", "Uploaded", "Failed" |
| `ProcessedAt` | DATETIME2 | No | UTC timestamp of operation |
| `BlobUrl` | NVARCHAR(1000) | Yes | Azure Blob Storage URL |
| `ErrorMessage` | NVARCHAR(MAX) | Yes | Error details if failed |
| `CorrelationId` | NVARCHAR(100) | Yes | Links to Service Bus messages |

### Indexes

1. **IX_FileTracking_PartnerCode_FileName_Direction_Status**
   - Purpose: Idempotency checks (prevent duplicate downloads/uploads)
   - Columns: PartnerCode, FileName, Direction, Status
   - Includes: ProcessedAt
   - Type: Nonclustered

2. **IX_FileTracking_ProcessedAt**
   - Purpose: Date range queries and reporting
   - Columns: ProcessedAt (descending)
   - Includes: PartnerCode, FileName, Direction, Status
   - Type: Nonclustered

3. **IX_FileTracking_CorrelationId**
   - Purpose: Message correlation tracking
   - Columns: CorrelationId
   - Filter: [CorrelationId] IS NOT NULL
   - Type: Nonclustered, filtered

## Key Features

### Idempotency Support

The composite index on `(PartnerCode, FileName, Direction, Status)` enables fast lookups to prevent:
- Re-downloading files that were already processed
- Re-uploading files that were already sent
- Duplicate processing of the same file

**Usage Example:**
```sql
SELECT COUNT(*) 
FROM FileTracking 
WHERE PartnerCode = 'PARTNERA' 
  AND FileName = 'claims_20251006.x12' 
  AND Direction = 'Inbound' 
  AND Status = 'Downloaded';
```

### Correlation Tracking

The `CorrelationId` field links file operations to:
- Service Bus messages
- Application Insights distributed traces
- End-to-end transaction flows

**Usage Example:**
```sql
SELECT * 
FROM FileTracking 
WHERE CorrelationId = 'abc123-guid-here' 
ORDER BY ProcessedAt;
```

### Error Tracking

Failed operations are captured with:
- Status = "Failed"
- ErrorMessage containing exception details
- Timestamp for troubleshooting

**Usage Example:**
```sql
SELECT PartnerCode, FileName, ErrorMessage, ProcessedAt
FROM FileTracking 
WHERE Status = 'Failed' 
  AND ProcessedAt > DATEADD(day, -7, GETUTCDATE());
```

## Deployment

### Local Development (LocalDB)

```powershell
cd EDI.SftpTracking.Migrations
dotnet ef database update --connection "Server=(localdb)\mssqllocaldb;Database=EDISftpTracking;Trusted_Connection=True;TrustServerCertificate=True;"
```

### Azure SQL Dev Environment

```powershell
$connectionString = "Server=sql-edi-dev-eastus2.database.windows.net;Database=EDISftpTracking;User Id=sqladmin;Password=$env:SQL_PASSWORD;Encrypt=True;"
dotnet ef database update --connection $connectionString
```

### Generate Idempotent SQL Script

```powershell
dotnet ef migrations script --idempotent --output ../scripts/EDISftpTracking_Migration.sql
```

## Integration with edi-sftp-connector

### Connection String Configuration

**appsettings.json:**
```json
{
  "ConnectionStrings": {
    "SftpTrackingDatabase": "Server=sql-edi-dev-eastus2.database.windows.net;Database=EDISftpTracking;Authentication=Active Directory Default;Encrypt=True;"
  }
}
```

**Azure Function App Configuration:**
```bash
az functionapp config appsettings set \
  --name func-edi-sftp-dev-eastus2 \
  --resource-group rg-edi-dev-eastus2 \
  --settings "SftpTrackingDatabase=Server=sql-edi-dev-eastus2.database.windows.net;Database=EDISftpTracking;Authentication=Active Directory Default;Encrypt=True;"
```

### TrackingService Usage

The SFTP Connector's `TrackingService` uses this database:

```csharp
// Record inbound file download
await _trackingService.RecordDownloadAsync(
    partnerCode: "PARTNERA",
    fileName: "claims_20251006.x12",
    fileHash: "sha256_hash_here",
    fileSize: 1024000,
    blobUrl: "https://edistoragedev.blob.core.windows.net/inbound/partnera/claims_20251006.x12",
    correlationId: context.InvocationId.ToString()
);

// Record outbound file upload
await _trackingService.RecordUploadAsync(
    partnerCode: "PARTNERB",
    fileName: "remit_271_20251006.x12",
    fileHash: "sha256_hash_here",
    fileSize: 512000,
    blobUrl: "https://edistoragedev.blob.core.windows.net/outbound/partnerb/remit_271_20251006.x12",
    correlationId: uploadRequest.CorrelationId
);
```

## Relationship to Other Databases

### EDISftpTracking vs EDI_ControlNumbers

These databases serve **different purposes** and are **independent**:

| Database | Purpose | Used By | Key Data |
|----------|---------|---------|----------|
| **EDISftpTracking** | Track file transfers | edi-sftp-connector | File operations, hashes, timestamps |
| **EDI_ControlNumbers** | Generate X12 control numbers | Outbound assembly functions | ISA/GS/ST sequences |

**Indirect Link:** Both use `PartnerCode` and can share `CorrelationId`/`OutboundFileId` for end-to-end tracing.

## Monitoring Queries

### Recent File Activity

```sql
-- Last 100 files processed
SELECT TOP 100 
    PartnerCode,
    FileName,
    Direction,
    Status,
    FileSize,
    ProcessedAt
FROM FileTracking 
ORDER BY ProcessedAt DESC;
```

### Partner Activity Summary

```sql
-- Files by partner
SELECT 
    PartnerCode,
    Direction,
    Status,
    COUNT(*) AS FileCount,
    SUM(FileSize) AS TotalBytes,
    MAX(ProcessedAt) AS LastFile
FROM FileTracking
GROUP BY PartnerCode, Direction, Status
ORDER BY PartnerCode, Direction;
```

### Failed Transfers (Last 7 Days)

```sql
SELECT 
    PartnerCode,
    FileName,
    Direction,
    ErrorMessage,
    ProcessedAt
FROM FileTracking 
WHERE Status = 'Failed' 
  AND ProcessedAt > DATEADD(day, -7, GETUTCDATE())
ORDER BY ProcessedAt DESC;
```

### Duplicate Detection Check

```sql
-- Files with same hash (potential duplicates)
SELECT 
    FileHash,
    COUNT(*) AS DuplicateCount,
    STRING_AGG(FileName, ', ') AS FileNames
FROM FileTracking
GROUP BY FileHash
HAVING COUNT(*) > 1;
```

## Performance Tuning

### Index Usage Statistics

```sql
SELECT 
    i.name AS IndexName,
    s.user_seeks + s.user_scans AS TotalReads,
    s.user_updates AS TotalWrites,
    s.last_user_seek,
    s.last_user_scan
FROM sys.dm_db_index_usage_stats s
JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE OBJECT_NAME(s.object_id) = 'FileTracking';
```

### Update Statistics

```sql
UPDATE STATISTICS [dbo].[FileTracking];
```

### Rebuild Indexes (if needed)

```sql
ALTER INDEX ALL ON [dbo].[FileTracking] REBUILD;
```

## Backup and Maintenance

### Automated Backups

Azure SQL Database provides automatic backups:
- Point-in-time restore (7-35 days)
- Long-term retention (up to 10 years)
- Geo-replication for disaster recovery

### Manual Export

```bash
az sql db export \
  --resource-group rg-edi-dev-eastus2 \
  --server sql-edi-dev-eastus2 \
  --name EDISftpTracking \
  --admin-user sqladmin \
  --admin-password $SQL_PASSWORD \
  --storage-key-type StorageAccessKey \
  --storage-key $STORAGE_KEY \
  --storage-uri "https://edistoragedev.blob.core.windows.net/backups/EDISftpTracking_$(date +%Y%m%d).bacpac"
```

## Next Steps

1. ✅ **Created:** EF Core migration project
2. ✅ **Generated:** Initial migration
3. ✅ **Published:** GitHub repository (private)
4. ⏳ **Deploy:** Apply migration to Azure SQL Dev
5. ⏳ **Configure:** Update edi-sftp-connector connection string
6. ⏳ **Test:** Verify tracking operations work end-to-end
7. ⏳ **Monitor:** Review Application Insights logs and query patterns

## Related Documentation

- **SFTP Connector:** https://github.com/PointCHealth/edi-sftp-connector
- **Partner Config Migration:** edi-sftp-connector/docs/PARTNER_CONFIG_MIGRATION_GUIDE.md
- **Refactoring Report:** SFTP_CONNECTOR_REFACTORING_REPORT.md
- **Architecture Spec:** docs/01-architecture-spec.md
- **Control Numbers DB:** https://github.com/PointCHealth/edi-database-controlnumbers

---

**Project Status:** ✅ Repository created, initial migration complete, ready for deployment  
**Repository:** https://github.com/PointCHealth/edi-database-sftptracking  
**Commit:** 1db63fb
