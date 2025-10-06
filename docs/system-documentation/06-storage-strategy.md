# Storage Strategy & Data Lake Architecture

## Overview

The Healthcare EDI Platform employs a comprehensive Azure Data Lake Storage Gen2 (ADLS Gen2) strategy with intelligent lifecycle management to optimize costs, performance, and regulatory compliance. The storage architecture supports multi-zone organization, automated tiering, and 7-10 year retention requirements while maintaining event replay capabilities and operational efficiency.

### Purpose

- Organize EDI files and metadata across distinct storage zones (landing, raw, quarantine, processed, archive)
- Implement cost-effective lifecycle policies with automated tiering (Hot → Cool → Archive)
- Maintain regulatory compliance with HIPAA 7-10 year retention requirements
- Enable event sourcing and replay capabilities for 834 enrollment transactions
- Optimize storage costs by 85-90% compared to database-only storage
- Support fast operational access for recent files (0-90 days) while archiving older data

### Key Capabilities

| Capability | Description |
|------------|-------------|
| **Multi-Zone Architecture** | Landing, raw, quarantine, metadata, outbound-staging, processed, archive zones |
| **Hierarchical Organization** | Date-based partitioning (YYYY/MM/DD) with partner/transaction type sub-folders |
| **Automated Lifecycle Management** | Policy-based tiering: Hot (0-90d) → Cool (90d-2y) → Archive (2y-10y) → Purge (10y+) |
| **Hybrid Storage Model** | Blob Storage for files, Azure SQL for metadata and references |
| **Event Sourcing Support** | Immutable raw file storage with hash-based idempotency |
| **Cost Optimization** | 85-90% storage cost reduction vs. database-only approach |
| **Regulatory Compliance** | HIPAA-compliant retention, audit logging, encryption at rest and in transit |

---

## Architecture

### Storage Account Design

```text
┌─────────────────────────────────────────────────────────────────────┐
│                     Azure Storage Account                            │
│                     edistg{env}{region}01                            │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Type: StorageV2 (General Purpose v2)                         │  │
│  │  SKU: Standard_GRS (Prod), Standard_LRS (Dev/Test)            │  │
│  │  Features: Hierarchical Namespace (ADLS Gen2), Versioning,    │  │
│  │            Soft Delete (30d), Change Feed, Lifecycle Mgmt     │  │
│  │  Access: Private Endpoints + VNet Integration (no public)     │  │
│  │  Encryption: Microsoft-managed keys (or CMK via Key Vault)    │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    Blob Containers (Zones)                     │  │
│  ├───────────────────────────────────────────────────────────────┤  │
│  │  1. landing/          - SFTP upload ingestion zone            │  │
│  │  2. raw/              - Validated original EDI files          │  │
│  │  3. quarantine/       - Failed validation files               │  │
│  │  4. metadata/         - Ingestion metadata JSON               │  │
│  │  5. outbound-staging/ - Mapper transformed outputs            │  │
│  │  6. processed/        - Successfully routed files             │  │
│  │  7. archive/          - Long-term compliance storage          │  │
│  │  8. config/           - Partner configs, mapping rules        │  │
│  │  9. inbound-responses/- Partner response files                │  │
│  │  10. orphaned-responses/ - Unmatched correlation responses    │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Storage Zones & Data Flow

```text
┌──────────────────────────────────────────────────────────────────────┐
│                         DATA FLOW THROUGH ZONES                       │
└──────────────────────────────────────────────────────────────────────┘

   INBOUND FLOW (Partner → Platform)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   ┌─────────────┐        ┌─────────────┐        ┌─────────────┐
   │  1. landing/│───────▶│  2. raw/    │───────▶│ 6. processed│
   │  SFTP Drop  │ ADF    │  Validated  │ Router │  Routed     │
   │  Hot tier   │ Pipeline│  Hot tier  │ Function│  Cool tier  │
   └─────────────┘        └──────┬──────┘        └─────────────┘
         │                       │                       │
         │ Validation            │                       │
         │ Failure               │                       │
         │                       │                       │
         ▼                       ▼                       ▼
   ┌─────────────┐        ┌─────────────┐        ┌─────────────┐
   │3. quarantine│        │4. metadata/ │        │ 7. archive/ │
   │  Invalid    │        │  JSON logs  │        │  10+ years  │
   │  90d delete │        │  Hot tier   │        │  Archive    │
   └─────────────┘        └─────────────┘        └─────────────┘


   OUTBOUND FLOW (Platform → Partner)
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   ┌─────────────┐        ┌─────────────┐        ┌─────────────┐
   │ raw/ (X12)  │───────▶│ 5. outbound-│───────▶│  Connector  │
   │             │ Mapper │    staging/ │ SFTP/  │  Delivery   │
   │             │ Function│  Transformed│ API    │  to Partner │
   └─────────────┘        └─────────────┘        └─────────────┘
                                 │
                                 │ Partner sends response
                                 ▼
                          ┌─────────────┐        ┌─────────────┐
                          │ 9. inbound- │───────▶│ Outbound    │
                          │   responses/│ Mapper │ Orchestrator│
                          │  Partner XML│        │ X12 Gen     │
                          └─────────────┘        └─────────────┘
```

---

## Container Structure

### 1. Landing Zone

**Container**: `landing`  
**Purpose**: Initial SFTP upload destination for partner files  
**Tier**: Hot  
**Retention**: Delete after 7 days (files moved to raw or quarantine)

**Path Structure**:
```text
landing/
├── {partner-code}/
│   └── {YYYY}/{MM}/{DD}/
│       ├── {partner-code}-{timestamp}-{filename}.edi
│       ├── {partner-code}-{timestamp}-{filename}.edi
│       └── ...
```

**Example**:
```text
landing/
├── PARTNERA/
│   └── 2025/10/06/
│       ├── PARTNERA-20251006T083015Z-834-batch001.edi
│       └── PARTNERA-20251006T091234Z-837-claims-daily.edi
```

**Lifecycle Policy**:
```json
{
  "name": "DeleteLandingAfter7Days",
  "enabled": true,
  "type": "Lifecycle",
  "definition": {
    "actions": {
      "baseBlob": {
        "delete": {
          "daysAfterModificationGreaterThan": 7
        }
      }
    },
    "filters": {
      "blobTypes": ["blockBlob"],
      "prefixMatch": ["landing/"]
    }
  }
}
```

### 2. Raw Zone

**Container**: `raw`  
**Purpose**: Validated original EDI files (source of truth for event sourcing)  
**Tier**: Hot (0-90d) → Cool (90d-2y) → Archive (2y-10y)  
**Retention**: 10 years (HIPAA compliance)

**Path Structure**:
```text
raw/
├── {YYYY}/{MM}/{DD}/
│   ├── {ingestion-id}_{partner-code}_{transaction-set}.edi
│   └── ...
```

**Example**:
```text
raw/
├── 2025/10/06/
│   ├── 550e8400-e29b-41d4-a716-446655440000_PARTNERA_834.edi
│   ├── 660f9511-f30c-52e5-b827-557766551111_PARTNERB_837.edi
│   └── ...
```

**Blob Metadata** (attached to each file):
```json
{
  "ingestionId": "550e8400-e29b-41d4-a716-446655440000",
  "partnerCode": "PARTNERA",
  "transactionSet": "834",
  "originalFileName": "PARTNERA-20251006T083015Z-834-batch001.edi",
  "receivedUtc": "2025-10-06T08:30:15Z",
  "checksumSha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "fileSize": "524288",
  "interchangeControl": "000125159",
  "groupControl": "000125159",
  "validationStatus": "PASSED"
}
```

**Lifecycle Policy**:
```json
{
  "name": "TierRawFiles",
  "enabled": true,
  "type": "Lifecycle",
  "definition": {
    "actions": {
      "baseBlob": {
        "tierToCool": {
          "daysAfterModificationGreaterThan": 90
        },
        "tierToArchive": {
          "daysAfterModificationGreaterThan": 730
        },
        "delete": {
          "daysAfterModificationGreaterThan": 3650
        }
      }
    },
    "filters": {
      "blobTypes": ["blockBlob"],
      "prefixMatch": ["raw/"]
    }
  }
}
```

### 3. Quarantine Zone

**Container**: `quarantine`  
**Purpose**: Files that failed validation (naming, authorization, checksum, virus, structural)  
**Tier**: Hot  
**Retention**: 90 days then delete

**Path Structure**:
```text
quarantine/
├── {YYYY}/{MM}/{DD}/
│   ├── {reason}/
│   │   ├── {filename}_quarantine-{timestamp}.edi
│   │   └── {filename}_quarantine-{timestamp}.edi.json (metadata)
```

**Example**:
```text
quarantine/
├── 2025/10/06/
│   ├── naming-violation/
│   │   ├── badfile_quarantine-20251006T083015Z.edi
│   │   └── badfile_quarantine-20251006T083015Z.edi.json
│   ├── unauthorized-partner/
│   │   ├── UNKNOWN-partner_quarantine-20251006T091234Z.edi
│   │   └── UNKNOWN-partner_quarantine-20251006T091234Z.edi.json
│   ├── checksum-mismatch/
│   ├── virus-detected/
│   └── structural-invalid/
```

**Quarantine Metadata JSON**:
```json
{
  "quarantineId": "770e8400-e29b-41d4-a716-446655440000",
  "quarantineReason": "NAMING_VIOLATION",
  "quarantineTimestamp": "2025-10-06T08:30:15Z",
  "originalFileName": "badfile.edi",
  "originalBlobPath": "landing/PARTNERA/2025/10/06/badfile.edi",
  "validationErrors": [
    {
      "rule": "FileNamingConvention",
      "expected": "{partner-code}-{timestamp}-{transaction-set}-{identifier}.edi",
      "actual": "badfile.edi",
      "severity": "ERROR"
    }
  ],
  "fileSize": 12345,
  "checksumSha256": "abc123...",
  "remediationGuidance": "Rename file to match naming convention and re-upload"
}
```

**Lifecycle Policy**:
```json
{
  "name": "DeleteQuarantineAfter90Days",
  "enabled": true,
  "type": "Lifecycle",
  "definition": {
    "actions": {
      "baseBlob": {
        "delete": {
          "daysAfterModificationGreaterThan": 90
        }
      }
    },
    "filters": {
      "blobTypes": ["blockBlob"],
      "prefixMatch": ["quarantine/"]
    }
  }
}
```

### 4. Metadata Zone

**Container**: `metadata`  
**Purpose**: Structured ingestion metadata (JSON) for each processed file  
**Tier**: Hot (0-90d) → Cool (90d-2y)  
**Retention**: 2 years

**Path Structure**:
```text
metadata/
├── {YYYY}/{MM}/{DD}/
│   ├── {ingestion-id}.json
│   └── ...
```

**Metadata JSON Schema**:
```json
{
  "ingestionId": "550e8400-e29b-41d4-a716-446655440000",
  "partnerCode": "PARTNERA",
  "transactionSet": "834",
  "fileName": "PARTNERA-20251006T083015Z-834-batch001.edi",
  "receivedUtc": "2025-10-06T08:30:15Z",
  "fileSize": 524288,
  "checksumSha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "rawBlobPath": "raw/2025/10/06/550e8400-e29b-41d4-a716-446655440000_PARTNERA_834.edi",
  "validationResults": {
    "namingConvention": "PASSED",
    "partnerAuthorization": "PASSED",
    "checksumVerification": "PASSED",
    "virusScan": "PASSED",
    "structuralPeek": "PASSED"
  },
  "x12Envelope": {
    "interchangeControl": "000125159",
    "groupControl": "000125159",
    "senderQualifier": "ZZ",
    "senderId": "SENDERID",
    "receiverQualifier": "ZZ",
    "receiverId": "RECEIVERID",
    "standardVersion": "00501",
    "usageIndicator": "P",
    "transactionSetCount": 1
  },
  "processingStatus": "COMPLETED",
  "routingTimestamp": "2025-10-06T08:31:00Z"
}
```

### 5. Outbound Staging Zone

**Container**: `outbound-staging`  
**Purpose**: Transformed partner-specific outputs from mapper functions  
**Tier**: Hot  
**Retention**: 30 days

**Path Structure**:
```text
outbound-staging/
├── {partner-id}/
│   ├── pending/
│   │   ├── {routing-id}.xml
│   │   └── {routing-id}.json
│   ├── delivered/
│   │   └── {routing-id}.xml
│   └── errors/
│       └── {routing-id}_error.xml
```

**Example**:
```text
outbound-staging/
├── partner-a/
│   ├── pending/
│   │   ├── 550e8400-e29b-41d4-a716-446655440000.xml
│   │   └── 660f9511-f30c-52e5-b827-557766551111.xml
│   ├── delivered/
│   │   └── 440e7300-d18a-31c4-9605-335544330000.xml
│   └── errors/
│       └── 770e8400-e29b-41d4-a716-446655440000_error.xml
```

### 6. Processed Zone

**Container**: `processed`  
**Purpose**: Successfully routed and delivered files  
**Tier**: Cool (immediate) → Archive (180d)  
**Retention**: 7 years

**Path Structure**:
```text
processed/
├── {YYYY}/{MM}/{DD}/
│   ├── {partner-code}/
│   │   ├── {transaction-set}/
│   │   │   ├── {routing-id}.edi
│   │   │   └── ...
```

### 7. Archive Zone

**Container**: `archive`  
**Purpose**: Long-term compliance storage (cold archive)  
**Tier**: Archive  
**Retention**: 10 years

**Path Structure**:
```text
archive/
├── {YYYY}/
│   ├── {MM}/
│   │   ├── archive-{YYYY-MM}.tar.gz
│   │   └── archive-{YYYY-MM}-manifest.json
```

### 8. Configuration Zone

**Container**: `config`  
**Purpose**: Partner configurations, mapping rules, schemas  
**Tier**: Hot (frequently accessed)  
**Retention**: Permanent (versioned)

**Path Structure**:
```text
config/
├── partners/
│   ├── partner-a.json
│   ├── partner-b.json
│   └── ...
├── mappers/
│   ├── claim-systems/
│   │   ├── claim-system-a/
│   │   │   ├── 837-to-xml-v1.json
│   │   │   ├── 271-from-json-v1.json
│   │   │   └── validation-schema.xsd
│   └── trading-partners/
│       ├── partner-a/
│       │   ├── 837-outbound-customization.json
│       │   └── ...
├── schemas/
│   ├── partners.schema.json
│   ├── routing.schema.json
│   └── canonical-response-v1.json
└── routing/
    ├── routing-rules.json
    └── subscription-filters.json
```

### 9. Inbound Responses Zone

**Container**: `inbound-responses`  
**Purpose**: Partner response files (271, 277, 835, 999)  
**Tier**: Hot  
**Retention**: 30 days in raw, 90 days in processed

**Path Structure**:
```text
inbound-responses/
├── {partner-id}/
│   ├── raw/
│   │   ├── {timestamp}_{response-type}.xml
│   │   └── ...
│   ├── processed/
│   │   └── {timestamp}_{response-type}.xml
│   └── errors/
│       └── {timestamp}_{response-type}_error.xml
```

### 10. Orphaned Responses Zone

**Container**: `orphaned-responses`  
**Purpose**: Responses that cannot be correlated to original routingId  
**Tier**: Hot  
**Retention**: 90 days (manual investigation required)

**Path Structure**:
```text
orphaned-responses/
├── {partner-id}/
│   └── {YYYY}/{MM}/{DD}/
│       ├── {partner-correlation-id}.json
│       └── ...
```

---

## Lifecycle Management

### Automated Tiering Strategy

```text
┌─────────────────────────────────────────────────────────────────┐
│                     FILE LIFECYCLE MANAGEMENT                    │
├─────────────┬──────────────┬─────────────┬──────────────────────┤
│   Age       │  Storage     │  Tier       │  Use Case            │
├─────────────┼──────────────┼─────────────┼──────────────────────┤
│ 0-90 days   │ Blob Storage │ Hot         │ Operational replay   │
│             │              │             │ Issue investigation  │
│             │              │  $0.018/GB  │ Recent reversals     │
├─────────────┼──────────────┼─────────────┼──────────────────────┤
│ 90d-2 years │ Blob Storage │ Cool        │ Audit requests       │
│             │              │             │ Historical analysis  │
│             │              │  $0.010/GB  │ Compliance queries   │
├─────────────┼──────────────┼─────────────┼──────────────────────┤
│ 2-10 years  │ Blob Storage │ Archive     │ Legal compliance     │
│             │              │             │ Regulatory retention │
│             │              │  $0.002/GB  │ Rare replay scenarios│
├─────────────┼──────────────┼─────────────┼──────────────────────┤
│ 10+ years   │ Purged       │ N/A         │ End of lifecycle     │
│             │              │  Deleted    │ Policy-compliant     │
└─────────────┴──────────────┴─────────────┴──────────────────────┘
```

### Cost Comparison

| Storage Type | Cost/GB/Month | 1TB/Month | 10TB/Month | 100TB Over 5 Years |
|--------------|---------------|-----------|------------|---------------------|
| Azure SQL Database | $0.12 | $120 | $1,200 | $72,000 |
| Blob Hot | $0.018 | $18 | $180 | $10,800 |
| Blob Cool | $0.01 | $10 | $100 | $6,000 |
| Blob Archive | $0.002 | $2 | $20 | $1,200 |
| **Hybrid (Recommended)** | **Variable** | **~$12** | **~$120** | **~$7,200** |

**Projected Savings**: 85-90% reduction in storage costs compared to database-only approach

### Bicep Lifecycle Policy Configuration

```bicep
// Complete lifecycle policy with all storage zones
resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        // Rule 1: Tier raw files (Hot → Cool → Archive → Delete)
        {
          enabled: true
          name: 'TierRawFiles'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: 90
                }
                tierToArchive: {
                  daysAfterModificationGreaterThan: 730  // 2 years
                }
                delete: {
                  daysAfterModificationGreaterThan: 3650  // 10 years
                }
              }
              snapshot: {
                delete: {
                  daysAfterCreationGreaterThan: 90
                }
              }
            }
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['raw/']
            }
          }
        }
        // Rule 2: Delete landing after 7 days
        {
          enabled: true
          name: 'DeleteLandingAfter7Days'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: 7
                }
              }
            }
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['landing/']
            }
          }
        }
        // Rule 3: Delete quarantine after 90 days
        {
          enabled: true
          name: 'DeleteQuarantineAfter90Days'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: 90
                }
              }
            }
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['quarantine/']
            }
          }
        }
        // Rule 4: Tier metadata to Cool after 90 days, delete after 2 years
        {
          enabled: true
          name: 'TierMetadata'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: 90
                }
                delete: {
                  daysAfterModificationGreaterThan: 730
                }
              }
            }
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['metadata/']
            }
          }
        }
        // Rule 5: Delete outbound-staging after 30 days
        {
          enabled: true
          name: 'DeleteOutboundStagingAfter30Days'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: 30
                }
              }
            }
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['outbound-staging/']
            }
          }
        }
        // Rule 6: Tier processed files immediately to Cool, archive after 180 days
        {
          enabled: true
          name: 'TierProcessedFiles'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: 0  // Immediate
                }
                tierToArchive: {
                  daysAfterModificationGreaterThan: 180
                }
                delete: {
                  daysAfterModificationGreaterThan: 2555  // 7 years
                }
              }
            }
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['processed/']
            }
          }
        }
        // Rule 7: Tier inbound-responses to Cool after 30 days, delete after 90 days
        {
          enabled: true
          name: 'TierInboundResponses'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: 30
                }
                delete: {
                  daysAfterModificationGreaterThan: 90
                }
              }
            }
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['inbound-responses/']
            }
          }
        }
        // Rule 8: Delete orphaned-responses after 90 days
        {
          enabled: true
          name: 'DeleteOrphanedResponsesAfter90Days'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: 90
                }
              }
            }
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['orphaned-responses/']
            }
          }
        }
      ]
    }
  }
}
```

---

## Hybrid Storage Model

### Database + Blob Storage Integration

The platform uses a **hybrid approach** where Azure SQL Database stores metadata and references, while Blob Storage holds the actual file content.

#### Database Schema (TransactionBatch Table)

```sql
CREATE TABLE [dbo].[TransactionBatch] (
    [TransactionBatchID] BIGINT IDENTITY(1,1) PRIMARY KEY,
    [BatchGUID] UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    [InterchangeControlNumber] VARCHAR(9) NOT NULL,
    [GroupControlNumber] VARCHAR(9) NOT NULL,
    [SenderID] VARCHAR(15) NOT NULL,
    [ReceiverID] VARCHAR(15) NOT NULL,
    [StandardVersion] VARCHAR(12) NOT NULL,
    [UsageIndicator] CHAR(1) NOT NULL,
    [FileName] VARCHAR(255) NULL,
    [FileReceivedDate] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    [FileHash] VARCHAR(64) NULL, -- SHA256 for idempotency
    [FileSize] BIGINT NULL,
    
    -- External Blob Storage References
    [BlobStorageAccount] VARCHAR(100) NULL,
    [BlobContainerName] VARCHAR(100) NULL,
    [BlobFileName] VARCHAR(500) NULL,
    [BlobFullUri] VARCHAR(1000) NULL,
    [BlobStorageTier] VARCHAR(20) NULL, -- Hot, Cool, Archive
    [BlobETag] VARCHAR(100) NULL,
    [BlobLastModified] DATETIME2 NULL,
    
    -- Lifecycle Management
    [RetentionStatus] VARCHAR(20) DEFAULT 'Active',
    [TierTransitionDate] DATETIME2 NULL,
    [PurgeEligibleDate] DATE NULL,
    [ArchivedDate] DATETIME2 NULL,
    [PurgedDate] DATETIME2 NULL,
    
    [CreatedDate] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    [ModifiedDate] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    
    INDEX IX_TransactionBatch_Hash NONCLUSTERED ([FileHash]),
    INDEX IX_TransactionBatch_BlobUri NONCLUSTERED ([BlobFullUri]),
    INDEX IX_TransactionBatch_RetentionStatus NONCLUSTERED ([RetentionStatus], [PurgeEligibleDate]),
    INDEX IX_TransactionBatch_StorageTier NONCLUSTERED ([BlobStorageTier], [TierTransitionDate])
);

-- Unique index for idempotency checks
CREATE UNIQUE INDEX UX_TransactionBatch_FileHash 
ON [dbo].[TransactionBatch] ([FileHash]) 
WHERE [FileHash] IS NOT NULL;
```

#### File Upload Service (C# Azure Function)

```csharp
public class BlobFileStorageService
{
    private readonly BlobServiceClient _blobServiceClient;
    private readonly ILogger _logger;
    
    public async Task<BlobStorageReference> UploadTransactionFile(
        Stream fileStream, 
        string fileName, 
        string partnerCode,
        string transactionSet,
        Guid ingestionId,
        DateTime receivedDate)
    {
        // Generate blob path: YYYY/MM/DD/{ingestionId}_{partner}_{txn}.edi
        string blobPath = $"{receivedDate:yyyy/MM/dd}/{ingestionId}_{partnerCode}_{transactionSet}.edi";
        
        BlobContainerClient container = _blobServiceClient.GetBlobContainerClient("raw");
        BlobClient blobClient = container.GetBlobClient(blobPath);
        
        // Metadata attached to blob
        var metadata = new Dictionary<string, string>
        {
            { "ingestionId", ingestionId.ToString() },
            { "partnerCode", partnerCode },
            { "transactionSet", transactionSet },
            { "originalFileName", fileName },
            { "receivedUtc", receivedDate.ToString("o") },
            { "uploadedBy", "EDI-Ingestion-Pipeline" }
        };
        
        // Calculate SHA256 hash for idempotency
        fileStream.Position = 0;
        string fileHash = await ComputeSHA256Hash(fileStream);
        fileStream.Position = 0;
        
        // Upload with Hot tier (lifecycle policy will tier automatically)
        await blobClient.UploadAsync(fileStream, new BlobUploadOptions
        {
            Metadata = metadata,
            AccessTier = AccessTier.Hot,
            HttpHeaders = new BlobHttpHeaders
            {
                ContentType = "application/edi-x12"
            },
            Tags = new Dictionary<string, string>
            {
                { "ingestionId", ingestionId.ToString() },
                { "partnerCode", partnerCode },
                { "transactionSet", transactionSet }
            }
        });
        
        var properties = await blobClient.GetPropertiesAsync();
        
        return new BlobStorageReference
        {
            BlobStorageAccount = _blobServiceClient.AccountName,
            BlobContainerName = "raw",
            BlobFileName = blobPath,
            BlobFullUri = blobClient.Uri.ToString(),
            BlobETag = properties.Value.ETag.ToString(),
            BlobLastModified = properties.Value.LastModified.DateTime,
            FileHash = fileHash,
            FileSize = fileStream.Length,
            BlobStorageTier = "Hot"
        };
    }
    
    public async Task<Stream> DownloadTransactionFile(string blobUri)
    {
        BlobClient blobClient = new BlobClient(new Uri(blobUri));
        
        // Check if blob is in Archive tier (requires rehydration)
        BlobProperties properties = await blobClient.GetPropertiesAsync();
        
        if (properties.AccessTier == AccessTier.Archive)
        {
            // Check rehydration status
            if (properties.ArchiveStatus == "rehydrate-pending-to-hot" || 
                properties.ArchiveStatus == "rehydrate-pending-to-cool")
            {
                throw new BlobArchivedException(
                    $"File is rehydrating. Status: {properties.ArchiveStatus}. Retry later.");
            }
            
            // Initiate rehydration (takes 1-15 hours for standard, < 1 hour for priority)
            await blobClient.SetAccessTierAsync(
                AccessTier.Hot, 
                rehydratePriority: RehydratePriority.Standard);
            
            throw new BlobArchivedException(
                "File is in Archive tier. Rehydration initiated. Retry in 1-15 hours.");
        }
        
        return await blobClient.OpenReadAsync();
    }
    
    private async Task<string> ComputeSHA256Hash(Stream stream)
    {
        using var sha256 = SHA256.Create();
        byte[] hash = await sha256.ComputeHashAsync(stream);
        return BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
    }
}
```

---

## Operations

### Monitoring Queries (KQL)

#### 1. Storage Tier Distribution

```kusto
// Monitor distribution across storage tiers
StorageAccountLogs
| where TimeGenerated > ago(24h)
| where OperationName == "GetBlobProperties"
| extend Tier = tostring(parse_json(ResponseBody).properties.accessTier)
| summarize Count = count() by Tier, bin(TimeGenerated, 1h)
| render timechart
```

#### 2. Storage Cost Trend

```kusto
// Estimate monthly storage costs by tier
let costPerGBPerMonth = dynamic({
    "Hot": 0.018,
    "Cool": 0.010,
    "Archive": 0.002
});
TransactionBatchTable
| summarize 
    HotGB = sumif(FileSize, BlobStorageTier == "Hot") / 1024.0 / 1024.0 / 1024.0,
    CoolGB = sumif(FileSize, BlobStorageTier == "Cool") / 1024.0 / 1024.0 / 1024.0,
    ArchiveGB = sumif(FileSize, BlobStorageTier == "Archive") / 1024.0 / 1024.0 / 1024.0
| extend 
    HotCost = HotGB * costPerGBPerMonth.Hot,
    CoolCost = CoolGB * costPerGBPerMonth.Cool,
    ArchiveCost = ArchiveGB * costPerGBPerMonth.Archive,
    TotalCost = HotCost + CoolCost + ArchiveCost
| project HotGB, CoolGB, ArchiveGB, HotCost, CoolCost, ArchiveCost, TotalCost
```

#### 3. Lifecycle Policy Effectiveness

```kusto
// Verify files are tiering correctly
TransactionBatchTable
| where TimeGenerated > ago(7d)
| extend 
    AgeDays = datetime_diff('day', now(), FileReceivedDate),
    ExpectedTier = case(
        AgeDays <= 90, "Hot",
        AgeDays <= 730, "Cool",
        "Archive"
    )
| summarize 
    Correct = countif(BlobStorageTier == ExpectedTier),
    Incorrect = countif(BlobStorageTier != ExpectedTier),
    Total = count()
    by ExpectedTier
| extend ComplianceRate = round(100.0 * Correct / Total, 2)
```

#### 4. Quarantine Rate by Reason

```kusto
// Monitor quarantine trends
QuarantineLog_CL
| where TimeGenerated > ago(7d)
| extend Reason = tostring(customDimensions.quarantineReason)
| summarize Count = count() by Reason, bin(TimeGenerated, 1d)
| render columnchart
```

#### 5. Archive Rehydration Requests

```kusto
// Track archive rehydration operations
StorageAccountLogs
| where OperationName == "SetBlobTier"
| where ResponseBody contains "rehydrate"
| extend 
    BlobUri = tostring(Uri),
    Priority = tostring(parse_json(RequestBody).rehydratePriority)
| summarize 
    RehydrationCount = count(),
    AvgDurationHours = avg(DurationMs) / 1000.0 / 3600.0
    by Priority, bin(TimeGenerated, 1d)
| render timechart
```

#### 6. Storage Health Dashboard

```kusto
// Comprehensive storage health metrics
let storageMetrics = TransactionBatchTable
| summarize 
    TotalFiles = count(),
    TotalSizeGB = sum(FileSize) / 1024.0 / 1024.0 / 1024.0,
    HotFiles = countif(BlobStorageTier == "Hot"),
    CoolFiles = countif(BlobStorageTier == "Cool"),
    ArchiveFiles = countif(BlobStorageTier == "Archive"),
    AvgFileSizeMB = avg(FileSize) / 1024.0 / 1024.0
| extend 
    HotPercent = round(100.0 * HotFiles / TotalFiles, 1),
    CoolPercent = round(100.0 * CoolFiles / TotalFiles, 1),
    ArchivePercent = round(100.0 * ArchiveFiles / TotalFiles, 1);
storageMetrics
```

#### 7. Blob Access Patterns

```kusto
// Analyze blob read operations by tier
StorageAccountLogs
| where OperationName == "GetBlob"
| extend Tier = tostring(parse_json(properties).accessTier)
| summarize 
    ReadCount = count(),
    AvgLatencyMs = avg(DurationMs),
    P95LatencyMs = percentile(DurationMs, 95)
    by Tier, bin(TimeGenerated, 1h)
| render timechart
```

#### 8. Missing Blob References (Data Integrity)

```kusto
// Alert on database records without blob references
TransactionBatchTable
| where isempty(BlobFullUri) or BlobFullUri == ""
| summarize MissingCount = count() by bin(FileReceivedDate, 1d)
| where MissingCount > 0
| render timechart
```

### Troubleshooting Scenarios

#### Scenario 1: High Storage Costs

**Symptoms**:
- Monthly storage costs exceed budget
- Unexpected growth in Hot tier usage

**Diagnosis**:

1. Query storage distribution:
   ```kusto
   TransactionBatchTable
   | summarize Count = count(), SizeGB = sum(FileSize) / 1GB by BlobStorageTier
   ```

2. Check lifecycle policy status:
   ```powershell
   # Verify lifecycle rules are enabled
   $storageAccount = Get-AzStorageAccount -ResourceGroupName "rg-edi-prod" -Name "edistgprod01"
   $policy = Get-AzStorageAccountManagementPolicy -ResourceGroupName "rg-edi-prod" -StorageAccountName "edistgprod01"
   $policy.Rules | Format-Table Name, Enabled, @{L='CoolDays';E={$_.Definition.Actions.BaseBlob.TierToCool.DaysAfterModificationGreaterThan}}
   ```

**Resolution**:
- Verify lifecycle policies are enabled and functioning
- Manually tier files if policies failed: `Set-AzStorageBlobContent -AccessTier Cool`
- Review retention policies for unnecessary long retention

#### Scenario 2: Archive Rehydration Delays

**Symptoms**:
- Event replay requests stuck waiting for archived files
- Rehydration taking > 15 hours

**Diagnosis**:

1. Check rehydration status:
   ```powershell
   $blob = Get-AzStorageBlob -Container "raw" -Blob "2023/01/15/file.edi" -Context $ctx
   $blob.ICloudBlob.Properties.ArchiveStatus
   ```

2. Review rehydration priority:
   ```kusto
   StorageAccountLogs
   | where OperationName == "SetBlobTier"
   | where RequestBody contains "rehydrate"
   | extend Priority = tostring(parse_json(RequestBody).rehydratePriority)
   | where Priority == "Standard"  // Should be "High" for urgent requests
   ```

**Resolution**:
- Use High priority rehydration for urgent requests (< 1 hour, higher cost)
- Proactively rehydrate files before planned operations
- Consider keeping last 90 days in Cool tier instead of Archive

#### Scenario 3: Quarantine Rate Spike

**Symptoms**:
- Sudden increase in quarantined files
- Partner complaints about rejected files

**Diagnosis**:

1. Analyze quarantine reasons:
   ```kusto
   QuarantineLog_CL
   | where TimeGenerated > ago(24h)
   | summarize Count = count() by tostring(customDimensions.quarantineReason)
   | render piechart
   ```

2. Identify affected partners:
   ```kusto
   QuarantineLog_CL
   | where TimeGenerated > ago(24h)
   | extend Partner = tostring(customDimensions.partnerCode)
   | summarize Count = count() by Partner
   | order by Count desc
   ```

**Resolution**:
- Review recent partner configuration changes
- Check for naming convention changes
- Verify partner authorization list is up-to-date
- Provide remediation guidance to partner

#### Scenario 4: Missing Blob References

**Symptoms**:
- Database records exist but blob references are null
- Event replay failures due to missing files

**Diagnosis**:

1. Identify missing references:
   ```sql
   SELECT 
       TransactionBatchID,
       BatchGUID,
       FileName,
       FileReceivedDate,
       BlobFullUri
   FROM TransactionBatch
   WHERE BlobFullUri IS NULL OR BlobFullUri = ''
   ORDER BY FileReceivedDate DESC;
   ```

2. Check if blobs exist in storage:
   ```powershell
   $batches = Invoke-Sqlcmd -Query "SELECT BatchGUID, FileName FROM TransactionBatch WHERE BlobFullUri IS NULL"
   foreach ($batch in $batches) {
       # Search for blob by pattern
       $blobs = Get-AzStorageBlob -Container "raw" -Prefix "*/*/$$($batch.FileName)*" -Context $ctx
       if ($blobs) {
           Write-Host "Found blob for $($batch.BatchGUID): $($blobs[0].Name)"
       }
   }
   ```

**Resolution**:
- If blob exists: Update database reference
- If blob missing: Re-upload from backup or partner source
- Implement dual-write validation for future uploads

---

## Security

### Access Control

**RBAC Assignments** (Bicep):

```bicep
// Function App: Read raw files, write outbound-staging
resource mapperBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(functionApp.id, storageAccount.id, 'BlobDataContributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe')  // Storage Blob Data Contributor
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ADF: Read landing, write raw/quarantine/metadata
resource adfBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(dataFactory.id, storageAccount.id, 'BlobDataContributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: dataFactory.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Operations Team: Read-only for troubleshooting
resource opsTeamBlobReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('ops-team', storageAccount.id, 'BlobDataReader')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 
      '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')  // Storage Blob Data Reader
    principalId: opsTeamGroupObjectId
    principalType: 'Group'
  }
}
```

### Network Security

**Private Endpoints** (Bicep):

```bicep
// Private endpoint for blob storage
resource blobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'pe-blob-${storageAccount.name}'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'blob-connection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['blob']
        }
      }
    ]
  }
}

// Disable public access
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  properties: {
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
  }
}
```

### Encryption

| Data State | Encryption Method | Key Management |
|------------|------------------|----------------|
| **At Rest** | AES-256 (Storage Service Encryption) | Microsoft-managed keys (default) or Customer-managed keys (CMK) via Key Vault |
| **In Transit** | TLS 1.2+ (HTTPS only) | Azure-managed certificates |
| **Blob Versioning** | Same as base blob | Inherited from account settings |

### Audit Logging

**Diagnostic Settings** (Bicep):

```bicep
// Enable blob audit logging
resource blobDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: storageAccount::blobService
  name: 'blob-audit-logs'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}
```

**Audit Query** (KQL):

```kusto
// Track all blob deletions (security audit)
StorageBlobLogs
| where OperationName == "DeleteBlob"
| extend 
    User = tostring(parse_json(AuthenticationInfo).identity),
    Container = tostring(Uri),
    IPAddress = tostring(CallerIpAddress)
| project TimeGenerated, User, Container, IPAddress, StatusText
| order by TimeGenerated desc
```

---

## Disaster Recovery

### Backup Strategy

| Component | Backup Method | RPO | RTO | Retention |
|-----------|---------------|-----|-----|-----------|
| **Blob Storage (Hot/Cool)** | GRS replication | < 15 min | < 1 hour | Continuous |
| **Blob Storage (Archive)** | GRS replication | < 15 min | 1-15 hours | Continuous |
| **Soft Delete** | Point-in-time recovery | 0 | < 5 min | 30 days |
| **Blob Versioning** | Version history | 0 | < 5 min | 90 days |
| **Azure SQL Metadata** | Automated backups | 5 min | < 1 hour | 35 days |

### Recovery Scenarios

#### Scenario 1: Accidental Blob Deletion

**Recovery Steps**:

1. Check soft delete:
   ```powershell
   # List deleted blobs
   $deletedBlobs = Get-AzStorageBlob -Container "raw" -IncludeDeleted -Context $ctx | 
       Where-Object { $_.IsDeleted }
   
   # Undelete specific blob
   $deletedBlobs[0].ICloudBlob.Undelete()
   ```

2. If past soft delete retention, restore from GRS secondary:
   ```powershell
   # Failover to secondary region
   Invoke-AzStorageAccountFailover -ResourceGroupName "rg-edi-prod" -Name "edistgprod01"
   ```

#### Scenario 2: Storage Account Corruption

**Recovery Steps**:

1. Initiate GRS failover:
   ```powershell
   # Customer-initiated failover (takes ~1 hour)
   Invoke-AzStorageAccountFailover `
     -ResourceGroupName "rg-edi-prod" `
     -Name "edistgprod01" `
     -Force
   ```

2. Update application endpoints to new primary region
3. After recovery, fail back to original region (manual replication required)

#### Scenario 3: Event Replay from Archived Files

**Recovery Steps**:

1. Initiate rehydration:
   ```csharp
   await blobClient.SetAccessTierAsync(
       AccessTier.Hot, 
       rehydratePriority: RehydratePriority.High);  // < 1 hour
   ```

2. Monitor rehydration status:
   ```powershell
   $blob = Get-AzStorageBlob -Container "raw" -Blob "file.edi" -Context $ctx
   while ($blob.ICloudBlob.Properties.ArchiveStatus -ne $null) {
       Start-Sleep -Seconds 300
       $blob = Get-AzStorageBlob -Container "raw" -Blob "file.edi" -Context $ctx
       Write-Host "Status: $($blob.ICloudBlob.Properties.ArchiveStatus)"
   }
   ```

3. Download and replay once rehydrated

---

## Infrastructure Deployment

### Bicep Module (Complete)

Located at: `infra/bicep/modules/storage-account.bicep`

Key configurations applied in main deployment:

```bicep
// Production storage account
module storageAccount 'modules/storage-account.bicep' = {
  name: 'storage-account-deployment'
  params: {
    name: 'edistgprod01'
    location: location
    sku: 'Standard_GRS'  // Geo-redundant
    kind: 'StorageV2'
    enableHierarchicalNamespace: true  // ADLS Gen2
    enableVersioning: true
    enableBlobSoftDelete: true
    blobSoftDeleteRetentionDays: 30
    enableContainerSoftDelete: true
    containerSoftDeleteRetentionDays: 30
    publicNetworkAccess: 'Disabled'
    containerNames: [
      'landing'
      'raw'
      'quarantine'
      'metadata'
      'outbound-staging'
      'processed'
      'archive'
      'config'
      'inbound-responses'
      'orphaned-responses'
    ]
    lifecycleRules: [
      // See complete lifecycle policy in Lifecycle Management section
    ]
    workspaceId: logAnalyticsWorkspace.id
  }
}
```

---

## Cost Analysis

### 5-Year TCO Projection

**Assumptions**:
- 500 EDI files per day
- Average file size: 500 KB
- Growth rate: 10% annually
- Blob Storage: Standard GRS

| Year | Daily Files | Total Files | Storage Size | Database Only | Hybrid Model | **Savings** |
|------|-------------|-------------|--------------|---------------|--------------|-------------|
| 1 | 500 | 182,500 | 91 GB | $10,950 | $1,420 | **$9,530 (87%)** |
| 2 | 550 | 383,075 | 192 GB | $22,985 | $2,485 | **$20,500 (89%)** |
| 3 | 605 | 603,858 | 302 GB | $36,232 | $3,620 | **$32,612 (90%)** |
| 4 | 666 | 846,541 | 423 GB | $50,792 | $4,835 | **$45,957 (90%)** |
| 5 | 732 | 1,113,738 | 557 GB | $66,824 | $6,142 | **$60,682 (91%)** |
| **Total** | | | | **$187,783** | **$18,502** | **$169,281 (90%)** |

**ROI**: 915% over 5 years  
**Break-Even**: Month 2 of operation

---

## Cross-References

### Related Documentation

- **[01-data-ingestion-layer.md](01-data-ingestion-layer.md)**: SFTP landing zone and initial file upload
- **[02-processing-pipeline.md](02-processing-pipeline.md)**: ADF pipeline writing to raw, quarantine, metadata zones
- **[04-mapper-transformation.md](04-mapper-transformation.md)**: Mapper functions reading raw files and writing to outbound-staging
- **[07-database-layer.md](07-database-layer.md)**: Hybrid model with blob references in Azure SQL

### Specification Documents

- **[12-raw-file-storage-strategy-spec.md](../12-raw-file-storage-strategy-spec.md)**: Complete storage strategy (955 lines)
- **[02-data-flow-spec.md](../02-data-flow-spec.md)**: Storage path patterns and validation rules
- **[11-event-sourcing-architecture-spec.md](../11-event-sourcing-architecture-spec.md)**: Event replay from blob storage

### Infrastructure Code

- **infra/bicep/modules/storage-account.bicep**: Complete storage account Bicep module
- **infra/bicep/main.bicep**: Storage account deployment configuration

---

**Document Version**: 1.0  
**Last Updated**: October 6, 2025  
**Status**: Complete  
**Next Review**: Q1 2026
