# Mapper and Connector Solution Specification for Destination Claim Systems

## 1. Purpose

Define the architecture, integration patterns, data transformation logic, and operational procedures for connecting the Healthcare EDI Platform to downstream **destination claim systems** (external/legacy systems) that:

1. Consume routed EDI transactions (837, 270, 276, 278, etc.) in their native formats
2. Generate business response data (271, 277, 277CA, 835) that must be transformed back to standard X12 for partner acknowledgments

This specification bridges the **core platform routing layer** (see Doc 08) and **heterogeneous claim system ecosystems** while maintaining loose coupling, traceability, and data integrity.

---

## 2. Scope

### 2.1 In-Scope

| Category | Items |
|----------|-------|
| **Outbound (Platform → Claim System)** | Transformation of routing messages to claim system input formats (proprietary XML, JSON, flat files, database inserts, APIs) |
| **Inbound (Claim System → Platform)** | Normalization of claim system responses to canonical intermediate format; assembly into standard X12 acknowledgments/responses |
| **Connector Patterns** | File-based (SFTP/SMB), API-based (REST/SOAP), database-based (direct SQL, stored procedures), message queue-based (MSMQ, proprietary queues) |
| **Claim System Types** | Adjudication engines, Prior authorization systems, Eligibility verification systems, Remittance processors, Claims clearinghouses |
| **Error Handling** | Mapping failures, connectivity failures, claim system rejections, idempotency, retries, dead-letter handling |
| **Observability** | Lineage tracking (routingId → claim system correlation ID → response), latency metrics, transformation audit logs |
| **Security** | Credential management, encryption in transit, least privilege access, PHI handling |

### 2.2 Out-of-Scope (Phase 1)

- Real-time streaming transformations (batch/micro-batch only)
- Custom business logic beyond data transformation (adjudication decisions remain in claim systems)
- Legacy system modernization or replacement
- Master data management (MDM) or canonical member/provider registries (reference data lookups only)
- Claim system internal modifications (connectors are adapter layer only)

---

## 3. Architectural Context

### 3.1 System Boundary

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Core EDI Platform                             │
│  ┌──────────────┐    ┌──────────────┐    ┌─────────────────┐   │
│  │ Ingestion    │───▶│ Router       │───▶│ Service Bus     │   │
│  │ (ADF)        │    │ Function     │    │ (edi-routing)   │   │
│  └──────────────┘    └──────────────┘    └────────┬────────┘   │
└──────────────────────────────────────────────────┼──────────────┘
                                                    │
                        ┌───────────────────────────┼───────────────────────┐
                        │                           │                       │
                        ▼                           ▼                       ▼
         ┌──────────────────────────┐  ┌──────────────────────┐  ┌─────────────────┐
         │  Mapper & Connector A    │  │  Mapper & Connector B│  │  Mapper & ...   │
         │  (837 Claims)            │  │  (270 Eligibility)   │  │                 │
         └─────────────┬────────────┘  └──────────┬───────────┘  └────────┬────────┘
                       │                           │                       │
                       ▼                           ▼                       ▼
         ┌──────────────────────────┐  ┌──────────────────────┐  ┌─────────────────┐
         │  Claim System 1          │  │  Claim System 2      │  │  Claim System N │
         │  (Adjudication Engine)   │  │  (Eligibility SaaS)  │  │  (Legacy AS400) │
         └─────────────┬────────────┘  └──────────┬───────────┘  └────────┬────────┘
                       │                           │                       │
                       │ (Response data in native format)                  │
                       ▼                           ▼                       ▼
         ┌──────────────────────────────────────────────────────────────────┐
         │             Response Aggregation & X12 Assembly                  │
         │          (Outbound Orchestrator - see Doc 08)                    │
         └──────────────────────────────────────────────────────────────────┘
```

**Key Principle**: Mappers and Connectors are **adapter layers** between the standardized platform and diverse claim systems. They do NOT own business logic; they translate formats and manage connectivity.

### 3.2 Interaction with Core Platform Components

| Core Component | Mapper/Connector Interaction |
|----------------|------------------------------|
| **Service Bus (edi-routing)** | Connectors subscribe to filtered topics (e.g., `sub-claims-system1`) and receive routing messages |
| **Raw Storage** | Mappers may fetch original EDI file via `fileBlobPath` if full payload needed (not just envelope metadata) |
| **Outbound Staging** | Connectors write response outcome signals (normalized format) for Outbound Orchestrator to consume |
| **Control Number Store** | No direct access (Outbound Orchestrator owns control number management) |
| **Log Analytics** | Mappers emit `MapperTransformation_CL` and `ConnectorDelivery_CL` custom logs |

---

## 4. Mapper Architecture

### 4.1 Mapper Responsibility

A **Mapper** transforms:

1. **Outbound**: EDI transaction data (837, 270, etc.) → Claim system input format
2. **Inbound**: Claim system response data → Canonical intermediate format (e.g., JSON schema) for X12 assembly

**Mappers are stateless**; all state externalized to staging storage or databases.

### 4.2 Outbound Mapper Flow (Platform → Claim System)

```text
┌────────────────┐
│ Routing Msg    │ (routingId, transactionSet, fileBlobPath, stPosition, etc.)
└────────┬───────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────┐
│                  Mapper Function / Logic App                      │
│                                                                    │
│  1. Fetch full EDI file from Raw Storage (if needed)             │
│  2. Parse ST segment at stPosition (using X12 parser library)     │
│  3. Extract claim system-specific fields per mapping rules        │
│  4. Transform to target format (XML, JSON, CSV, fixed-width)      │
│  5. Validate output schema                                        │
│  6. Enrich with claim system metadata (e.g., batch header)        │
│  7. Stage output file/payload                                     │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
                   ┌──────────────────┐
                   │ Connector        │ (Delivers to claim system)
                   └──────────────────┘
```

### 4.3 Inbound Mapper Flow (Claim System → Platform)

```text
┌────────────────┐
│ Claim System   │ (277 status update, 271 eligibility response, 835 remittance)
│ Response Data  │ (Proprietary format: XML, JSON, DB row, etc.)
└────────┬───────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────┐
│              Inbound Mapper Function / Logic App                  │
│                                                                    │
│  1. Receive response via connector (file pickup, API callback,    │
│     database poll)                                                │
│  2. Parse native format (XML/JSON parser, DB query result)        │
│  3. Validate completeness (required fields present)               │
│  4. Map to canonical response schema (see §4.5)                   │
│  5. Correlate to original routingId (via claim system ref ID)     │
│  6. Write to Outbound Staging (outcome signal)                    │
│  7. Emit audit log with transformation metadata                   │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
                   ┌──────────────────────┐
                   │ Outbound Orchestrator│ (Builds X12 271, 277, 835, etc.)
                   └──────────────────────┘
```

### 4.4 Mapping Rules Repository

**Storage**: `config/mappers/<claim-system-id>/`

**Structure**:

```text
config/mappers/
├── claim-system-a/
│   ├── 837-to-xml-v1.json          # Declarative field mapping
│   ├── 271-from-json-v1.json       # Reverse mapping
│   ├── validation-schema.xsd       # Output schema validation
│   └── enrichment-rules.json       # Conditional logic (e.g., payer-specific codes)
├── claim-system-b/
│   ├── 270-to-csv-v2.json
│   └── ...
└── shared/
    ├── x12-segment-definitions.json # Reusable X12 parsing metadata
    └── code-translation-tables.json # e.g., HIPAA codes → proprietary codes
```

**Format Example** (`837-to-xml-v1.json`):

```json
{
  "version": "1.0",
  "sourceFormat": "X12-837P",
  "targetFormat": "ClaimSystemA-XML-v2.3",
  "mappings": [
    {
      "targetPath": "Claim.ClaimID",
      "sourceSegment": "CLM",
      "sourceElement": "CLM01",
      "required": true,
      "transformation": null
    },
    {
      "targetPath": "Claim.PatientID",
      "sourceSegment": "NM1",
      "sourceQualifier": "IL",
      "sourceElement": "NM109",
      "required": true,
      "transformation": null
    },
    {
      "targetPath": "Claim.SubmittedAmount",
      "sourceSegment": "CLM",
      "sourceElement": "CLM02",
      "required": true,
      "transformation": "formatCurrency"
    },
    {
      "targetPath": "Claim.DiagnosisCodes",
      "sourceSegment": "HI",
      "sourceComposite": "HI01",
      "required": true,
      "transformation": "extractDiagnosisList"
    }
  ],
  "conditionalEnrichment": [
    {
      "condition": "partnerCode == 'PARTNERA'",
      "action": "addField",
      "targetPath": "Claim.CustomField1",
      "value": "SPECIAL_FLAG"
    }
  ]
}
```

### 4.5 Canonical Response Schema (Intermediate Format)

**Purpose**: Normalize diverse claim system responses into a platform-standard JSON structure that Outbound Orchestrator can consume to generate X12.

**Schema**: `config/schemas/canonical-response-v1.json`

**Example** (271 Eligibility Response):

```json
{
  "responseId": "uuid",
  "responseType": "271",
  "routingId": "original-routing-guid",
  "claimSystemId": "claim-system-a",
  "claimSystemCorrelationId": "CS123456",
  "receivedUtc": "2025-10-02T14:32:00Z",
  "responseStatus": "ACCEPTED",
  "responseData": {
    "eligibility": {
      "memberId": "MBR123456",
      "subscriberId": "SUB789",
      "coverageActive": true,
      "benefitDetails": [
        {
          "serviceTypeCode": "30",
          "coverageLevel": "IND",
          "timePeriodQualifier": "29",
          "monetaryAmount": 1500.00,
          "percentAmount": null,
          "quantityQualifier": null,
          "quantity": null
        }
      ],
      "rejectionReason": null
    }
  },
  "mappingMetadata": {
    "mapperVersion": "1.0",
    "transformationDurationMs": 45,
    "validationErrors": []
  }
}
```

**Example** (277CA Claim Acknowledgment):

```json
{
  "responseId": "uuid",
  "responseType": "277CA",
  "routingId": "original-routing-guid",
  "claimSystemId": "claim-system-b",
  "claimSystemCorrelationId": "ADJ987654",
  "receivedUtc": "2025-10-02T16:45:00Z",
  "responseStatus": "ACCEPTED",
  "responseData": {
    "claimAcknowledgment": {
      "claimId": "CLM123456",
      "statusCode": "1",
      "statusCategoryCode": "A1",
      "entityIdentifierCode": "PR",
      "statusEffectiveDate": "2025-10-02",
      "totalClaimChargeAmount": 2500.00,
      "claimLevelRemarks": []
    }
  },
  "mappingMetadata": {
    "mapperVersion": "1.2",
    "transformationDurationMs": 120,
    "validationErrors": []
  }
}
```

### 4.6 Mapper Implementation Patterns

| Pattern | Use Case | Technology Options |
|---------|----------|-------------------|
| **Azure Function (C#)** | High-volume, low-latency, complex transformations | X12Parser.Net, custom logic |
| **Logic Apps** | Low-code, simple XML/JSON transforms, connector-rich | Built-in XML/JSON transforms, liquid templates |
| **Azure Data Factory Mapping Data Flow** | Batch processing, large file transformations | Visual mapping, expression language |
| **Biztalk/Integration Services (Legacy)** | Existing investment, gradual migration | X12 accelerators, XSLT |

**Recommendation**: **Azure Functions (C#)** for claim system mappers due to:

- Full control over X12 parsing (EDI.Net, X12Parser libraries)
- Complex conditional logic support
- Integration with Service Bus triggers
- Testability and CI/CD compatibility

### 4.7 Mapper Error Handling

| Error Type | Handling Strategy |
|------------|-------------------|
| **Parsing Failure** (Invalid X12 structure) | Log error, write to `mapper-errors` container with original payload, emit alert, dead-letter routing message |
| **Missing Required Field** | Log validation error, attempt partial mapping if configured, else dead-letter |
| **Schema Validation Failure** (Output) | Log error, quarantine output, retry with fallback mapping version |
| **Transformation Exception** | Retry with exponential backoff (3 attempts), then dead-letter |
| **Correlation ID Not Found** (Inbound) | Log orphaned response, store in `orphaned-responses` staging, manual reconciliation runbook |

---

## 5. Connector Architecture

### 5.1 Connector Responsibility

A **Connector** handles:

1. **Outbound**: Delivering transformed data to claim systems (file transfer, API call, database write, queue post)
2. **Inbound**: Retrieving response data from claim systems (file pickup, API polling, database query, queue subscription)
3. **Protocol Management**: Authentication, retries, acknowledgment handling, idempotency

**Connectors are stateless** (connection pooling aside); delivery state tracked in external storage.

### 5.2 Connector Patterns by Claim System Type

#### 5.2.1 Pattern A: File-Based (SFTP/SMB)

**Use Case**: Legacy claim systems expecting batch files (fixed-width, CSV, XML)

**Outbound Flow**:

1. Mapper writes transformed file to staging: `outbound-claims/claim-system-a/pending/<batchId>.xml`
2. Connector Function (timer trigger every 5 min or event-driven) scans `pending/` folder
3. Connector transfers file via SFTP/SMB to claim system inbound folder
4. Claim system processes file, writes response to outbound folder
5. Connector moves processed file to `outbound-claims/claim-system-a/delivered/`
6. Update delivery status table (Azure SQL or Table Storage)

**Inbound Flow**:

1. Connector polls claim system outbound folder (SFTP/SMB) every N minutes
2. Downloads response files to `inbound-responses/claim-system-a/raw/`
3. Triggers Inbound Mapper Function (Blob Created event)
4. Mapper processes response, writes canonical format to Outbound Staging
5. Connector archives response file to `inbound-responses/claim-system-a/processed/`

**Technology**:

- Azure Function with SFTP client library (SSH.NET, WinSCP .NET)
- Azure Logic Apps with SFTP/FTP connectors (low-code option)
- Credentials stored in Key Vault; retrieved via Managed Identity

**Idempotency**: Filename includes `<batchId>` or `<routingId>`; claim system returns same filename in response for correlation

#### 5.2.2 Pattern B: API-Based (REST/SOAP)

**Use Case**: Modern claim systems exposing RESTful or SOAP APIs

**Outbound Flow**:

1. Mapper produces JSON/XML payload
2. Connector Function invokes claim system API endpoint (e.g., `POST /api/v1/claims`)
3. API returns synchronous response with correlation ID or async job ID
4. Connector stores correlation ID in `correlation-store` table (Azure SQL)
5. If async: Connector polls status endpoint or subscribes to webhook

**Inbound Flow**:

1. Claim system POSTs response to platform webhook endpoint (Azure Function HTTP trigger)
2. Webhook validates signature/token (security)
3. Triggers Inbound Mapper Function
4. Mapper correlates via claim system correlation ID → routingId lookup
5. Writes canonical response to Outbound Staging

**Technology**:

- Azure Function (HTTP client, HttpClient factory with Polly resilience)
- API Management (optional facade for rate limiting, caching, monitoring)
- OAuth2/JWT token management via Key Vault + token caching

**Idempotency**: Include `X-Idempotency-Key: <routingId>` header; claim system deduplicates requests

#### 5.2.3 Pattern C: Database-Based (Direct SQL / Stored Procedures)

**Use Case**: Claim systems with shared database access (on-premises SQL Server, Oracle)

**Outbound Flow**:

1. Mapper produces JSON payload
2. Connector Function calls stored procedure `usp_InsertClaim` passing JSON or individual parameters
3. Stored procedure returns claim system internal ID
4. Connector stores mapping: `routingId` → `claimSystemInternalId` in correlation table

**Inbound Flow**:

1. Connector Function (timer trigger) queries claim system staging table for new responses:

   ```sql
   SELECT * FROM ClaimResponses WHERE ProcessedFlag = 0 ORDER BY CreatedDate
   ```

2. Fetches response rows, triggers Inbound Mapper per row
3. Mapper correlates via `claimSystemInternalId` → `routingId` lookup
4. Writes canonical response to Outbound Staging
5. Updates claim system table: `UPDATE ClaimResponses SET ProcessedFlag = 1 WHERE ID = @ID`

**Technology**:

- Azure Function with ADO.NET or Dapper
- Connection string stored in Key Vault
- VNet integration or Azure SQL Managed Instance for on-premises connectivity

**Idempotency**: Use `routingId` as unique key in claim system staging table (unique constraint prevents duplicates)

#### 5.2.4 Pattern D: Message Queue-Based (MSMQ / IBM MQ / Proprietary)

**Use Case**: Legacy claim systems using message queues for async processing

**Outbound Flow**:

1. Mapper produces XML message
2. Connector Function posts message to claim system inbound queue (e.g., MSMQ `ClaimInbound` queue)
3. Claim system processes message, posts response to outbound queue

**Inbound Flow**:

1. Connector Function subscribes to claim system outbound queue (e.g., MSMQ `ClaimOutbound`)
2. Receives response message, triggers Inbound Mapper
3. Mapper correlates via embedded correlation ID (message property or payload field)
4. Writes canonical response to Outbound Staging

**Technology**:

- Azure Function with MSMQ/IBM MQ client libraries (may require Windows hosting or Azure Service Fabric)
- On-premises data gateway for hybrid connectivity
- Service Bus as intermediary (bridge MSMQ → Service Bus via adapter)

**Idempotency**: Message ID property set to `routingId`; claim system deduplicates via message ID

### 5.3 Connector Configuration Repository

**Storage**: `config/connectors/<claim-system-id>/`

**Structure**:

```text
config/connectors/
├── claim-system-a/
│   ├── connector-config.json       # Connection details, retry policy
│   ├── credential-refs.json        # Key Vault secret names
│   └── endpoint-metadata.json      # API endpoints, SFTP paths, DB connection strings (refs)
└── claim-system-b/
    └── ...
```

**Example** (`connector-config.json` for SFTP):

```json
{
  "connectorId": "claim-system-a-sftp",
  "connectorType": "SFTP",
  "connectionDetails": {
    "host": "sftp.claimsystem-a.com",
    "port": 22,
    "username": "platform_user",
    "credentialSecretName": "claim-system-a-sftp-key",
    "inboundPath": "/claims/inbound",
    "outboundPath": "/claims/outbound",
    "archivePath": "/claims/archive"
  },
  "retryPolicy": {
    "maxAttempts": 3,
    "backoffStrategy": "exponential",
    "initialDelayMs": 1000,
    "maxDelayMs": 60000
  },
  "polling": {
    "enabled": true,
    "intervalMinutes": 5,
    "filePattern": "*.xml"
  },
  "monitoring": {
    "alertOnConsecutiveFailures": 3,
    "alertRecipients": ["ops-team@example.com"]
  }
}
```

**Example** (`connector-config.json` for REST API):

```json
{
  "connectorId": "claim-system-b-api",
  "connectorType": "REST",
  "connectionDetails": {
    "baseUrl": "https://api.claimsystem-b.com/v1",
    "authType": "OAuth2",
    "tokenEndpoint": "https://auth.claimsystem-b.com/oauth/token",
    "clientIdSecretName": "claim-system-b-client-id",
    "clientSecretSecretName": "claim-system-b-client-secret",
    "scopes": ["claims.submit", "claims.read"]
  },
  "endpoints": {
    "submitClaim": {
      "method": "POST",
      "path": "/claims",
      "timeout": 30000,
      "idempotencyHeader": "X-Idempotency-Key"
    },
    "getClaimStatus": {
      "method": "GET",
      "path": "/claims/{claimId}/status",
      "timeout": 10000
    }
  },
  "retryPolicy": {
    "maxAttempts": 5,
    "backoffStrategy": "exponential",
    "retryableStatusCodes": [429, 502, 503, 504]
  },
  "webhook": {
    "enabled": true,
    "endpoint": "https://func-edi-webhook-prod.azurewebsites.net/api/ClaimSystemBWebhook",
    "secret": "webhook-secret-name"
  }
}
```

### 5.4 Connector Resilience & Error Handling

| Scenario | Handling Strategy |
|----------|-------------------|
| **Transient Network Error** | Retry with exponential backoff (3-5 attempts), log retry attempts, alert if all retries exhausted |
| **Authentication Failure** | Attempt token refresh (OAuth2), retry once, if still failing alert critical (credentials expired) |
| **Claim System Unavailable** | Circuit breaker pattern (open after 5 consecutive failures, half-open retry after 5 min), alert, fallback to queue backlog |
| **Timeout** | Cancel operation, log timeout, retry with longer timeout (up to max), dead-letter after max attempts |
| **Invalid Response Format** | Log parsing error, quarantine response, alert, manual triage |
| **Duplicate Delivery Detection** | Claim system returns idempotent response (200 OK + "already processed"), log as duplicate, mark successful |

---

## 6. Correlation & Lineage Tracking

### 6.1 Correlation ID Chain

**Purpose**: Trace a transaction from ingestion through claim system processing to X12 response generation

**ID Chain**:

```text
ingestionId (file-level, GUID)
  └─> routingId (ST-level, GUID)
       └─> claimSystemCorrelationId (claim system internal, varies by system)
            └─> responseId (canonical response, GUID)
                 └─> outboundFileId (X12 ack file, GUID)
```

**Storage**:

- **Correlation Store** (Azure SQL):

```sql
CREATE TABLE CorrelationMapping (
    RoutingID UNIQUEIDENTIFIER PRIMARY KEY,
    IngestionID UNIQUEIDENTIFIER NOT NULL,
    ClaimSystemID NVARCHAR(50) NOT NULL,
    ClaimSystemCorrelationID NVARCHAR(255) NOT NULL,
    OutboundMappedUtc DATETIME2 NOT NULL,
    ResponseID UNIQUEIDENTIFIER NULL,
    InboundMappedUtc DATETIME2 NULL,
    OutboundFileID UNIQUEIDENTIFIER NULL,
    FinalizedUtc DATETIME2 NULL,
    Status NVARCHAR(20) NOT NULL, -- PENDING, DELIVERED, RESPONDED, ACKNOWLEDGED, FAILED
    CONSTRAINT UQ_ClaimCorrelation UNIQUE (ClaimSystemID, ClaimSystemCorrelationID)
);

CREATE INDEX IX_Correlation_RoutingID ON CorrelationMapping(RoutingID);
CREATE INDEX IX_Correlation_ClaimSystem ON CorrelationMapping(ClaimSystemID, Status);
```

### 6.2 Lineage Integration with Purview

**Approach**: Extend Purview custom lineage to include mapper/connector hops

**Lineage Graph**:

```text
[Raw EDI File (837)]
  └─> [Routing Message (routingId)]
       └─> [Mapper Transformation (claim-system-a/837-to-xml)]
            └─> [Connector Delivery (SFTP to ClaimSystemA)]
                 └─> [Claim System Processing (external - placeholder asset)]
                      └─> [Inbound Response (ClaimSystemA-XML)]
                           └─> [Inbound Mapper (xml-to-canonical-271)]
                                └─> [Canonical Response (responseId)]
                                     └─> [Outbound X12 File (271)]
```

**Implementation**: Mapper and Connector Functions emit lineage events to Event Hub; scheduled Azure Function processes events and calls Purview REST API to create custom lineage links.

---

## 7. Claim System Onboarding Procedure

### 7.1 Onboarding Checklist

| Step | Task | Responsible Team | Artifacts Produced |
|------|------|------------------|-------------------|
| 1 | Discovery: Identify claim system type, connectivity, data formats | Integration Team | Integration questionnaire |
| 2 | Design mapping rules (X12 → claim system format) | Integration Team + Claim System SME | Mapping rule JSON files |
| 3 | Design reverse mapping rules (claim system → canonical) | Integration Team + Claim System SME | Reverse mapping JSON files |
| 4 | Implement Mapper Function (outbound + inbound) | Development Team | Azure Function code, unit tests |
| 5 | Implement Connector (delivery + retrieval) | Development Team | Azure Function/Logic App, integration tests |
| 6 | Configure Service Bus subscription filter | Platform Team | Subscription rule (IaC) |
| 7 | Store connector config + credentials in Key Vault | Operations Team | Key Vault secrets |
| 8 | Deploy mapper + connector to dev environment | DevOps Team | ARM/Bicep deployment |
| 9 | End-to-end testing with claim system (test data) | Integration Team + Claim System SME | Test results, validation report |
| 10 | Deploy to prod, enable monitoring alerts | DevOps + Platform Team | Production deployment, alert rules |
| 11 | Document runbook (troubleshooting, manual retry) | Operations Team | Runbook in `docs/runbooks/` |

### 7.2 Integration Questionnaire (Template)

**Claim System**: _________________

**Contact SME**: _________________

**Integration Type**: ☐ SFTP  ☐ REST API  ☐ SOAP  ☐ Database  ☐ Message Queue  ☐ Other: _____

**Transaction Types Supported**: ☐ 837  ☐ 270  ☐ 276  ☐ 278  ☐ 834  ☐ 835

**Inbound Data Format**: ☐ X12 (native)  ☐ XML  ☐ JSON  ☐ CSV  ☐ Fixed-width  ☐ Database table  ☐ Other: _____

**Outbound Response Format**: ☐ X12  ☐ XML  ☐ JSON  ☐ CSV  ☐ Database table  ☐ Other: _____

**Authentication Method**: ☐ SSH Key  ☐ Username/Password  ☐ OAuth2  ☐ API Key  ☐ Certificate  ☐ Windows Auth

**Response Timing**: ☐ Synchronous (< 30 sec)  ☐ Asynchronous (webhook)  ☐ Polling required  ☐ Batch (daily/hourly)

**Idempotency Support**: ☐ Yes (describe): _____  ☐ No

**Volume Expectations**: _____ transactions/day, Peak: _____ transactions/hour

**Latency SLA**: Claim system processes claim within _____ (time)

**Error Handling**: How does claim system report errors? _____

**Correlation**: How to correlate response to original request? _____

**Special Requirements**: (e.g., specific header fields, encryption, IP whitelist) _____

---

## 8. Observability & Monitoring

### 8.1 Custom Log Analytics Tables

#### 8.1.1 MapperTransformation_CL

```kusto
// Sample schema
MapperTransformation_CL
| project 
    TimeGenerated,
    RoutingID_g,
    ClaimSystemID_s,
    TransactionSet_s,
    MapperVersion_s,
    Direction_s, // OUTBOUND or INBOUND
    TransformationDurationMs_d,
    InputSizeBytes_d,
    OutputSizeBytes_d,
    ValidationErrors_s, // JSON array
    Status_s // SUCCESS, FAILED, PARTIAL
```

#### 8.1.2 ConnectorDelivery_CL

```kusto
// Sample schema
ConnectorDelivery_CL
| project 
    TimeGenerated,
    RoutingID_g,
    ClaimSystemID_s,
    ConnectorType_s, // SFTP, REST, DATABASE, QUEUE
    Direction_s, // OUTBOUND or INBOUND
    DeliveryDurationMs_d,
    RetryCount_d,
    ClaimSystemCorrelationID_s,
    Status_s, // DELIVERED, FAILED, PENDING_RETRY
    ErrorMessage_s
```

### 8.2 Key Metrics

| Metric | Definition | Target | Alert Threshold |
|--------|-----------|--------|----------------|
| **Mapper Latency** | TransformationDurationMs p95 per claim system | < 500 ms | > 2000 ms for 15 min |
| **Connector Delivery Success Rate** | (Delivered / Total) per claim system | > 99% | < 95% over 30 min |
| **Connector Retry Rate** | (Retries / Total Deliveries) | < 5% | > 15% over 30 min |
| **Response Correlation Failure Rate** | Orphaned responses / Total responses | < 0.5% | > 2% over 1 hr |
| **End-to-End Latency** | RoutingMsg received → Response in Outbound Staging | Varies by claim system | Claim system SLA + 5 min buffer |

### 8.3 Dashboards

**Azure Workbook**: "Claim System Integration Health"

Sections:

1. **Overview**: Total transactions per claim system, success vs. failure split, current backlog
2. **Mapper Performance**: Transformation latency heatmap, validation error breakdown
3. **Connector Health**: Delivery success rate trend, retry attempts per connector, authentication failures
4. **Correlation Status**: Pending correlations aging report, orphaned responses list
5. **Error Deep Dive**: Top error messages, claim system-specific failure patterns

---

## 9. Security Considerations

### 9.1 Credential Management

| Credential Type | Storage | Rotation Strategy | Access Control |
|----------------|---------|-------------------|----------------|
| **SFTP SSH Keys** | Key Vault (secret) | Annual rotation + alert 30 days before expiry | Mapper Function Managed Identity granted `secrets/get` |
| **API Tokens (OAuth2)** | Key Vault (secret) + in-memory cache (60 min TTL) | Token refresh via refresh token; client secret rotation quarterly | Connector Function Managed Identity |
| **Database Connection Strings** | Key Vault (connection string secret) | Password rotation quarterly via automated script | Connector Function Managed Identity + VNet integration |
| **Webhook Secrets** | Key Vault (secret) | Annual rotation + versioning | Webhook Function validates HMAC signature |

### 9.2 Data Encryption

| Stage | Encryption Method |
|-------|------------------|
| **In Transit (Platform → Claim System)** | TLS 1.2+ (SFTP, HTTPS), IPSec for database connections |
| **In Transit (Claim System → Platform)** | TLS 1.2+ (HTTPS, SFTP), validate server certificates |
| **At Rest (Staging Storage)** | Azure Storage encryption (Microsoft-managed keys or CMK) |
| **At Rest (Correlation Store)** | Azure SQL TDE enabled |

### 9.3 Least Privilege

| Component | Permissions |
|-----------|-------------|
| **Outbound Mapper Function** | Read: Raw Storage (specific container), Read: Key Vault secrets (mapper-specific), Write: Staging Storage (claim system outbound folder) |
| **Outbound Connector Function** | Read: Staging Storage (claim system outbound folder), Read: Key Vault secrets (connector-specific), Network: Outbound to claim system (firewall rules) |
| **Inbound Connector Function** | Write: Staging Storage (claim system inbound folder), Read: Key Vault secrets (connector-specific) |
| **Inbound Mapper Function** | Read: Staging Storage (claim system inbound folder), Write: Outbound Staging, Read/Write: Correlation Store |

---

## 10. Testing Strategy

### 10.1 Unit Tests

**Scope**: Mapper transformation logic, mapping rule validation, schema validation

**Tools**: xUnit, NUnit, Moq (mocking X12 parser, storage clients)

**Examples**:

- Given 837P transaction, When outbound mapper applies ClaimSystemA rules, Then output XML matches expected schema
- Given ClaimSystemB JSON response, When inbound mapper parses, Then canonical response includes all required fields

### 10.2 Integration Tests

**Scope**: Mapper + Connector end-to-end, claim system sandbox integration

**Tools**: Azure Functions local runtime, Docker containers (mock claim system endpoints), Testcontainers

**Examples**:

- Given routing message in Service Bus, When mapper + SFTP connector processes, Then file appears in mock SFTP server
- Given mock claim system webhook posts response, When inbound connector + mapper processes, Then canonical response written to Outbound Staging

### 10.3 Contract Tests

**Scope**: Verify claim system API/file format contracts remain stable

**Tools**: Pact (consumer-driven contracts), JSON Schema validators

**Examples**:

- Given ClaimSystemA XML schema v2.3, When inbound mapper parses test file, Then no validation errors
- Given ClaimSystemB REST API contract, When connector invokes endpoint, Then response matches expected schema

### 10.4 Performance Tests

**Scope**: Mapper throughput, connector concurrency limits

**Tools**: Azure Load Testing, JMeter

**Examples**:

- Simulate 1000 routing messages/minute, measure mapper latency p95
- Simulate concurrent SFTP transfers to claim system, identify connection pool limits

---

## 11. Operational Runbooks

### 11.1 Runbook: Mapper Transformation Failure

**Symptom**: `MapperTransformation_CL` shows `Status_s = FAILED` for claim system X

**Diagnosis**:

1. Query Log Analytics for error details:

   ```kusto
   MapperTransformation_CL
   | where Status_s == "FAILED" and ClaimSystemID_s == "claim-system-a"
   | order by TimeGenerated desc
   | take 10
   ```

2. Check `ValidationErrors_s` field for schema validation failures
3. Retrieve original routing message from Service Bus dead-letter queue

**Resolution**:

- If mapping rule error: Update mapping rule JSON in `config/mappers/`, redeploy mapper Function
- If X12 parsing error: Validate raw EDI file structure, check for non-standard segments
- If transient error: Resubmit routing message from DLQ (use Service Bus Explorer)

**Escalation**: If mapping rule fix required, contact Integration Team

### 11.2 Runbook: Connector Delivery Failure

**Symptom**: `ConnectorDelivery_CL` shows `Status_s = FAILED` for claim system Y

**Diagnosis**:

1. Query Log Analytics for error details:

   ```kusto
   ConnectorDelivery_CL
   | where Status_s == "FAILED" and ClaimSystemID_s == "claim-system-b"
   | order by TimeGenerated desc
   | take 10
   ```

2. Check `ErrorMessage_s` for network errors, authentication failures, timeouts
3. Verify claim system availability (ping, telnet to port, HTTP status check)
4. Check Key Vault access logs for credential retrieval failures

**Resolution**:

- If authentication failure: Rotate credentials in Key Vault, update claim system-side if needed
- If network error: Verify firewall rules, VNet integration, claim system IP whitelist
- If timeout: Increase timeout in connector config, investigate claim system performance
- If claim system unavailable: Wait for restoration, connector will retry per policy

**Escalation**: If claim system infrastructure issue, contact Claim System Vendor Support

### 11.3 Runbook: Orphaned Response (Correlation Failure)

**Symptom**: Inbound response received but cannot correlate to original routing message

**Diagnosis**:

1. Query Correlation Store for missing `ClaimSystemCorrelationID`:

   ```sql
   SELECT * FROM CorrelationMapping 
   WHERE ClaimSystemCorrelationID = '<claim-system-id-from-response>'
   ```

2. Check if response arrived before outbound delivery completed (timing issue)
3. Verify claim system correlation ID format matches expected pattern

**Resolution**:

- If timing issue (response faster than expected): Implement delayed retry (wait 5 min, retry correlation lookup)
- If correlation ID format mismatch: Update inbound mapper to handle format variation
- If genuinely orphaned (outbound never delivered): Manual investigation, potentially re-send original transaction

**Escalation**: If frequent occurrence, investigate claim system response timing and correlation ID generation logic

---

## 12. Performance & Scalability Considerations

### 12.1 Throughput Targets

| Claim System | Transaction Volume | Peak Rate | Mapper Throughput | Connector Concurrency |
|--------------|-------------------|-----------|-------------------|----------------------|
| **ClaimSystemA (837 batch)** | 50k claims/day | 200 claims/min | 500 transformations/min | 10 concurrent SFTP transfers |
| **ClaimSystemB (270 real-time)** | 100k inquiries/day | 500 inquiries/min | 1000 transformations/min | 50 concurrent API calls |
| **ClaimSystemC (835 remittance)** | 10k remits/day | 50 remits/min | 200 transformations/min | 5 concurrent database writes |

### 12.2 Scaling Strategies

| Component | Scaling Approach | Trigger |
|-----------|-----------------|---------|
| **Mapper Functions** | Horizontal scale (Function App consumption/premium plan) | CPU > 70% for 10 min OR Queue length > 1000 |
| **Connector Functions** | Horizontal scale + connection pooling | Active connections > 80% of pool OR latency p95 > threshold |
| **Correlation Store** | Azure SQL scale up (DTU/vCore) OR read replicas | DTU > 80% OR query latency > 500ms |
| **Service Bus** | Service Bus Premium (partitioning) OR multiple namespaces | Throttling errors > 5/min |

### 12.3 Batching Strategies

**Scenario**: High-volume claim systems that accept batch files (e.g., 837 batch of 1000 claims)

**Approach**:

1. Accumulate routing messages in staging storage for N minutes (e.g., 10 min) or M messages (e.g., 500)
2. Trigger batch mapper Function (timer or queue depth threshold)
3. Mapper aggregates individual transformations into single batch file
4. Connector delivers batch file to claim system
5. Claim system returns batch response file
6. Inbound mapper splits response, correlates each response to original routing message

**Benefits**: Reduced claim system API calls, improved throughput, lower cost

**Trade-offs**: Increased latency (batching window delay)

---

## 13. Cost Optimization

### 13.1 Cost Drivers

| Component | Estimated Monthly Cost (per claim system) | Optimization Strategies |
|-----------|------------------------------------------|------------------------|
| **Azure Functions (Mapper + Connector)** | $50-200 (consumption plan) | Use Premium plan for high-volume (reserved capacity), optimize cold start |
| **Azure Storage (Staging)** | $10-50 | Lifecycle policies (move to cool after 30 days, delete after 90 days) |
| **Azure SQL (Correlation Store)** | $100-300 (S2-S4) | Rightsize based on actual DTU usage, use read replicas for analytics |
| **Service Bus** | $10-40 (Standard) | Use Premium for high-volume (flat rate), optimize message size |
| **Key Vault** | $5-10 | Minimal (secret operations charged per 10k) |
| **Log Analytics** | $50-150 | Optimize retention (30 days hot, archive rest), filter verbose logs |

**Total Estimated Cost per Claim System**: **$225-750/month** (varies by volume and complexity)

### 13.2 Optimization Recommendations

1. **Batch Processing**: Group transformations to reduce Function invocations
2. **Caching**: Cache mapping rules and claim system metadata in Function memory
3. **Compression**: Compress large files before SFTP transfer
4. **Right-Sizing**: Monitor Function execution time, scale down over-provisioned resources
5. **Reserved Capacity**: For high-volume claim systems, consider Azure Functions Premium plan reserved capacity

---

## 14. Open Issues & Future Enhancements

### 14.1 Open Issues

| Issue | Description | Priority | Target Resolution |
|-------|-------------|----------|------------------|
| **Mapping Rule Versioning** | Need strategy for backward-compatible mapping rule updates without breaking existing flows | High | Q1 2026 |
| **Real-Time Streaming** | Evaluate Azure Stream Analytics for real-time transformations (current: micro-batch) | Medium | Q2 2026 (spike) |
| **Claim System Health Probing** | Automated health checks (ping, API liveness) to predict failures before delivery attempts | Medium | Q1 2026 |
| **Advanced Correlation** | Support fuzzy matching when claim system correlation ID format varies unexpectedly | Low | Q3 2026 |
| **Multi-Tenant Mapper** | Single mapper Function handling multiple claim systems with dynamic rule loading (cost optimization) | Medium | Q2 2026 |

### 14.2 Future Enhancements

- **Visual Mapping Designer**: Low-code UI for defining mapping rules (e.g., Azure Logic Apps designer-like experience)
- **AI-Assisted Mapping**: ML model suggests mappings based on field names/data types
- **Claim System Marketplace**: Pre-built connectors/mappers for popular claim systems (e.g., Change Healthcare, Availity)
- **FHIR Support**: Bidirectional mapping between X12 and FHIR resources (CMS interoperability)
- **Blockchain Audit Trail**: Immutable ledger for correlation events (regulatory compliance)

---

## 15. Appendix A: Technology Stack Recommendations

| Layer | Recommended Technology | Alternative Options |
|-------|----------------------|---------------------|
| **Mapper (Outbound)** | Azure Functions (C#) + EDI.Net / X12Parser.Net | Logic Apps (low-code), Biztalk (legacy migration) |
| **Mapper (Inbound)** | Azure Functions (C#) + Newtonsoft.Json / XDocument | Logic Apps, Azure Data Factory Mapping Data Flow |
| **Connector (SFTP)** | Azure Functions (SSH.NET) | Logic Apps (SFTP connector), Azure Data Factory (copy activity) |
| **Connector (REST API)** | Azure Functions (HttpClient + Polly) | Logic Apps (HTTP connector), Azure API Management (facade) |
| **Connector (Database)** | Azure Functions (Dapper / EF Core) | Logic Apps (SQL connector), Azure Data Factory (copy activity) |
| **Correlation Store** | Azure SQL Database | Cosmos DB (if high write throughput + global distribution needed) |
| **Mapping Rules Storage** | Azure Blob Storage (JSON files) | Azure Cosmos DB (if real-time rule updates needed), Git repo (version control) |
| **Monitoring** | Log Analytics + Azure Monitor | Application Insights (deep APM), Datadog (third-party) |

---

## 16. Appendix B: Sample Mapper Function Code (C# Skeleton)

```csharp
using System;
using System.Threading.Tasks;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Azure.Storage.Blobs;

public class OutboundMapper837
{
    private readonly BlobServiceClient _blobClient;
    private readonly ILogger<OutboundMapper837> _logger;

    public OutboundMapper837(BlobServiceClient blobClient, ILogger<OutboundMapper837> logger)
    {
        _blobClient = blobClient;
        _logger = logger;
    }

    [FunctionName("OutboundMapper837_ClaimSystemA")]
    public async Task Run(
        [ServiceBusTrigger("edi-routing", "sub-claims-system-a", Connection = "ServiceBusConnection")]
        string routingMessage,
        ILogger log)
    {
        var routingMsg = JsonConvert.DeserializeObject<RoutingMessage>(routingMessage);
        log.LogInformation($"Processing routingId: {routingMsg.RoutingId}");

        try
        {
            // 1. Fetch raw EDI file
            var blobContainer = _blobClient.GetBlobContainerClient("raw");
            var blob = blobContainer.GetBlobClient(routingMsg.FileBlobPath);
            var ediContent = await blob.DownloadContentAsync();

            // 2. Parse X12 transaction at stPosition
            var x12Parser = new X12Parser();
            var transaction = x12Parser.ParseTransaction(ediContent.Value.Content.ToString(), routingMsg.StPosition);

            // 3. Apply mapping rules
            var mappingRules = await LoadMappingRules("claim-system-a", "837-to-xml-v1.json");
            var transformedXml = TransformToXml(transaction, mappingRules);

            // 4. Validate output schema
            ValidateXmlSchema(transformedXml, "claim-system-a-schema.xsd");

            // 5. Write to staging
            var stagingContainer = _blobClient.GetBlobContainerClient("outbound-staging");
            var outputBlob = stagingContainer.GetBlobClient($"claim-system-a/pending/{routingMsg.RoutingId}.xml");
            await outputBlob.UploadAsync(new BinaryData(transformedXml));

            // 6. Update correlation store
            await UpdateCorrelationStore(routingMsg.RoutingId, routingMsg.IngestionId, "claim-system-a", routingMsg.RoutingId.ToString());

            // 7. Emit telemetry
            log.LogInformation($"Mapper success: routingId={routingMsg.RoutingId}, outputSize={transformedXml.Length}");
        }
        catch (Exception ex)
        {
            log.LogError(ex, $"Mapper failure: routingId={routingMsg.RoutingId}");
            throw; // Dead-letter message
        }
    }

    private string TransformToXml(X12Transaction transaction, MappingRules rules)
    {
        // Apply mapping rules (field extraction, transformation functions)
        // Return XML string
        throw new NotImplementedException();
    }

    private void ValidateXmlSchema(string xml, string schemaPath)
    {
        // XSD validation
        throw new NotImplementedException();
    }

    private async Task<MappingRules> LoadMappingRules(string claimSystemId, string ruleFile)
    {
        // Load from Blob Storage config/mappers/<claimSystemId>/<ruleFile>
        throw new NotImplementedException();
    }

    private async Task UpdateCorrelationStore(Guid routingId, Guid ingestionId, string claimSystemId, string correlationId)
    {
        // INSERT into Azure SQL CorrelationMapping table
        throw new NotImplementedException();
    }
}
```

---

## 17. Appendix C: Sample Connector Function Code (SFTP Delivery)

```csharp
using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Renci.SshNet;
using Azure.Storage.Blobs;
using Azure.Security.KeyVault.Secrets;

public class SftpConnector
{
    private readonly BlobServiceClient _blobClient;
    private readonly SecretClient _keyVaultClient;
    private readonly ILogger<SftpConnector> _logger;

    [FunctionName("SftpConnector_ClaimSystemA")]
    public async Task Run(
        [TimerTrigger("0 */5 * * * *")] TimerInfo timer, // Every 5 minutes
        ILogger log)
    {
        log.LogInformation("SFTP Connector starting scan...");

        var stagingContainer = _blobClient.GetBlobContainerClient("outbound-staging");
        var pendingBlobs = stagingContainer.GetBlobs(prefix: "claim-system-a/pending/");

        foreach (var blobItem in pendingBlobs)
        {
            try
            {
                // 1. Download file from staging
                var blob = stagingContainer.GetBlobClient(blobItem.Name);
                var content = await blob.DownloadContentAsync();

                // 2. Retrieve SFTP credentials from Key Vault
                var sftpHost = Environment.GetEnvironmentVariable("ClaimSystemA_SFTP_Host");
                var sftpUsername = Environment.GetEnvironmentVariable("ClaimSystemA_SFTP_Username");
                var sftpKeySecret = await _keyVaultClient.GetSecretAsync("claim-system-a-sftp-key");
                var privateKey = new PrivateKeyFile(new MemoryStream(Convert.FromBase64String(sftpKeySecret.Value.Value)));

                // 3. Connect and upload
                using (var sftpClient = new SftpClient(sftpHost, sftpUsername, privateKey))
                {
                    sftpClient.Connect();
                    var remoteFilePath = $"/claims/inbound/{Path.GetFileName(blobItem.Name)}";
                    using (var stream = new MemoryStream(content.Value.Content.ToArray()))
                    {
                        sftpClient.UploadFile(stream, remoteFilePath);
                    }
                    sftpClient.Disconnect();
                }

                // 4. Move to delivered folder
                var deliveredBlob = stagingContainer.GetBlobClient($"claim-system-a/delivered/{Path.GetFileName(blobItem.Name)}");
                await deliveredBlob.StartCopyFromUriAsync(blob.Uri);
                await blob.DeleteAsync();

                // 5. Emit telemetry
                log.LogInformation($"SFTP delivery success: {blobItem.Name}");
            }
            catch (Exception ex)
            {
                log.LogError(ex, $"SFTP delivery failure: {blobItem.Name}");
                // Retry logic handled by timer trigger re-execution
            }
        }
    }
}
```

---

## 18. References

- **Doc 01**: Architecture Specification (Core Platform, Routing Layer)
- **Doc 02**: Data Flow Specification (Ingestion, Validation)
- **Doc 08**: Transaction Routing & Outbound Response Specification (Routing messages, Outbound Orchestrator, Control Number Store)
- **Doc 11**: Event Sourcing Architecture for Enrollment Management (Example destination system)
- **X12 Standards**: ASC X12N HIPAA Implementation Guides (837, 270, 276, 278, 834, 835, 271, 277, 999, TA1)
- **Azure Functions Best Practices**: https://docs.microsoft.com/azure/azure-functions/functions-best-practices
- **EDI.Net Library**: https://github.com/indice-co/EDI.Net
- **SSH.NET Library**: https://github.com/sshnet/SSH.NET

---

**Document Version**: 1.0  
**Last Updated**: October 2, 2025  
**Status**: Draft - Pending Review  
**Next Review**: Q1 2026  
**Owner**: Integration Architecture Team
