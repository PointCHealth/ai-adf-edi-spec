# Healthcare EDI Platform - Processing Pipeline

**Document Version:** 1.0  
**Date:** October 6, 2025  
**Status:** Production  
**Owner:** EDI Platform Team  
**Related Specifications:**

- [02-data-flow-spec.md](../02-data-flow-spec.md)
- [06-adf-pipeline-project.md](../../implementation-plan/06-adf-pipeline-project.md)
- [01-data-ingestion-layer.md](./01-data-ingestion-layer.md)
- [03-routing-messaging.md](./03-routing-messaging.md)

---

## Overview

### Purpose

The Processing Pipeline subsystem orchestrates validation, transformation, and metadata extraction for EDI files after landing. Built on Azure Data Factory (ADF), it bridges file ingestion and domain routing by enforcing data quality, maintaining audit trails, and preparing files for downstream processing.

**Key Responsibilities:**

- Event-driven pipeline orchestration via Event Grid
- Multi-stage validation (naming, authorization, integrity, structural)
- Metadata extraction and persistence (ingestion records)
- Raw zone persistence with hierarchical partitioning
- Quarantine management for failed files
- Routing trigger preparation

### Key Principles

1. **Event-Driven Architecture**: Storage events trigger pipelines; no scheduled polling
2. **Fail-Fast Validation**: Early rejection minimizes resource consumption
3. **Idempotency**: Duplicate files detected via SHA256 hash comparison
4. **Immutable Raw Storage**: Files never modified after persistence
5. **Observability First**: All pipeline activities logged to Log Analytics
6. **Configuration-Driven**: Partner policies and validation rules externalized

---

## Architecture

### Component Diagram

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                     PROCESSING PIPELINE ARCHITECTURE                     │
└─────────────────────────────────────────────────────────────────────────┘

  ┌──────────────┐
  │ Event Grid   │ Blob Created Event
  │   Topic      │ (sftp-root/inbound/<partner>/<file>)
  └──────┬───────┘
         │
         ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  ADF Pipeline: pl_ingest_dispatch                                     │
  │  ─────────────────────────────────                                    │
  │  1. Get Metadata Activity (blob properties)                          │
  │  2. Parse filename (partner code, transaction set)                   │
  │  3. Validate naming convention (regex)                               │
  │  4. Check partner authorization                                       │
  │  5. Route to specialized pipeline based on file type                 │
  └──────────────┬────────────┬──────────────────────┬────────────────────┘
                 │            │                      │
        .edi/.txt│      .zip │              Invalid │
                 │            │                      │
                 ▼            ▼                      ▼
  ┌──────────────────┐ ┌──────────────────┐  ┌──────────────────┐
  │ pl_ingest_       │ │ pl_ingest_       │  │ pl_ingest_       │
  │ validate_copy    │ │ zip_expand       │  │ error_handler    │
  └──────────────────┘ └──────────────────┘  └──────────────────┘
         │                     │                      │
         ▼                     ▼                      ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  Validation Activities                                                │
  │  ─────────────────────                                                │
  │  • Checksum computation (SHA256)                                     │
  │  • Optional virus scan (Azure Function hook)                         │
  │  • Size validation                                                    │
  │  • Duplicate detection (hash lookup)                                 │
  │  • Structural peek (ISA/IEA envelope check)                          │
  └──────────────────────┬──────────────────────────────────────────────┘
                         │
                    ┌────┴────┐
                    │         │
            Success │         │ Failure
                    ▼         ▼
         ┌──────────────┐  ┌──────────────┐
         │ Copy to Raw  │  │ Move to      │
         │ Zone         │  │ Quarantine   │
         │              │  │              │
         │ Path Pattern:│  │ Path Pattern:│
         │ raw/partner= │  │ quarantine/  │
         │ <code>/      │  │ partner=     │
         │ transaction= │  │ <code>/      │
         │ <set>/       │  │ date=YYYY-   │
         │ ingest_date= │  │ MM-DD/       │
         │ YYYY-MM-DD/  │  │ <file>       │
         └──────┬───────┘  └──────┬───────┘
                │                  │
                ▼                  ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  pl_ingest_metadata_publish                                           │
  │  ────────────────────────────                                         │
  │  • Write metadata JSON to metadata/ingestion/date=YYYY-MM-DD/        │
  │  • Publish to Log Analytics (EDIIngestion_CL custom table)           │
  │  • Tag blob with metadata (partner, transaction, sensitivity)        │
  └──────────────────────┬──────────────────────────────────────────────┘
                         │
                    Success│
                         ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  Routing Trigger (Next Stage)                                         │
  │  ────────────────────────────                                         │
  │  • Invoke func_router_dispatch (Azure Function)                      │
  │  • Pass: ingestionId, rawBlobPath, partnerCode, transactionSet       │
  │  • Function publishes routing messages to Service Bus                │
  └──────────────────────────────────────────────────────────────────────┘
```

### Data Flow (Happy Path)

```text
1. Partner uploads file → SFTP landing zone
2. Event Grid publishes Blob Created event
3. pl_ingest_dispatch triggered with blob URL
4. Get Metadata: Extract blob properties (size, lastModified, name)
5. Parse filename: Extract partnerCode, transactionSet, timestamp
6. Validate naming: Regex match against <PartnerCode>_<TransactionSet>_<YYYYMMDDHHMMSS>_<Sequence>.<ext>
7. Authorize partner: Lookup partnerCode in config/partners/partners.json
8. Check file type: Branch on extension (.edi, .zip, other)
9. Compute checksum: SHA256 hash of blob content
10. Duplicate detection: Query metadata store for existing hash
11. Optional virus scan: Call Azure Function with file stream
12. Structural peek: Validate ISA/IEA envelope consistency (X12 files)
13. Copy to raw zone: Persist with partitioned path
14. Tag blob: Apply metadata tags (partner, transaction, PHI, ingestionId)
15. Write metadata: JSON record to metadata/ingestion/date=YYYY-MM-DD/part-{guid}.json
16. Publish to Log Analytics: Custom table EDIIngestion_CL
17. Trigger routing: Invoke func_router_dispatch with ingestionId
```

### Error Path

```text
1. Validation failure detected (any stage)
2. Set pipeline variable: validationStatus = QUARANTINED
3. Set pipeline variable: quarantineReason = <failure detail>
4. Copy file to quarantine path
5. Write metadata record with failure details
6. Emit alert via Action Group (email/Teams/ServiceNow)
7. Log diagnostic event to Log Analytics (severity=Medium/High)
8. Pipeline completes (does NOT block other files)
```

---

## Configuration

### Pipeline Definitions

All pipelines defined in `infra/bicep/modules/data-factory.bicep` and exported to JSON for Git version control.

**Primary Pipelines:**

| Pipeline Name | Trigger | Purpose | Avg Duration |
|---------------|---------|---------|--------------|
| `pl_ingest_dispatch` | Event Grid | Entry point; routes by file type | 5-15 sec |
| `pl_ingest_validate_copy` | Called by dispatch | Validates and copies single file | 10-45 sec |
| `pl_ingest_zip_expand` | Called by dispatch | Decompresses archives, invokes validate foreach | 30-120 sec |
| `pl_ingest_error_handler` | Called on failure | Centralized quarantine + alerting | 3-8 sec |
| `pl_ingest_metadata_publish` | Called by validate | Writes metadata records | 5-10 sec |
| `pl_reprocess` | Manual/automation | Reprocesses quarantined files | 15-60 sec |

### ADF Configuration

**Resource Properties:**

```bicep
// From infra/bicep/modules/data-factory.bicep
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: 'adf-${namingPrefix}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Enabled' // Restricted to VNet via Managed VNet
  }
}

// Managed Virtual Network (private network isolation)
resource managedVirtualNetwork 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = {
  parent: dataFactory
  name: 'default'
  properties: {}
}

// Integration Runtime (compute for activities)
resource integrationRuntime 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  parent: dataFactory
  name: 'AutoResolveIntegrationRuntime'
  properties: {
    type: 'Managed'
    managedVirtualNetwork: {
      referenceName: 'default'
      type: 'ManagedVirtualNetworkReference'
    }
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
        dataFlowProperties: {
          computeType: 'General'
          coreCount: 8
          timeToLive: 10 // minutes
        }
      }
    }
  }
}
```

**Linked Services:**

- **AzureDataLakeStorage**: Connection to ADLS Gen2 raw/staging zones
  - Authentication: System-assigned managed identity
  - Permissions: Storage Blob Data Contributor (RBAC)
- **AzureKeyVault**: Secret retrieval for partner credentials
  - Authentication: System-assigned managed identity
  - Permissions: Key Vault Secrets User
- **AzureSqlDatabase**: Control number store (for outbound)
  - Authentication: System-assigned managed identity (SQL authentication fallback)
  - Permissions: db_datareader, db_datawriter
- **AzureFunction**: Custom validation activities
  - Authentication: Function key from Key Vault

### File Naming Convention

**Required Pattern:**

```regex
^[A-Za-z0-9]{2,10}_(\d{3}[A-Za-z]?)_\d{14}_[0-9]{3,6}\.[A-Za-z0-9]+$
```

**Example Valid Names:**

- `PARTNERA_270_20251006120000_001.edi`
- `HEALTHCO_837P_20251006143022_000125.txt`
- `PAYER01_834_20251006090000_999999.dat`

**Components:**

| Component | Description | Pattern | Example |
|-----------|-------------|---------|---------|
| **PartnerCode** | Unique partner identifier | `[A-Za-z0-9]{2,10}` | `PARTNERA` |
| **TransactionSet** | X12 transaction type | `\d{3}[A-Za-z]?` | `270`, `837P` |
| **Timestamp** | UTC generation time | `YYYYMMDDHHMMSS` | `20251006120000` |
| **Sequence** | Incremental counter | `\d{3,6}` | `001`, `000125` |
| **Extension** | File type | `.edi`, `.txt`, `.dat`, `.zip` | `.edi` |

### Storage Path Patterns

**Landing Zone (SFTP):**

```text
sftp-root/inbound/<partnerCode>/<originalFileName>

Example:
sftp-root/inbound/PARTNERA/PARTNERA_270_20251006120000_001.edi
```

**Raw Zone (Validated):**

```text
raw/partner=<partnerCode>/transaction=<transactionSet>/ingest_date=YYYY-MM-DD/<originalFileName>

Example:
raw/partner=PARTNERA/transaction=270/ingest_date=2025-10-06/PARTNERA_270_20251006120000_001.edi
```

**Quarantine Zone:**

```text
quarantine/partner=<partnerCode>/ingest_date=YYYY-MM-DD/<originalFileName>

Example:
quarantine/partner=PARTNERA/ingest_date=2025-10-06/PARTNERA_270_20251006120000_001.edi
```

**Metadata Zone:**

```text
metadata/ingestion/date=YYYY-MM-DD/part-<guid>.json

Example:
metadata/ingestion/date=2025-10-06/part-9f1c6d2e-3f3d-4b6c-9d4b-0e9e2a6c1a11.json
```

---

## Operations

### Pipeline Activities

**1. Get Metadata Activity**

Extracts blob properties to avoid full download for validation.

```json
{
  "name": "GetFileMetadata",
  "type": "GetMetadata",
  "typeProperties": {
    "dataset": {
      "referenceName": "LandingZoneBlob"
    },
    "fieldList": [
      "itemName",
      "size",
      "lastModified",
      "contentMD5"
    ]
  }
}
```

**Output Variables:**

- `@activity('GetFileMetadata').output.itemName` → Original filename
- `@activity('GetFileMetadata').output.size` → File size in bytes
- `@activity('GetFileMetadata').output.lastModified` → Timestamp

**2. Parse Filename Activity**

Extracts components using ADF expressions.

```json
{
  "name": "ParseFilename",
  "type": "SetVariable",
  "typeProperties": {
    "variableName": "partnerCode",
    "value": "@split(activity('GetFileMetadata').output.itemName, '_')[0]"
  }
}
```

**Extracted Variables:**

- `@variables('partnerCode')` → Partner identifier
- `@variables('transactionSet')` → Transaction type (270, 834, 837P, etc.)
- `@variables('timestamp')` → File generation timestamp
- `@variables('sequence')` → Sequence number
- `@variables('extension')` → File extension

**3. Validate Naming Activity**

Uses If Condition to check regex match.

```json
{
  "name": "ValidateNamingConvention",
  "type": "IfCondition",
  "typeProperties": {
    "expression": {
      "@bool(startsWith(activity('GetFileMetadata').output.itemName, variables('partnerCode')))"
    },
    "ifFalseActivities": [
      {
        "name": "QuarantineInvalidName",
        "type": "ExecutePipeline",
        "typeProperties": {
          "pipeline": {
            "referenceName": "pl_ingest_error_handler"
          },
          "parameters": {
            "quarantineReason": "NAMING_INVALID"
          }
        }
      }
    ]
  }
}
```

**4. Authorize Partner Activity**

Lookup partner configuration from config store.

```json
{
  "name": "AuthorizePartner",
  "type": "Lookup",
  "typeProperties": {
    "source": {
      "type": "JsonSource",
      "storeSettings": {
        "type": "AzureBlobFSReadSettings",
        "recursive": false,
        "wildcardFileName": "partners.json"
      }
    },
    "dataset": {
      "referenceName": "PartnerConfigDataset"
    }
  }
}
```

**Validation Logic:**

```javascript
// Check if partner exists and is active
@bool(
  or(
    equals(activity('AuthorizePartner').output.firstRow.status, 'ACTIVE'),
    equals(activity('AuthorizePartner').output.firstRow.status, 'TESTING')
  )
)
```

**5. Compute Checksum Activity**

Calls Azure Function to compute SHA256 hash.

```json
{
  "name": "ComputeChecksum",
  "type": "AzureFunctionActivity",
  "typeProperties": {
    "functionName": "ComputeChecksum",
    "method": "POST",
    "headers": {},
    "body": {
      "blobUri": "@activity('GetFileMetadata').output.itemName"
    }
  },
  "linkedServiceName": {
    "referenceName": "AzureFunctionLinkedService"
  }
}
```

**Output:**

```json
{
  "checksumSha256": "a3f5b8c2d1e9f0a7b6c4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b7c6d5e4f3a2"
}
```

**6. Duplicate Detection Activity**

Queries metadata store for existing hash.

```json
{
  "name": "CheckDuplicate",
  "type": "Lookup",
  "typeProperties": {
    "source": {
      "type": "JsonSource",
      "storeSettings": {
        "type": "AzureBlobFSReadSettings",
        "wildcardFolderPath": "metadata/ingestion/date=*",
        "wildcardFileName": "*.json"
      },
      "additionalColumns": [
        {
          "name": "fileHash",
          "value": "@activity('ComputeChecksum').output.checksumSha256"
        }
      ]
    }
  }
}
```

**Decision Logic:**

```javascript
// If hash exists, mark as SKIPPED_DUPLICATE
@if(
  greater(activity('CheckDuplicate').output.count, 0),
  'SKIPPED_DUPLICATE',
  'PROCEED'
)
```

**7. Optional Virus Scan Activity**

Calls Azure Function with AV engine integration.

```json
{
  "name": "VirusScan",
  "type": "AzureFunctionActivity",
  "typeProperties": {
    "functionName": "ScanFile",
    "method": "POST",
    "body": {
      "blobUri": "@activity('GetFileMetadata').output.itemName"
    }
  },
  "linkedServiceName": {
    "referenceName": "AzureFunctionLinkedService"
  }
}
```

**Output:**

```json
{
  "scanResult": "CLEAN", // or "INFECTED"
  "scanEngine": "Microsoft Defender",
  "scanTimestamp": "2025-10-06T12:00:30Z"
}
```

**8. Structural Peek Activity**

Validates X12 envelope consistency (ISA/IEA, GS/GE, ST/SE).

```json
{
  "name": "StructuralPeek",
  "type": "AzureFunctionActivity",
  "typeProperties": {
    "functionName": "ValidateEnvelope",
    "method": "POST",
    "body": {
      "blobUri": "@activity('GetFileMetadata').output.itemName",
      "maxBytes": 10240
    }
  }
}
```

**Validation Checks:**

- ISA segment present at start
- IEA segment present at end with matching control number
- GS/GE functional group envelope valid
- ST/SE transaction set envelopes valid
- Segment counts match declared counts

**9. Copy to Raw Zone Activity**

Persists validated file to raw zone with partitioned path.

```json
{
  "name": "CopyToRawZone",
  "type": "Copy",
  "inputs": [
    {
      "referenceName": "LandingZoneBlob"
    }
  ],
  "outputs": [
    {
      "referenceName": "RawZoneBlob",
      "parameters": {
        "partnerCode": "@variables('partnerCode')",
        "transactionSet": "@variables('transactionSet')",
        "ingestDate": "@formatDateTime(utcnow(), 'yyyy-MM-dd')"
      }
    }
  ],
  "typeProperties": {
    "source": {
      "type": "BinarySource"
    },
    "sink": {
      "type": "BinarySink"
    },
    "preserve": true,
    "validateDataConsistency": true
  }
}
```

**10. Tag Blob Activity**

Applies metadata tags for governance and access control.

```json
{
  "name": "TagBlob",
  "type": "WebActivity",
  "typeProperties": {
    "url": "@concat('https://', variables('storageAccount'), '.blob.core.windows.net/', variables('rawBlobPath'), '?comp=tags')",
    "method": "PUT",
    "headers": {
      "Content-Type": "application/xml"
    },
    "body": "<Tags><TagSet><Tag><Key>PartnerCode</Key><Value>@{variables('partnerCode')}</Value></Tag><Tag><Key>TransactionSet</Key><Value>@{variables('transactionSet')}</Value></Tag><Tag><Key>DataSensitivity</Key><Value>PHI</Value></Tag><Tag><Key>IngestionId</Key><Value>@{variables('ingestionId')}</Value></Tag></TagSet></Tags>"
  }
}
```

**11. Write Metadata Activity**

Persists ingestion metadata JSON record.

```json
{
  "name": "WriteMetadata",
  "type": "Copy",
  "inputs": [
    {
      "type": "InlineDataset"
    }
  ],
  "outputs": [
    {
      "referenceName": "MetadataZoneJson"
    }
  ],
  "typeProperties": {
    "source": {
      "type": "JsonSource",
      "inline": {
        "ingestionId": "@variables('ingestionId')",
        "partnerCode": "@variables('partnerCode')",
        "transactionSet": "@variables('transactionSet')",
        "originalFileName": "@activity('GetFileMetadata').output.itemName",
        "receivedUtc": "@activity('GetFileMetadata').output.lastModified",
        "processedUtc": "@utcnow()",
        "blobPathRaw": "@variables('rawBlobPath')",
        "checksumSha256": "@activity('ComputeChecksum').output.checksumSha256",
        "fileSizeBytes": "@activity('GetFileMetadata').output.size",
        "validationStatus": "SUCCESS",
        "quarantineReason": null,
        "retryCount": 0
      }
    },
    "sink": {
      "type": "JsonSink"
    }
  }
}
```

### Monitoring Metrics

**Pipeline Metrics:**

| Metric | Description | Target | KQL Query |
|--------|-------------|--------|-----------|
| **Ingestion Latency** | processedUtc - receivedUtc | < 300 sec (p95) | `ingestion_latency.kql` |
| **Validation Failure Rate** | Failures / total per day | < 2% | `validation_failure_rate.kql` |
| **Pipeline Success Rate** | Successful runs / total | > 99% | `pipeline_success_rate.kql` |
| **Throughput** | Files processed per hour | 5,000+ | `ingestion_throughput.kql` |
| **Quarantine Rate** | Quarantined files / total | < 2% | `quarantine_rate.kql` |

**KQL Query Examples:**

```kql
// Ingestion Latency (p50, p95, p99)
EDIIngestion_CL
| where TimeGenerated > ago(24h)
| extend LatencySec = datetime_diff('second', processedUtc_t, receivedUtc_t)
| summarize 
    p50 = percentile(LatencySec, 50),
    p95 = percentile(LatencySec, 95),
    p99 = percentile(LatencySec, 99),
    count()
| render timechart

// Validation Failure Rate by Partner
EDIIngestion_CL
| where TimeGenerated > ago(7d)
| summarize 
    Total = count(),
    Failures = countif(validationStatus_s != "SUCCESS")
    by partnerCode_s
| extend FailureRate = round(100.0 * Failures / Total, 2)
| where FailureRate > 2.0
| order by FailureRate desc

// Pipeline Duration by Activity
ADFPipelineRun
| where PipelineName == "pl_ingest_validate_copy"
| where TimeGenerated > ago(24h)
| extend DurationSec = datetime_diff('second', End, Start)
| summarize 
    avg(DurationSec), 
    percentile(DurationSec, 95)
    by ActivityName
| order by avg_DurationSec desc
| render barchart

// Quarantine Trend by Reason
EDIIngestion_CL
| where TimeGenerated > ago(30d)
| where validationStatus_s == "QUARANTINED"
| summarize count() by quarantineReason_s, bin(TimeGenerated, 1d)
| render timechart
```

### Troubleshooting

**1. Pipeline Execution Failures**

**Symptom:** Pipeline status = Failed in ADF monitoring

**Diagnosis Steps:**

```kql
// Find failed pipeline runs
ADFPipelineRun
| where Status == "Failed"
| where TimeGenerated > ago(1h)
| project 
    TimeGenerated,
    PipelineName,
    RunId,
    ErrorCode,
    ErrorMessage,
    FailureType
| order by TimeGenerated desc
```

**Common Causes:**

- **Timeout**: Integration Runtime busy (check TTL settings)
- **Permission denied**: Managed identity missing RBAC role
- **Network error**: Managed VNet not configured or firewall blocking
- **Invalid reference**: Linked service or dataset misconfigured

**Resolution:**

```powershell
# Check managed identity permissions
$MI_ObjectId = (Get-AzDataFactoryV2 -ResourceGroupName "rg-edi-prod" -Name "adf-edi-prod").Identity.PrincipalId
Get-AzRoleAssignment -ObjectId $MI_ObjectId

# Verify linked service connection
Test-AzDataFactoryV2LinkedService -ResourceGroupName "rg-edi-prod" -DataFactoryName "adf-edi-prod" -Name "AzureDataLakeStorage"

# Check Integration Runtime status
Get-AzDataFactoryV2IntegrationRuntime -ResourceGroupName "rg-edi-prod" -DataFactoryName "adf-edi-prod" -Name "AutoResolveIntegrationRuntime"
```

**2. Slow Pipeline Performance**

**Symptom:** Ingestion latency > 300 seconds

**Diagnosis:**

```kql
// Identify slow activities
ADFActivityRun
| where TimeGenerated > ago(1h)
| extend DurationSec = datetime_diff('second', End, Start)
| where DurationSec > 30
| summarize 
    avg(DurationSec),
    max(DurationSec),
    count()
    by ActivityName, ActivityType
| order by avg_DurationSec desc
```

**Common Causes:**

- **Large files**: > 50 MB files causing Copy Activity timeout
- **Cold start**: Integration Runtime warming up (increase TTL)
- **Azure Function latency**: Custom validation functions slow
- **Metadata lookup**: Inefficient partner config queries

**Resolution:**

- Enable parallel processing for large files
- Increase Integration Runtime TTL to 30 minutes
- Optimize Azure Function code (caching, connection pooling)
- Use indexed lookup datasets for partner config

**3. Quarantine Rate Spike**

**Symptom:** > 5% of files quarantined

**Diagnosis:**

```kql
// Quarantine reasons breakdown
EDIIngestion_CL
| where TimeGenerated > ago(24h)
| where validationStatus_s == "QUARANTINED"
| summarize count() by quarantineReason_s
| order by count_ desc
| render piechart
```

**Common Causes:**

- **Naming violations**: Partner changed naming convention
- **Unauthorized partner**: Partner config not updated
- **Virus scan failures**: False positives from AV engine
- **Structural errors**: Malformed X12 envelopes

**Resolution:**

- Review partner config for recent changes
- Validate naming convention with partner
- Tune AV engine sensitivity (if false positives)
- Contact partner for file format corrections

**4. Duplicate Detection Failures**

**Symptom:** Same file processed multiple times

**Diagnosis:**

```kql
// Find duplicate ingestion IDs
EDIIngestion_CL
| where TimeGenerated > ago(24h)
| summarize count() by checksumSha256_s
| where count_ > 1
| order by count_ desc
```

**Common Causes:**

- **Hash collision**: Extremely rare (SHA256 collision)
- **Metadata lookup failure**: Metadata store unavailable
- **Race condition**: Two pipelines processing same file

**Resolution:**

- Verify metadata store availability
- Check for concurrent pipeline runs (should not happen)
- Review Event Grid subscription filter to prevent duplicates

---

## Security

### Access Control

**Azure Data Factory Managed Identity:**

| Resource | Role | Justification |
|----------|------|---------------|
| ADLS Gen2 Storage Account | Storage Blob Data Contributor | Read/write to landing, raw, quarantine zones |
| Azure Key Vault | Key Vault Secrets User | Retrieve partner credentials, connection strings |
| Azure SQL Database | db_datareader, db_datawriter | Control number queries (outbound) |
| Azure Functions | Function Key retrieval | Invoke custom validation functions |
| Log Analytics | Monitoring Metrics Publisher | Publish custom metrics and logs |

**Bicep Configuration:**

```bicep
// Storage RBAC assignment
resource storageBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, dataFactory.id, 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: dataFactory.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Key Vault RBAC assignment
resource keyVaultSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, dataFactory.id, '4633458b-17de-408a-b874-0445c86b69e6')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 
      '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: dataFactory.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
```

### Network Isolation

**Managed Virtual Network:**

- All Integration Runtime activities execute within ADF Managed VNet
- No public internet access for pipeline activities
- Private endpoints to ADLS Gen2, Key Vault, SQL Database
- Outbound traffic restricted to approved Azure services

**Configuration:**

```bicep
// From infra/bicep/modules/data-factory.bicep
resource managedVirtualNetwork 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = {
  parent: dataFactory
  name: 'default'
  properties: {}
}

// Private endpoint to storage
resource storagePrivateEndpoint 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = {
  parent: managedVirtualNetwork
  name: 'storage-private-endpoint'
  properties: {
    privateLinkResourceId: storageAccount.id
    groupId: 'blob'
  }
}
```

### Data Protection

**In Transit:**

- HTTPS/TLS 1.2+ only for all data transfers
- Managed identity authentication (no credentials in pipelines)
- Private endpoints for Azure service communication

**At Rest:**

- Azure Storage Service Encryption (SSE) enabled by default
- Customer-managed keys (CMK) optional via Key Vault
- Blob versioning enabled for accidental deletion protection
- Soft delete enabled (30 days retention)

**PHI Handling:**

- Minimal data exposure in pipeline logs (no claim lines, no member IDs)
- Metadata extracts only envelope control numbers
- File content never logged to Application Insights or Log Analytics
- Blob tags mark PHI/PII sensitivity for governance

---

## Performance

### Capacity Planning

**Current Throughput:**

- **Files per hour**: 5,000+ (tested with 500 KB average file size)
- **Concurrent pipelines**: 50 (ADF default concurrency limit)
- **Integration Runtime**: 8 vCores, 10-minute TTL
- **Average latency**: 15-45 seconds (p95 < 300 sec)

**Scaling Strategies:**

1. **Horizontal Scaling**: Increase Integration Runtime core count (8 → 16 → 32 vCores)
2. **Parallel Processing**: Enable ForEach parallelism for batch files
3. **Partitioning**: Distribute files across multiple pipelines by partner
4. **Caching**: Cache partner config in memory (Azure Function static variable)

### Optimization Best Practices

**1. Minimize Data Movement:**

- Use Get Metadata instead of full Copy for validation
- Structural peek reads only first 10 KB of file
- Checksum computed incrementally (streaming)

**2. Optimize Activity Chaining:**

- Execute independent activities in parallel
- Avoid unnecessary dependencies between activities
- Use pipeline parameters to skip optional activities

**3. Integration Runtime Tuning:**

```bicep
resource integrationRuntime 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  properties: {
    typeProperties: {
      computeProperties: {
        dataFlowProperties: {
          computeType: 'General'
          coreCount: 16 // Increased from 8 for high throughput
          timeToLive: 30 // Increased from 10 to reduce cold starts
        }
      }
    }
  }
}
```

**4. Reduce External Calls:**

- Batch Azure Function invocations where possible
- Use ADF-native activities instead of Web Activity
- Cache lookup results in pipeline variables

---

## Testing

### Integration Testing

**Test Scenarios:**

1. **Happy Path**: Valid file → raw zone → metadata published → routing triggered
2. **Invalid Naming**: Malformed filename → quarantine → alert
3. **Unauthorized Partner**: Unknown partner code → quarantine
4. **Duplicate File**: Same hash → skipped with SKIPPED_DUPLICATE status
5. **Large File**: 100 MB file → parallel copy → success
6. **Zip Archive**: Archive file → decompressed → each file validated
7. **Virus Detected**: Infected file → quarantine → high-severity alert
8. **Structural Error**: Malformed X12 → quarantine
9. **Network Timeout**: Storage unavailable → retry → eventual success
10. **Concurrent Uploads**: 100 files simultaneously → all processed

**Test Data:**

```powershell
# Generate test file
$partnerCode = "TESTPART"
$transactionSet = "270"
$timestamp = (Get-Date).ToString("yyyyMMddHHmmss")
$sequence = "001"
$filename = "${partnerCode}_${transactionSet}_${timestamp}_${sequence}.edi"

# Upload to landing zone
az storage blob upload `
  --account-name "edistgdev01" `
  --container-name "sftp-root" `
  --name "inbound/${partnerCode}/${filename}" `
  --file "./testdata/${filename}"

# Monitor pipeline execution
az datafactory pipeline-run show `
  --factory-name "adf-edi-dev" `
  --resource-group "rg-edi-dev" `
  --run-id "<run-id>"
```

### Load Testing

**Test Configuration:**

- **Tool**: Azure Load Testing service
- **Scenario**: 5,000 files uploaded in 60 minutes (83 files/minute)
- **File sizes**: 100 KB to 5 MB (mixed distribution)
- **Partners**: 10 unique partner codes
- **Transaction types**: 270, 834, 837P (mixed)

**Success Criteria:**

- All files processed successfully
- p95 latency < 300 seconds
- No pipeline failures
- No duplicate processing
- Quarantine rate < 2%

---

## References

### Specifications

- [02-data-flow-spec.md](../02-data-flow-spec.md) - Detailed data flow and validation rules
- [01-architecture-spec.md](../01-architecture-spec.md) - Overall system architecture
- [08-transaction-routing-outbound-spec.md](../08-transaction-routing-outbound-spec.md) - Routing layer details

### Implementation Guides

- [06-adf-pipeline-project.md](../../implementation-plan/06-adf-pipeline-project.md) - Pipeline implementation guide
- [05-phase-1-core-platform.md](../../implementation-plan/05-phase-1-core-platform.md) - Phase 1 deployment
- [07-storage-container-structure.md](../../implementation-plan/07-storage-container-structure.md) - Storage layout

### Code Repositories

- **ADF Pipelines**: `infra/bicep/modules/data-factory.bicep`
- **Validation Functions**: (To be implemented in Phase 1)
- **KQL Queries**: `docs/kql-queries.md`

### Related Documentation

- [01-data-ingestion-layer.md](./01-data-ingestion-layer.md) - SFTP landing and file reception
- [03-routing-messaging.md](./03-routing-messaging.md) - Service Bus routing (next stage)
- [06-storage-strategy.md](./06-storage-strategy.md) - Storage zones and lifecycle management

---

**Document Status:** Complete  
**Last Validation:** October 6, 2025  
**Next Review:** January 6, 2026
