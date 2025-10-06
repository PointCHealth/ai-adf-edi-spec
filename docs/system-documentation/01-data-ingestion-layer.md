# Data Ingestion Layer

**Version:** 3.0  
**Last Updated:** October 6, 2025  
**Owner:** EDI Platform Team  
**Related Specs:** [02-data-flow-spec.md](../02-data-flow-spec.md)

---

## Overview

The Data Ingestion Layer is the entry point for all EDI files into the platform. It provides secure, reliable file landing with immediate validation, metadata extraction, and immutable raw storage.

### Purpose

- Accept EDI files from trading partners via multiple protocols
- Validate file structure and enforce naming conventions
- Persist immutable copies in raw storage zone
- Extract metadata for lineage and tracking
- Trigger downstream processing via events

### Key Principles

- **Immutability**: Original files never modified after landing
- **Event-Driven**: Storage events trigger processing, no polling
- **Fail-Safe**: Invalid files quarantined, never lost
- **Traceable**: Every file tracked with correlation IDs

---

## Architecture

### Components

```text
┌──────────────┐
│   Trading    │
│   Partners   │
└──────┬───────┘
       │
       ▼
┌─────────────────────────────────────────────────────────┐
│             SFTP Landing Zone                          │
│  Azure Storage with SFTP-enabled access                │
│  Path: /inbound/<partnerCode>/                         │
└──────┬──────────────────────────────────────────────────┘
       │ Blob Created Event
       ▼
┌─────────────────────────────────────────────────────────┐
│             Event Grid                                  │
│  Filter: /inbound/** paths only                        │
└──────┬──────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────┐
│        ADF Pipeline: pl_ingest_dispatch                │
│  1. Validate naming convention                          │
│  2. Check partner authorization                         │
│  3. Compute checksum (SHA256)                           │
│  4. Optional: Virus scan                                │
│  5. Copy to raw zone (immutable)                        │
│  6. Extract metadata                                    │
│  7. Tag blob with classification                        │
└──────┬──────────────────────────────────────────────────┘
       │
       ├─ Success ──▶ Raw Zone Storage + Metadata Log
       │
       └─ Failure ──▶ Quarantine Zone + Alert
```

### Data Flow

**Happy Path**:

1. Partner uploads file to `/inbound/<partnerCode>/filename.edi`
2. Storage emits Blob Created event to Event Grid
3. Event Grid triggers ADF pipeline with blob URL
4. Pipeline validates file (naming, size, partner authorization)
5. Pipeline computes SHA256 checksum
6. Pipeline copies file to raw zone: `raw/partner=<code>/transaction=<type>/ingest_date=YYYY-MM-DD/`
7. Pipeline writes metadata record to Log Analytics `EDIIngestion_CL`
8. Pipeline publishes success event for downstream routing

**Error Path**:

1. Validation fails (naming, size, unauthorized partner)
2. File moved to quarantine: `quarantine/partner=<code>/ingest_date=YYYY-MM-DD/`
3. Metadata record written with `validationStatus=QUARANTINED` and reason
4. Alert sent to operations team
5. File awaits manual review or reprocessing

---

## Configuration

### File Naming Convention

**Pattern**: `<PartnerCode>_<TransactionSet>_<YYYYMMDDHHMMSS>_<Sequence>.<ext>`

**Examples**:

- `PARTNERA_270_20251006120000_001.edi` - Eligibility inquiry
- `PARTNERB_837P_20251006130000_012.edi` - Professional claim
- `INTERNAL-ENROLLMENT_834_20251006140000_001.edi` - Enrollment file

**Validation Rules**:

- PartnerCode: 2-20 alphanumeric characters, hyphens allowed
- TransactionSet: 3-digit X12 code (e.g., 270, 834, 837) with optional suffix (P/I/D)
- Timestamp: UTC, YYYYMMDDHHmmss format
- Sequence: 3-6 digit zero-padded number
- Extension: `.edi`, `.txt`, `.dat`, `.zip` (compressed batches)

### Partner Authorization

Partners defined in `config/partners/partners.json`:

```json
{
  "partnerCode": "PARTNERA",
  "name": "Partner A Healthcare",
  "partnerType": "EXTERNAL",
  "status": "active",
  "expectedTransactions": ["270", "271", "276", "277"],
  "endpoint": {
    "type": "SFTP",
    "sftp": {
      "homePath": "/inbound/PARTNERA",
      "pgpRequired": false
    }
  }
}
```

**Authorization Checks**:

- Partner code exists in active partner registry
- Transaction type in `expectedTransactions` list
- SFTP path matches partner `homePath`
- Partner status is "active" (not "inactive" or "draft")

### Storage Paths

| Zone | Purpose | Path Pattern | Lifecycle |
|------|---------|--------------|-----------|
| **Landing** | SFTP upload target | `/inbound/<partnerCode>/` | Delete after successful ingestion |
| **Raw** | Immutable source | `/raw/partner=<code>/transaction=<type>/ingest_date=YYYY-MM-DD/` | 7 years (HIPAA retention) |
| **Quarantine** | Failed validation | `/quarantine/partner=<code>/ingest_date=YYYY-MM-DD/` | 30 days, then archive or delete |
| **Metadata** | Processing logs | `/metadata/ingestion/date=YYYY-MM-DD/part-*.json` | 7 years |

### Validation Rules

| Rule | Check | Action on Failure |
|------|-------|-------------------|
| **Naming** | Matches regex pattern | Quarantine |
| **Partner Authorized** | Partner code exists and active | Quarantine + alert |
| **Transaction Supported** | Transaction in partner's expected list | Quarantine |
| **Size** | > 0 bytes, < 100 MB (default) | Quarantine |
| **Checksum** | SHA256 computed successfully | Retry, then quarantine |
| **Virus Scan** | Optional: AV engine returns clean | Quarantine + high-severity alert |

---

## Operations

### Monitoring

**Key Metrics**:

| Metric | Definition | Target | Query |
|--------|------------|--------|-------|
| **Ingestion Latency** | Time from blob created to raw zone persisted | p95 < 5 minutes | `ack_latency.kql` |
| **Validation Failure Rate** | Failed validations / total files | < 2% | `EDIIngestion_CL` |
| **Quarantine Count** | Files in quarantine by partner | Track trend | Dashboard |
| **Duplicate Rate** | Duplicate checksums detected | < 1% | `duplicate_detection.kql` |

**Log Analytics Query** (Ingestion Latency):

```kusto
EDIIngestion_CL
| where TimeGenerated > ago(24h)
| extend latencySeconds = datetime_diff('second', processedUtc, receivedUtc)
| summarize 
    p50=percentile(latencySeconds, 50),
    p95=percentile(latencySeconds, 95),
    p99=percentile(latencySeconds, 99),
    count=count()
by bin(TimeGenerated, 1h), partnerCode
| order by TimeGenerated desc
```

### Troubleshooting

**Common Issues**:

**1. File Quarantined - Naming Convention**

**Symptoms**: File in quarantine with reason "NAME_INVALID"

**Resolution**:

1. Check file naming against pattern in Event Grid metadata
2. Verify partner code matches configuration
3. If valid: Rename file and re-upload
4. If persistent: Review partner upload script/process

**2. Partner Not Authorized**

**Symptoms**: File quarantined with reason "PARTNER_UNAUTHORIZED"

**Resolution**:

1. Verify partner exists in `partners.json`
2. Check partner `status` is "active"
3. Verify transaction type in `expectedTransactions`
4. If new partner: Complete onboarding process (see [10-trading-partner-config.md](./10-trading-partner-config.md))

**3. High Ingestion Latency**

**Symptoms**: p95 latency > 10 minutes

**Resolution**:

1. Check ADF pipeline run history for delays
2. Review Event Grid delivery latency
3. Check Storage account throttling metrics
4. Scale up integration runtime if CPU/memory high
5. Review concurrent pipeline activity count

**4. Virus Scan Failures**

**Symptoms**: Files quarantined with AV failure

**Resolution**:

1. Verify AV service health (if using external scanner)
2. Review file content for actual malware
3. If false positive: Add exception and reprocess
4. Escalate to security team if malware confirmed

### Reprocessing

**Manual Reprocessing**:

1. Locate file in quarantine zone
2. Verify issue resolved (naming, partner config, etc.)
3. Trigger `pl_reprocess` pipeline with parameters:
   - `originalBlobPath`: Full path to quarantined file
   - `force`: true/false (skip re-validation if true)
4. Monitor pipeline execution
5. Verify success in `EDIIngestion_CL` log

**Automated Reprocessing**:

- Scheduled retry for transient errors (network, service unavailable)
- Max 3 retry attempts with exponential backoff (5min, 15min, 30min)
- After max retries: Dead-letter queue for manual intervention

---

## Security

### Authentication & Authorization

**SFTP Access**:

- Partner-specific SSH keys or passwords stored in Key Vault
- Per-partner SFTP users with restricted home directories
- No cross-partner file access (isolated paths)

**Service Identities**:

- ADF Managed Identity with:
  - Storage Blob Data Reader (landing zone)
  - Storage Blob Data Contributor (raw, quarantine zones)
  - Event Grid Data Sender (routing events)
  - Key Vault Secrets User (partner credentials)

### Data Protection

**Encryption**:

- At Rest: Azure Storage encryption (Microsoft-managed keys)
- In Transit: TLS 1.2+ for SFTP connections
- Optional: PGP encryption for sensitive partners (Phase 2)

**Access Controls**:

- Landing zone: Partner write-only (via SFTP user)
- Raw zone: Platform read-only, no delete
- Quarantine zone: Operations read/delete
- Network: Private endpoints for storage (no public access)

### Compliance

**HIPAA Requirements**:

- Audit logging: All file operations logged to Log Analytics
- Data retention: 7 years for raw files
- Immutability: Raw files optionally WORM-protected
- Lineage: Metadata links file to downstream processing

---

## Performance

### Scalability

**Current Capacity**:

- 100 concurrent file uploads via SFTP
- 5,000 files/hour ingestion throughput
- Max file size: 100 MB (configurable per partner)

**Scaling Strategies**:

- **Horizontal**: Additional ADF integration runtimes
- **Vertical**: Premium Storage tier for high IOPS
- **Partitioning**: Separate Event Grid subscriptions per partner for isolation

### Optimization

**Best Practices**:

1. **Batch Small Files**: Combine <100KB files into ZIP archives
2. **Parallel Activities**: ADF pipeline uses parallel copy activities for large files
3. **Event Filtering**: Event Grid filters by path to avoid unnecessary triggers
4. **Metadata Indexing**: Partition raw zone by date for efficient queries

---

## Testing

### Integration Tests

**Test Scenarios**:

1. **Happy Path**: Valid file uploaded → raw zone persisted
2. **Invalid Naming**: Incorrect filename → quarantine
3. **Unauthorized Partner**: Unknown partner code → quarantine
4. **Large File**: 50MB file → successful ingestion
5. **Duplicate File**: Same checksum → dedup detection
6. **ZIP Archive**: Compressed batch → extracted and processed

**Test Data**:

- Synthetic 270, 834, 837 files in `tests/data/`
- Partner configurations for test partners
- Automated test harness using Azure Storage SDK

### Performance Tests

**Load Testing**:

- 5,000 files uploaded in 1 hour (sustained)
- 100 concurrent uploads (burst)
- Measure: p95 latency, error rate, throughput

---

## References

### Related Documentation

- [Data Flow Specification](../02-data-flow-spec.md) - Complete data flow details
- [Processing Pipeline](./02-processing-pipeline.md) - Next stage after ingestion
- [Storage Strategy](./06-storage-strategy.md) - Storage zones and lifecycle
- [Trading Partner Config](./10-trading-partner-config.md) - Partner onboarding

### Configuration Files

- Partner registry: `config/partners/partners.json`
- Partner schema: `config/partners/partners.schema.json`
- ADF pipelines: `infra/bicep/modules/adf-pipelines.bicep`

### KQL Queries

- Ingestion latency: `queries/kusto/ingestion_latency.kql`
- Quarantine monitoring: `queries/kusto/quarantine_monitoring.kql`
- Duplicate detection: `queries/kusto/duplicate_detection.kql`

---

**Document Version:** 3.0  
**Last Updated:** October 6, 2025  
**Next Review:** January 6, 2026  
**Owner:** EDI Platform Team
