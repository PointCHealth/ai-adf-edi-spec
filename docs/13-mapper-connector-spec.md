# Trading Partner Integration Adapters Specification

## 1. Purpose

Define the architecture, integration patterns, data transformation logic, and operational procedures for connecting the Healthcare EDI Platform to **trading partner endpoints** (both external healthcare organizations and internal configured partners) that:

1. Consume routed EDI transactions (837, 270, 276, 278, etc.) in their native or partner-specific formats
2. Generate business response data (271, 277, 277CA, 835) that must be transformed back to standard X12 for acknowledgments

This specification bridges the **core platform routing layer** (see Doc 08) and **heterogeneous trading partner ecosystems** (external and internal) while maintaining loose coupling, traceability, and data integrity.

**Key Architectural Change**: This unified approach treats internal systems (claims, eligibility, enrollment, remittance) as configured trading partners with dedicated integration adapters, eliminating the distinction between "internal destination systems" and "external partners."

---

## 2. Scope

### 2.1 In-Scope

| Category | Items |
|----------|-------|
| **Outbound (Platform → Trading Partner)** | Transformation of routing messages to partner-specific input formats (proprietary XML, JSON, flat files, database inserts, APIs) for both external and internal partners |
| **Inbound (Trading Partner → Platform)** | Normalization of partner responses to canonical intermediate format; assembly into standard X12 acknowledgments/responses |
| **Connector Patterns** | File-based (SFTP/SMB), API-based (REST/SOAP), database-based (direct SQL, stored procedures), message queue-based (Service Bus, MSMQ, proprietary queues) |
| **Trading Partner Types** | External partners (payers, providers, clearinghouses) and internal partners (claims processing, eligibility services, enrollment management, remittance processors) |
| **Error Handling** | Mapping failures, connectivity failures, partner rejections, idempotency, retries, dead-letter handling |
| **Observability** | Lineage tracking (routingId → partner correlation ID → response), latency metrics, transformation audit logs |
| **Security** | Credential management, encryption in transit, least privilege access, PHI handling |

### 2.2 Out-of-Scope (Phase 1)

- Real-time streaming transformations (batch/micro-batch only)
- Custom business logic beyond data transformation (adjudication decisions remain in trading partners)
- Legacy system modernization or replacement
- Master data management (MDM) or canonical member/provider registries (reference data lookups only)
- Trading partner internal modifications (adapters are interface layer only)

---

## 3. Architectural Context

### 3.0 Standardization Benefits

**Decision**: Azure Functions (C#) with centralized mapping rules repository for all Mapper and Connector implementations

**Key Benefits**:

| Benefit Category | Specific Advantages |
|-----------------|-------------------|
| **Development Efficiency** | Single technology stack, shared code libraries, consistent patterns, reduced learning curve |
| **Operational Excellence** | Unified monitoring, standardized debugging, consistent deployment patterns, centralized configuration |
| **Maintainability** | Single codebase paradigm, shared utilities, consistent error handling, unified testing approach |
| **Performance & Scalability** | Optimized for Azure, native Service Bus integration, efficient memory usage, horizontal scaling |
| **Security & Compliance** | Consistent security patterns, unified credential management, standardized encryption, audit trails |
| **Cost Optimization** | Reduced development time, shared infrastructure, optimized resource usage, unified monitoring |

**Mapping Rules Repository Strategy**:

- **Centralized Configuration**: All mapping rules stored in structured Azure Blob Storage
- **Specialized Mappings**: Support for claim system-specific and trading partner-specific transformations
- **Version Management**: Built-in versioning and backward compatibility support
- **Runtime Flexibility**: Dynamic rule loading without code deployment

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
         │  Partner Adapter A       │  │  Partner Adapter B   │  │  Partner         │
         │  (837 Claims)            │  │  (270 Eligibility)   │  │  Adapter N       │
         └─────────────┬────────────┘  └──────────┬───────────┘  └────────┬────────┘
                       │                           │                       │
                       ▼                           ▼                       ▼
         ┌──────────────────────────┐  ┌──────────────────────┐  ┌─────────────────┐
         │  Trading Partner 1       │  │  Trading Partner 2   │  │  Trading         │
         │  (Claims Partner -       │  │  (Eligibility SaaS - │  │  Partner N       │
         │   Internal)              │  │   Internal)          │  │  (External)      │
         └─────────────┬────────────┘  └──────────┬───────────┘  └────────┬────────┘
                       │                           │                       │
                       │ (Response data in partner-specific format)        │
                       ▼                           ▼                       ▼
         ┌──────────────────────────────────────────────────────────────────┐
         │             Response Aggregation & X12 Assembly                  │
         │          (Outbound Orchestrator - see Doc 08)                    │
         └──────────────────────────────────────────────────────────────────┘
```

**Key Principle**: Partner Integration Adapters are **bidirectional interface layers** between the standardized platform and diverse trading partner ecosystems (external and internal). They do NOT own business logic; they translate formats and manage connectivity.

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

**Centralized Storage**: Azure Blob Storage with hierarchical organization for specialized mappings

**Repository Structure**: `config/mappers/`

**Hierarchy Design**:

```text
config/mappers/
├── claim-systems/                      # Claim system specific mappings
│   ├── claim-system-a/
│   │   ├── 837-to-xml-v1.json         # Transaction-specific outbound mapping
│   │   ├── 271-from-json-v1.json      # Transaction-specific inbound mapping
│   │   ├── validation-schema.xsd       # Output schema validation
│   │   ├── enrichment-rules.json       # Conditional logic and business rules
│   │   └── metadata.json              # Version info, compatibility, contacts
│   └── claim-system-b/
│       ├── 270-to-csv-v2.json
│       ├── 271-from-xml-v1.json
│       └── ...
├── trading-partners/                   # Trading partner specific mappings
│   ├── partner-a/
│   │   ├── 837-outbound-customization.json  # Partner-specific field requirements
│   │   ├── 999-inbound-rules.json          # Partner-specific acknowledgment rules
│   │   └── partner-metadata.json           # Contact info, SLAs, special requirements
│   └── partner-b/
│       └── ...
├── shared/                            # Reusable mapping components
│   ├── x12-segment-definitions.json   # Standard X12 segment parsing metadata
│   ├── code-translation-tables.json   # HIPAA codes ↔ proprietary codes
│   ├── common-transformations.json    # Reusable transformation functions
│   └── validation-patterns.json       # Common validation rules
└── templates/                         # Mapping rule templates for new integrations
    ├── sftp-xml-template.json
    ├── rest-api-json-template.json
    └── database-template.json
```

**Specialized Mapping Categories**:

1. **Claim System Mappings**: Format-specific transformations (X12 ↔ XML/JSON/CSV/Database)
2. **Trading Partner Mappings**: Partner-specific field requirements, validation rules, business logic
3. **Shared Components**: Reusable transformation logic, code tables, validation patterns
4. **Templates**: Starting points for new claim system or trading partner integrations

**Enhanced Mapping Rule Format** (`837-to-xml-v1.json`):

```json
{
  "version": "1.0",
  "claimSystemId": "claim-system-a",
  "tradingPartnerId": null,
  "sourceFormat": "X12-837P",
  "targetFormat": "ClaimSystemA-XML-v2.3",
  "compatibility": {
    "minMapperVersion": "1.0",
    "maxMapperVersion": "2.x",
    "x12Versions": ["005010X222A1"]
  },
  "mappings": [
    {
      "targetPath": "Claim.ClaimID",
      "sourceSegment": "CLM",
      "sourceElement": "CLM01",
      "required": true,
      "transformation": null,
      "validation": {
        "pattern": "^[A-Za-z0-9]{1,20}$",
        "maxLength": 20
      }
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
      "transformation": "formatCurrency",
      "validation": {
        "dataType": "decimal",
        "minValue": 0.01,
        "maxValue": 999999.99
      }
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
    },
    {
      "condition": "claimAmount > 10000",
      "action": "addField",
      "targetPath": "Claim.HighValueFlag",
      "value": "true"
    }
  ],
  "customTransformations": [
    {
      "name": "formatCurrency",
      "description": "Format decimal as currency with 2 decimal places",
      "implementation": "CurrencyFormatter"
    },
    {
      "name": "extractDiagnosisList",
      "description": "Extract and format diagnosis codes from HI segments",
      "implementation": "DiagnosisCodeExtractor"
    }
  ]
}
```

**Trading Partner Override Example** (`trading-partners/partner-a/837-outbound-customization.json`):

```json
{
  "version": "1.0",
  "tradingPartnerId": "partner-a",
  "baseMapping": "claim-systems/claim-system-a/837-to-xml-v1.json",
  "overrides": [
    {
      "targetPath": "Claim.PartnerSpecificField",
      "sourceSegment": "CLM",
      "sourceElement": "CLM01",
      "transformation": "partnerAClaimIdFormat",
      "required": true
    }
  ],
  "additionalValidation": [
    {
      "field": "Claim.ClaimID",
      "rule": "mustStartWith",
      "value": "PA"
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

### 4.6 Mapper Implementation Pattern

**Standardized Architecture**: **Azure Functions (C#)** for all claim system mappers

**Technology Stack**:

- **Azure Functions (C#)** - Primary compute platform
- **X12Parser.Net / EDI.Net** - X12 parsing and generation
- **Newtonsoft.Json** - JSON processing for mapping rules and canonical responses
- **Azure Blob Storage** - Mapping rules repository
- **System.Text.Json** - High-performance JSON serialization where applicable

**Benefits of Standardization**:

- **Consistent Development Experience**: Single technology stack reduces learning curve and maintenance overhead
- **Full Control over X12 Processing**: Native C# libraries provide complete access to X12 structure and validation
- **Complex Business Logic Support**: C# enables sophisticated conditional transformations and validation rules
- **High Performance**: Compiled code with optimized X12 parsing libraries
- **Native Azure Integration**: Seamless integration with Service Bus triggers, Key Vault, and Storage
- **Testability**: Unit testing, integration testing, and mocking capabilities
- **CI/CD Compatibility**: Standard deployment pipelines and automated testing
- **Debugging and Monitoring**: Rich debugging experience and Application Insights integration

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

- **Azure Function (C#)** with SSH.NET library for SFTP connectivity
- Credentials stored in Key Vault; retrieved via Managed Identity
- Connection pooling and retry logic built into connector functions

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

- **Azure Function (C#)** with HttpClient and Polly resilience patterns
- OAuth2/JWT token management via Key Vault with in-memory caching
- Built-in retry policies and circuit breaker patterns

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

- **Azure Function (C#)** with ADO.NET or Dapper for database connectivity
- Connection string stored in Key Vault with Managed Identity authentication
- Built-in connection pooling and retry logic

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

- **Azure Function (C#)** with message queue client libraries
- Service Bus as intermediary for hybrid connectivity patterns
- Queue connection management with retry and circuit breaker patterns

**Idempotency**: Message ID property set to `routingId`; claim system deduplicates via message ID

### 5.4 Connector Configuration Repository

**Storage**: `config/connectors/<claim-system-id>/`

**Structure**:

```text
config/connectors/
├── claim-systems/
│   ├── claim-system-a/
│   │   ├── connector-config.json       # Connection details, retry policy
│   │   ├── credential-refs.json        # Key Vault secret names
│   │   └── endpoint-metadata.json      # API endpoints, SFTP paths, DB connection strings (refs)
│   └── claim-system-b/
│       └── ...
└── shared/
    ├── retry-policies.json             # Standard retry policy templates
    ├── monitoring-templates.json       # Standard monitoring configurations
    └── security-templates.json         # Standard security configurations
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
    "alertRecipients": ["edi-platform-team@pointchealth.com"]
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

### 5.5 Connector Implementation with Azure Functions

**Standardized Architecture**: **Azure Functions (C#)** for all connectors

**Technology Stack**:

- **Azure Functions (C#)** - Primary compute platform for all connector types
- **SSH.NET** - SFTP connectivity
- **HttpClient + Polly** - REST API connectivity with resilience patterns
- **ADO.NET / Dapper** - Database connectivity
- **Azure Service Bus SDK** - Message queue integration
- **Azure Key Vault SDK** - Credential management

**Implementation Patterns**:

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

| Step | Task | Responsible | Artifacts Produced |
|------|------|------------------|-------------------|
| 1 | Discovery: Identify claim system type, connectivity, data formats | EDI Platform Engineer | Integration questionnaire |
| 2 | Design mapping rules (X12 → claim system format) | EDI Platform Engineer + Claim System SME | Mapping rule JSON files |
| 3 | Design reverse mapping rules (claim system → canonical) | EDI Platform Engineer + Claim System SME | Reverse mapping JSON files |
| 4 | **Implement Azure Function Mapper** (outbound + inbound, C#) | EDI Platform Engineer | Azure Function code, unit tests, mapping rule loader |
| 5 | **Implement Azure Function Connector** (delivery + retrieval, C#) | EDI Platform Engineer | Azure Function code, integration tests, resilience patterns |
| 6 | Configure Service Bus subscription filter | EDI Platform Engineer | Subscription rule (IaC) |
| 7 | Store mapping rules in Blob Storage + connector config/credentials in Key Vault | EDI Platform Engineer | Mapping rules repository, Key Vault secrets |
| 8 | Deploy mapper + connector Functions to dev environment | EDI Platform Engineer | Bicep deployment, Function App configuration |
| 9 | End-to-end testing with claim system (test data) | EDI Platform Engineer + Claim System SME | Test results, validation report |
| 10 | Deploy to prod, enable monitoring alerts | EDI Platform Team | Production deployment, alert rules |
| 11 | Document runbook (troubleshooting, manual retry) | EDI Platform Engineer | Runbook in `docs/runbooks/` |

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

**Escalation**: If mapping rule fix required, contact EDI Platform Team

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

**Standardized Platform Enhancements** (leveraging Azure Functions + C# foundation):

- **Visual Mapping Designer**: Web-based UI for creating and editing mapping rules (integrated with Azure portal)
- **AI-Assisted Mapping**: ML model suggests field mappings based on X12 structure analysis and historical patterns
- **Mapping Rules Marketplace**: Pre-built mapping rule templates for popular claim systems (Change Healthcare, Availity, BCBS)
- **Real-Time Rule Updates**: Hot-reload capability for mapping rules without Function restart
- **Advanced Transformation Engine**: Support for complex business logic, lookup tables, and cross-segment validation
- **FHIR Integration**: Bidirectional mapping between X12 EDI and FHIR R4 resources (CMS interoperability)
- **Enhanced Trading Partner Support**: Dynamic partner-specific transformations with A/B testing capability
- **Performance Optimization**: Compiled mapping rules, memory-efficient parsing, parallel processing
- **Blockchain Audit Trail**: Immutable ledger for all mapping and transformation events (regulatory compliance)
- **Automated Testing**: AI-generated test cases based on mapping rules and real transaction patterns

---

## 15. Appendix A: Standardized Technology Stack

**Core Architecture Decision**: Azure Functions (C#) for all Mapper and Connector implementations

| Layer | **Standardized Technology** | **Libraries & SDKs** | **Benefits** |
|-------|---------------------------|---------------------|--------------|
| **Mapper (Outbound)** | **Azure Functions (C#)** | EDI.Net / X12Parser.Net, Newtonsoft.Json | Full X12 control, complex logic support, testability |
| **Mapper (Inbound)** | **Azure Functions (C#)** | Newtonsoft.Json, System.Xml.Linq | Consistent parsing, validation, error handling |
| **Connector (SFTP)** | **Azure Functions (C#)** | SSH.NET, Azure Storage SDK | Native SFTP support, connection pooling |
| **Connector (REST API)** | **Azure Functions (C#)** | HttpClient, Polly, Azure Key Vault SDK | Resilience patterns, token management |
| **Connector (Database)** | **Azure Functions (C#)** | Dapper / ADO.NET, Azure SQL SDK | High performance, connection management |
| **Connector (Message Queue)** | **Azure Functions (C#)** | Azure Service Bus SDK, custom queue clients | Unified messaging patterns |
| **Mapping Rules Repository** | **Azure Blob Storage** | JSON configuration files | Version control, hierarchical organization |
| **Correlation Store** | **Azure SQL Database** | Entity Framework Core / Dapper | ACID compliance, high performance queries |
| **Monitoring & Observability** | **Azure Monitor + Log Analytics** | Application Insights SDK | Native Azure integration |

**Eliminated Technologies** (Phase 1):

- Logic Apps (complexity of debugging, limited custom logic)
- Azure Data Factory Mapping Data Flow (batch-only, limited real-time support)
- BizTalk (legacy, high maintenance overhead)
- Multiple technology stacks (operational complexity)

**Development Standards**:

- **Language**: C# 13+ (.NET 9)
- **Function Runtime**: Azure Functions v4 (isolated worker model)
- **Authentication**: Managed Identity for all Azure resources
- **Configuration**: Azure App Configuration for runtime settings
- **Secrets**: Azure Key Vault for credentials and sensitive data
- **Testing**: xUnit for unit tests, TestContainers for integration tests
- **CI/CD**: Azure DevOps with bicep-based infrastructure as code

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

            // 3. Load mapping rules from repository
            var mappingRules = await LoadMappingRules("claim-system-a", "837-to-xml-v1.json");
            
            // 3a. Apply trading partner overrides if applicable
            var partnerOverrides = await LoadPartnerOverrides(routingMsg.TradingPartnerId, "837-outbound-customization.json");
            if (partnerOverrides != null)
            {
                mappingRules = ApplyPartnerOverrides(mappingRules, partnerOverrides);
            }
            
            // 4. Transform using enhanced mapping engine
            var transformedXml = await TransformToXml(transaction, mappingRules, routingMsg);

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

    private async Task<string> TransformToXml(X12Transaction transaction, MappingRules rules, RoutingMessage routingMsg)
    {
        // Enhanced transformation with custom business logic support
        var transformer = new X12ToXmlTransformer(rules);
        return await transformer.TransformAsync(transaction, routingMsg);
    }

    private void ValidateXmlSchema(string xml, string schemaPath)
    {
        // XSD validation with detailed error reporting
        var validator = new XmlSchemaValidator();
        validator.ValidateAgainstSchema(xml, schemaPath);
    }

    private async Task<MappingRules> LoadMappingRules(string claimSystemId, string ruleFile)
    {
        // Load from Blob Storage config/mappers/claim-systems/<claimSystemId>/<ruleFile>
        var configContainer = _blobClient.GetBlobContainerClient("config");
        var ruleBlob = configContainer.GetBlobClient($"mappers/claim-systems/{claimSystemId}/{ruleFile}");
        var content = await ruleBlob.DownloadContentAsync();
        return JsonConvert.DeserializeObject<MappingRules>(content.Value.Content.ToString());
    }

    private async Task<PartnerOverrides> LoadPartnerOverrides(string tradingPartnerId, string overrideFile)
    {
        if (string.IsNullOrEmpty(tradingPartnerId)) return null;
        
        var configContainer = _blobClient.GetBlobContainerClient("config");
        var overrideBlob = configContainer.GetBlobClient($"mappers/trading-partners/{tradingPartnerId}/{overrideFile}");
        
        if (!await overrideBlob.ExistsAsync()) return null;
        
        var content = await overrideBlob.DownloadContentAsync();
        return JsonConvert.DeserializeObject<PartnerOverrides>(content.Value.Content.ToString());
    }

    private MappingRules ApplyPartnerOverrides(MappingRules baseRules, PartnerOverrides overrides)
    {
        // Apply partner-specific field mappings and validation rules
        return new MappingRulesProcessor().ApplyOverrides(baseRules, overrides);
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
**Owner**: EDI Platform Team
