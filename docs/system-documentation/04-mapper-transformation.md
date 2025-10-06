# Mapper & Transformation Layer

## Overview

The Mapper & Transformation Layer bridges the Healthcare EDI Platform's routing layer and heterogeneous trading partner ecosystems (both external partners and internal configured partners). It transforms routed EDI transactions into partner-specific formats and normalizes partner responses back to standard X12 for acknowledgments. All mappers are implemented as **Azure Functions (C#)** with a centralized mapping rules repository for consistency and maintainability.

### Purpose

- Transform EDI transactions (837, 270, 276, 278, etc.) to partner-specific formats (XML, JSON, CSV, database inserts, API payloads)
- Normalize partner responses back to canonical intermediate format
- Support complex business logic and conditional transformations
- Maintain traceability through complete transformation lineage
- Ensure data integrity and validation at each transformation step

### Key Capabilities

| Capability | Description |
|------------|-------------|
| **Bidirectional Transformation** | Outbound (X12 → Partner Format) and Inbound (Partner Format → Canonical JSON) |
| **Centralized Mapping Rules** | Hierarchical Blob Storage repository with claim system and partner-specific rules |
| **Standardized Technology** | Azure Functions (C#) with EDI.Net/X12Parser.Net libraries for all mappers |
| **Trading Partner Abstraction** | Unified model treating internal and external partners identically |
| **Complex Logic Support** | Conditional enrichment, custom transformations, cross-segment validation |
| **Schema Validation** | XSD validation for XML outputs, JSON Schema for JSON outputs |
| **Performance Optimization** | In-memory caching of mapping rules, connection pooling, parallel processing |

---

## Architecture

### System Context

```text
┌───────────────────────────────────────────────────────────────────────┐
│                         Core EDI Platform                              │
│  ┌──────────────┐    ┌──────────────┐    ┌────────────────────┐      │
│  │ ADF Pipeline │───▶│ Router       │───▶│ Service Bus        │      │
│  │ (Validation) │    │ Function     │    │ (edi-routing topic)│      │
│  └──────────────┘    └──────────────┘    └────────┬───────────┘      │
└─────────────────────────────────────────────────┼──────────────────────┘
                                                   │
                        ┌──────────────────────────┼─────────────────────────────┐
                        │                          │                             │
                        ▼                          ▼                             ▼
         ┌──────────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
         │  Mapper Function A       │  │  Mapper Function B   │  │  Mapper Function N   │
         │  (834 Enrollment)        │  │  (270 Eligibility)   │  │  (837 Claims)        │
         │  - Parse X12             │  │  - Parse X12         │  │  - Parse X12         │
         │  - Load mapping rules    │  │  - Load rules        │  │  - Load rules        │
         │  - Apply partner         │  │  - Transform to JSON │  │  - Transform to XML  │
         │    overrides             │  │  - Validate schema   │  │  - Validate schema   │
         │  - Transform to XML      │  │  - Stage output      │  │  - Stage output      │
         │  - Validate schema       │  │                      │  │                      │
         │  - Stage output          │  │                      │  │                      │
         └─────────────┬────────────┘  └──────────┬───────────┘  └────────┬─────────────┘
                       │                           │                       │
                       ▼                           ▼                       ▼
         ┌──────────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
         │  Connector (SFTP/API)    │  │  Connector (REST)    │  │  Connector (Database)│
         │  Delivers to Partner     │  │  Delivers to Partner │  │  Delivers to Partner │
         └─────────────┬────────────┘  └──────────┬───────────┘  └────────┬─────────────┘
                       │                           │                       │
                       ▼                           ▼                       ▼
         ┌──────────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
         │  Trading Partner 1       │  │  Trading Partner 2   │  │  Trading Partner N   │
         │  (Internal System)       │  │  (External Partner)  │  │  (Internal/External) │
         └─────────────┬────────────┘  └──────────┬───────────┘  └────────┬─────────────┘
                       │                           │                       │
                       │ (Response in partner-specific format)             │
                       ▼                           ▼                       ▼
         ┌────────────────────────────────────────────────────────────────────┐
         │              Inbound Mapper Functions                              │
         │  - Receive partner responses (via connectors)                      │
         │  - Parse native format (XML/JSON/CSV/Database)                     │
         │  - Transform to canonical response schema                          │
         │  - Correlate to original routingId                                 │
         │  - Write to Outbound Staging for X12 assembly                      │
         └────────────────────────────────────────────────────────────────────┘
```

**Key Principle**: Mappers are **stateless transformation engines**. All state (correlation IDs, processing status) is externalized to Azure SQL or Blob Storage.

### Data Flow

#### Outbound Transformation (Platform → Trading Partner)

```text
1. [Service Bus Message] → Mapper Function receives routing message
   {
     "routingId": "guid",
     "transactionSet": "837",
     "fileBlobPath": "raw/2025/10/06/file.edi",
     "stPosition": 1234,
     "partnerCode": "PARTNER-A",
     "tradingPartnerId": "partner-a"
   }

2. [Blob Storage Read] → Mapper fetches full EDI file from raw storage
   "raw/2025/10/06/file.edi" → 10MB EDI file

3. [X12 Parsing] → Parse ST segment at specified position
   X12Parser.ParseTransaction(ediContent, stPosition=1234)
   → X12Transaction object (CLM segments, NM1 loops, etc.)

4. [Mapping Rules Load] → Fetch rules from centralized repository
   Base: config/mappers/claim-systems/claim-system-a/837-to-xml-v1.json
   Override: config/mappers/trading-partners/partner-a/837-outbound-customization.json

5. [Transformation] → Apply mapping rules + partner overrides
   X12Transaction + MappingRules → XML/JSON/CSV output
   - Field mappings (CLM01 → Claim.ClaimID)
   - Conditional enrichment (if partnerCode == 'PARTNER-A', add CustomField1)
   - Custom transformations (formatCurrency, extractDiagnosisList)

6. [Schema Validation] → Validate output against partner XSD/JSON Schema
   XmlSchemaValidator.Validate(outputXml, "partner-a-schema.xsd")

7. [Staging Write] → Write transformed output to staging storage
   outbound-staging/partner-a/pending/{routingId}.xml

8. [Correlation Store] → Update Azure SQL correlation mapping
   INSERT CorrelationMapping (RoutingID, PartnerID, PartnerCorrelationID, Status='DELIVERED')

9. [Telemetry] → Emit Application Insights custom event
   MapperTransformation_CL: routingId, duration, inputSize, outputSize, status

10. [Connector Trigger] → Connector function picks up file from staging for delivery
```

#### Inbound Transformation (Trading Partner → Platform)

```text
1. [Connector Receives Response] → Partner response via SFTP pickup, API webhook, or database poll
   Partner XML/JSON/CSV response → inbound-responses/partner-a/raw/{timestamp}.xml

2. [Inbound Mapper Trigger] → Blob Created event triggers mapper function
   BlobTrigger("inbound-responses/partner-a/raw/{filename}")

3. [Parse Native Format] → Parse partner-specific response format
   XDocument.Parse(xml) or JsonConvert.DeserializeObject(json)

4. [Mapping Rules Load] → Fetch inbound mapping rules
   config/mappers/claim-systems/claim-system-a/271-from-xml-v1.json

5. [Transformation] → Map to canonical response schema
   PartnerXml + InboundMappingRules → CanonicalResponse JSON
   {
     "responseId": "guid",
     "responseType": "271",
     "routingId": "original-routing-guid",
     "partnerSystemId": "partner-a",
     "partnerCorrelationId": "PA123456",
     "responseData": { "eligibility": {...} }
   }

6. [Correlation Lookup] → Find original routingId via partner correlation ID
   SELECT RoutingID FROM CorrelationMapping WHERE PartnerCorrelationID = 'PA123456'

7. [Outbound Staging Write] → Write canonical response for X12 assembly
   outbound-staging/responses/{responseId}.json

8. [Archive Partner Response] → Move processed response to archive
   inbound-responses/partner-a/processed/{timestamp}.xml

9. [Telemetry] → Emit Application Insights custom event
   InboundMapper_CL: responseId, duration, correlationStatus, validationErrors

10. [Outbound Orchestrator] → Picks up canonical response and generates X12 (271, 277, 835, etc.)
```

---

## Mapping Rules Repository

### Repository Structure

**Storage Location**: Azure Blob Storage container `config`, hierarchical organization

```text
config/mappers/
├── claim-systems/                      # Claim system specific mappings
│   ├── claim-system-a/
│   │   ├── 837-to-xml-v1.json         # Outbound: X12 837 → Claim System A XML
│   │   ├── 271-from-json-v1.json      # Inbound: Claim System A JSON → Canonical 271
│   │   ├── 277-from-xml-v1.json       # Inbound: Claim System A XML → Canonical 277
│   │   ├── validation-schema.xsd       # Output XSD schema for validation
│   │   ├── enrichment-rules.json       # Conditional business rules
│   │   └── metadata.json               # Version info, compatibility, contacts
│   ├── claim-system-b/
│   │   ├── 270-to-csv-v2.json         # Outbound: X12 270 → CSV format
│   │   ├── 271-from-xml-v1.json       # Inbound: XML → Canonical 271
│   │   └── ...
│   └── claim-system-c/
│       ├── 834-to-json-v1.json        # Outbound: X12 834 → JSON format
│       └── ...
├── trading-partners/                   # Partner-specific customizations
│   ├── partner-a/
│   │   ├── 837-outbound-customization.json  # Partner-specific field requirements
│   │   ├── 999-inbound-rules.json          # Partner-specific acknowledgment rules
│   │   └── partner-metadata.json           # Contact info, SLAs, special requirements
│   ├── partner-b/
│   │   ├── 270-outbound-customization.json
│   │   └── ...
│   └── partner-c/
│       └── ...
├── shared/                             # Reusable mapping components
│   ├── x12-segment-definitions.json    # Standard X12 segment parsing metadata
│   ├── code-translation-tables.json    # HIPAA codes ↔ proprietary codes
│   ├── common-transformations.json     # Reusable transformation functions
│   └── validation-patterns.json        # Common validation rules
└── templates/                          # Mapping rule templates for new integrations
    ├── sftp-xml-template.json
    ├── rest-api-json-template.json
    └── database-template.json
```

### Mapping Rule Format

**Base Mapping Rule** (`claim-systems/claim-system-a/837-to-xml-v1.json`):

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
      "condition": "partnerCode == 'PARTNER-A'",
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

**Trading Partner Override** (`trading-partners/partner-a/837-outbound-customization.json`):

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

### Canonical Response Schema

**Purpose**: Normalize diverse partner responses into platform-standard JSON for X12 assembly.

**Example** (271 Eligibility Response canonical format):

```json
{
  "responseId": "550e8400-e29b-41d4-a716-446655440000",
  "responseType": "271",
  "routingId": "original-routing-guid",
  "partnerSystemId": "partner-a",
  "partnerCorrelationId": "PA123456",
  "receivedUtc": "2025-10-06T14:32:00Z",
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

---

## Azure Function Implementation

### Technology Stack

| Component | Technology | Library/SDK | Purpose |
|-----------|-----------|-------------|---------|
| **Compute Platform** | Azure Functions v4 | Isolated worker model | Serverless compute with auto-scaling |
| **Runtime** | .NET 9 (C#) | System.Text.Json | High-performance transformation logic |
| **X12 Parsing** | EDI.Net / X12Parser.Net | Custom parsers | Parse X12 transactions, extract segments |
| **JSON Processing** | Newtonsoft.Json | Json.NET | Mapping rules deserialization |
| **XML Processing** | System.Xml.Linq | XDocument, XmlSchemaValidator | XML output generation and validation |
| **Storage Access** | Azure Blob Storage SDK | Azure.Storage.Blobs | Mapping rules and file access |
| **Messaging** | Azure Service Bus SDK | Azure.Messaging.ServiceBus | Routing message consumption |
| **Secrets Management** | Azure Key Vault SDK | Azure.Security.KeyVault.Secrets | Credential retrieval |
| **Telemetry** | Application Insights | Microsoft.ApplicationInsights | Custom events and metrics |

### Infrastructure Configuration

**Bicep Module**: `infra/bicep/modules/function-app.bicep` (deployed for each mapper)

```bicep
// Key configurations from main.bicep
var functionApps = [
  {
    name: 'func-mapper-engine-${namingPrefix}'
    displayName: 'Mapper Engine'
    purpose: 'Transform routing messages to partner-specific formats'
  }
  // Additional mapper functions per trading partner or claim system
]

resource functionAppPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: resourceNames.functionAppPlan
  location: location
  sku: {
    name: functionAppSku  // EP1 (Premium), EP2, EP3
  }
  properties: {
    maximumElasticWorkerCount: functionAppMaxInstances  // Auto-scale up to 10
  }
  kind: 'elastic'
}

// Each mapper function deployed with:
// - VNet integration (functionAppsSubnetId)
// - Managed Identity (system-assigned)
// - Application Insights
// - RBAC: Storage Blob Data Contributor, Service Bus Data Receiver
```

**Hosting Plan**: Azure Functions Premium (EP1)
- **vCPU**: 1 vCPU per instance
- **Memory**: 3.5 GB per instance
- **Min Instances**: 1 (always-on for warm start)
- **Max Instances**: 10 (auto-scale based on queue depth and CPU)
- **VNet Integration**: Enabled (private access to Storage and Service Bus)

### Sample Mapper Function Code

**Outbound Mapper** (837 Claims to Partner XML):

```csharp
using System;
using System.Threading.Tasks;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Azure.Storage.Blobs;
using Azure.Messaging.ServiceBus;

namespace EDI.Mappers
{
    public class OutboundMapper837
    {
        private readonly BlobServiceClient _blobClient;
        private readonly ILogger<OutboundMapper837> _logger;
        private readonly IX12Parser _x12Parser;
        private readonly IMappingRulesLoader _rulesLoader;
        private readonly ITransformationEngine _transformationEngine;

        public OutboundMapper837(
            BlobServiceClient blobClient,
            ILogger<OutboundMapper837> logger,
            IX12Parser x12Parser,
            IMappingRulesLoader rulesLoader,
            ITransformationEngine transformationEngine)
        {
            _blobClient = blobClient;
            _logger = logger;
            _x12Parser = x12Parser;
            _rulesLoader = rulesLoader;
            _transformationEngine = transformationEngine;
        }

        [Function("OutboundMapper837_PartnerA")]
        public async Task Run(
            [ServiceBusTrigger("edi-routing", "sub-claims-partner-a", Connection = "ServiceBusConnection")]
            ServiceBusReceivedMessage message,
            ServiceBusMessageActions messageActions)
        {
            var routingMsg = JsonConvert.DeserializeObject<RoutingMessage>(message.Body.ToString());
            _logger.LogInformation($"Processing routingId: {routingMsg.RoutingId}, partner: {routingMsg.PartnerCode}");

            try
            {
                // 1. Fetch raw EDI file from Blob Storage
                var blobContainer = _blobClient.GetBlobContainerClient("raw");
                var blob = blobContainer.GetBlobClient(routingMsg.FileBlobPath);
                var ediContent = await blob.DownloadContentAsync();
                var ediString = ediContent.Value.Content.ToString();

                // 2. Parse X12 transaction at specified position
                var transaction = _x12Parser.ParseTransaction(ediString, routingMsg.StPosition);
                _logger.LogInformation($"Parsed X12 transaction: {transaction.TransactionSetCode}, segments: {transaction.SegmentCount}");

                // 3. Load base mapping rules
                var baseRules = await _rulesLoader.LoadBaseRules(
                    claimSystemId: "claim-system-a",
                    ruleFile: "837-to-xml-v1.json");

                // 4. Apply trading partner overrides (if applicable)
                var partnerRules = baseRules;
                if (!string.IsNullOrEmpty(routingMsg.TradingPartnerId))
                {
                    var overrides = await _rulesLoader.LoadPartnerOverrides(
                        tradingPartnerId: routingMsg.TradingPartnerId,
                        overrideFile: "837-outbound-customization.json");
                    
                    if (overrides != null)
                    {
                        partnerRules = _transformationEngine.ApplyOverrides(baseRules, overrides);
                        _logger.LogInformation($"Applied partner overrides for: {routingMsg.TradingPartnerId}");
                    }
                }

                // 5. Transform to partner XML format
                var transformedXml = await _transformationEngine.TransformToXml(
                    transaction, 
                    partnerRules, 
                    routingMsg);

                // 6. Validate output schema
                var schemaPath = $"config/mappers/claim-systems/claim-system-a/validation-schema.xsd";
                await _transformationEngine.ValidateXmlSchema(transformedXml, schemaPath);

                // 7. Write to staging storage
                var stagingContainer = _blobClient.GetBlobContainerClient("outbound-staging");
                var outputPath = $"partner-a/pending/{routingMsg.RoutingId}.xml";
                var outputBlob = stagingContainer.GetBlobClient(outputPath);
                await outputBlob.UploadAsync(new BinaryData(transformedXml), overwrite: true);

                // 8. Update correlation store (Azure SQL)
                await UpdateCorrelationStore(
                    routingMsg.RoutingId, 
                    routingMsg.IngestionId, 
                    "partner-a", 
                    routingMsg.RoutingId.ToString());

                // 9. Emit custom telemetry
                _logger.LogInformation($"Mapper success: routingId={routingMsg.RoutingId}, outputSize={transformedXml.Length} bytes");
                
                // Complete the message (remove from queue)
                await messageActions.CompleteMessageAsync(message);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Mapper failure: routingId={routingMsg.RoutingId}, error={ex.Message}");
                
                // Dead-letter the message after max retry attempts
                await messageActions.DeadLetterMessageAsync(message, 
                    deadLetterReason: "TransformationFailure",
                    deadLetterErrorDescription: ex.Message);
            }
        }

        private async Task UpdateCorrelationStore(Guid routingId, Guid ingestionId, string partnerId, string partnerCorrelationId)
        {
            // INSERT into Azure SQL CorrelationMapping table
            // Implementation uses Dapper or EF Core
            // Connection string from Key Vault via Managed Identity
        }
    }
}
```

**Inbound Mapper** (Partner XML to Canonical 271):

```csharp
using System;
using System.Threading.Tasks;
using System.Xml.Linq;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Azure.Storage.Blobs;

namespace EDI.Mappers
{
    public class InboundMapper271
    {
        private readonly BlobServiceClient _blobClient;
        private readonly ILogger<InboundMapper271> _logger;
        private readonly IMappingRulesLoader _rulesLoader;
        private readonly ITransformationEngine _transformationEngine;
        private readonly ICorrelationService _correlationService;

        public InboundMapper271(
            BlobServiceClient blobClient,
            ILogger<InboundMapper271> logger,
            IMappingRulesLoader rulesLoader,
            ITransformationEngine transformationEngine,
            ICorrelationService correlationService)
        {
            _blobClient = blobClient;
            _logger = logger;
            _rulesLoader = rulesLoader;
            _transformationEngine = transformationEngine;
            _correlationService = correlationService;
        }

        [Function("InboundMapper271_PartnerA")]
        public async Task Run(
            [BlobTrigger("inbound-responses/partner-a/raw/{filename}", Connection = "StorageConnection")]
            BlobClient blob,
            string filename)
        {
            _logger.LogInformation($"Processing inbound response: {filename}");

            try
            {
                // 1. Download partner response XML
                var responseContent = await blob.DownloadContentAsync();
                var responseXml = responseContent.Value.Content.ToString();

                // 2. Parse partner XML format
                var xmlDoc = XDocument.Parse(responseXml);
                _logger.LogInformation($"Parsed partner XML, root element: {xmlDoc.Root?.Name}");

                // 3. Load inbound mapping rules
                var mappingRules = await _rulesLoader.LoadBaseRules(
                    claimSystemId: "partner-a",
                    ruleFile: "271-from-xml-v1.json");

                // 4. Transform to canonical response format
                var canonicalResponse = await _transformationEngine.TransformToCanonical(
                    xmlDoc, 
                    mappingRules);

                // 5. Correlate to original routingId
                var partnerCorrelationId = canonicalResponse.PartnerCorrelationId;
                var routingId = await _correlationService.LookupRoutingId(
                    partnerId: "partner-a",
                    partnerCorrelationId: partnerCorrelationId);

                if (routingId == Guid.Empty)
                {
                    _logger.LogWarning($"Orphaned response: partnerCorrelationId={partnerCorrelationId}");
                    // Write to orphaned-responses container for manual investigation
                    await WriteOrphanedResponse(canonicalResponse, filename);
                    return;
                }

                canonicalResponse.RoutingId = routingId;

                // 6. Write canonical response to outbound staging
                var stagingContainer = _blobClient.GetBlobContainerClient("outbound-staging");
                var responseJson = JsonConvert.SerializeObject(canonicalResponse, Formatting.Indented);
                var responsePath = $"responses/{canonicalResponse.ResponseId}.json";
                var responseBlob = stagingContainer.GetBlobClient(responsePath);
                await responseBlob.UploadAsync(new BinaryData(responseJson), overwrite: true);

                // 7. Archive processed partner response
                var archiveContainer = _blobClient.GetBlobContainerClient("inbound-responses");
                var archivePath = $"partner-a/processed/{filename}";
                var archiveBlob = archiveContainer.GetBlobClient(archivePath);
                await archiveBlob.StartCopyFromUriAsync(blob.Uri);
                await blob.DeleteAsync();

                // 8. Emit telemetry
                _logger.LogInformation($"Inbound mapper success: responseId={canonicalResponse.ResponseId}, routingId={routingId}");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Inbound mapper failure: filename={filename}, error={ex.Message}");
                // Move to error container for manual review
                await MoveToErrorContainer(blob, filename);
            }
        }

        private async Task WriteOrphanedResponse(CanonicalResponse response, string filename)
        {
            var orphanedContainer = _blobClient.GetBlobContainerClient("orphaned-responses");
            var orphanedPath = $"partner-a/{DateTime.UtcNow:yyyy/MM/dd}/{filename}";
            var orphanedBlob = orphanedContainer.GetBlobClient(orphanedPath);
            var json = JsonConvert.SerializeObject(response, Formatting.Indented);
            await orphanedBlob.UploadAsync(new BinaryData(json), overwrite: true);
        }

        private async Task MoveToErrorContainer(BlobClient sourceBlob, string filename)
        {
            var errorContainer = _blobClient.GetBlobContainerClient("inbound-responses");
            var errorPath = $"partner-a/errors/{filename}";
            var errorBlob = errorContainer.GetBlobClient(errorPath);
            await errorBlob.StartCopyFromUriAsync(sourceBlob.Uri);
            await sourceBlob.DeleteAsync();
        }
    }
}
```

---

## Configuration

### Mapper Function Settings

**Application Settings** (Azure Function App Configuration):

```json
{
  "ServiceBusConnection__fullyQualifiedNamespace": "sb-edi-prod.servicebus.windows.net",
  "StorageConnection__blobServiceUri": "https://edistgprod01.blob.core.windows.net",
  "KeyVaultUri": "https://kv-edi-prod.vault.azure.net",
  "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
  "AZURE_FUNCTIONS_ENVIRONMENT": "Production",
  "APPLICATIONINSIGHTS_CONNECTION_STRING": "<connection-string>",
  
  // Mapper-specific settings
  "MappingRulesContainer": "config",
  "MappingRulesCacheDurationMinutes": "60",
  "OutboundStagingContainer": "outbound-staging",
  "InboundResponsesContainer": "inbound-responses",
  "CorrelationStoreConnectionString": "@Microsoft.KeyVault(SecretUri=https://kv-edi-prod.vault.azure.net/secrets/correlation-store-connection)",
  
  // Performance tuning
  "MaxConcurrentCalls": "100",
  "PrefetchCount": "10",
  "MessageBatchSize": "10"
}
```

### Service Bus Subscription Filters

**Example**: 837 Claims mapper subscribes to filtered messages

```sql
-- Subscription: sub-claims-partner-a
-- SQL Filter Expression
transactionSet LIKE '837%' AND partnerCode = 'PARTNER-A'
```

Configured in Bicep (`modules/service-bus.bicep`):

```bicep
resource subscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-01-01-preview' = {
  name: 'sub-claims-partner-a'
  parent: topic
  properties: {
    lockDuration: 'PT5M'
    maxDeliveryCount: 10
    requiresSession: false
  }
}

resource subscriptionRule 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2022-01-01-preview' = {
  name: 'ClaimsPartnerAFilter'
  parent: subscription
  properties: {
    filterType: 'SqlFilter'
    sqlFilter: {
      sqlExpression: "transactionSet LIKE '837%' AND partnerCode = 'PARTNER-A'"
    }
  }
}
```

---

## Operations

### Monitoring Queries (KQL)

#### 1. Mapper Transformation Latency (p50, p95, p99)

```kusto
customEvents
| where name == "MapperTransformation"
| extend RoutingId = tostring(customDimensions.routingId)
| extend PartnerId = tostring(customDimensions.partnerId)
| extend DurationMs = todouble(customDimensions.transformationDurationMs)
| summarize 
    p50 = percentile(DurationMs, 50),
    p95 = percentile(DurationMs, 95),
    p99 = percentile(DurationMs, 99),
    Count = count()
    by PartnerId, bin(timestamp, 5m)
| order by timestamp desc
```

#### 2. Mapper Failure Rate by Partner

```kusto
customEvents
| where name == "MapperTransformation"
| extend PartnerId = tostring(customDimensions.partnerId)
| extend Status = tostring(customDimensions.status)
| summarize 
    Total = count(),
    Failures = countif(Status == "FAILED"),
    FailureRate = round(100.0 * countif(Status == "FAILED") / count(), 2)
    by PartnerId, bin(timestamp, 15m)
| where FailureRate > 5.0  // Alert if > 5% failure rate
| order by timestamp desc
```

#### 3. Validation Errors by Mapping Rule

```kusto
customEvents
| where name == "MapperTransformation"
| extend ValidationErrors = tostring(customDimensions.validationErrors)
| where isnotempty(ValidationErrors)
| extend ErrorArray = parse_json(ValidationErrors)
| mv-expand Error = ErrorArray
| extend ErrorField = tostring(Error.field)
| extend ErrorMessage = tostring(Error.message)
| summarize ErrorCount = count() by ErrorField, ErrorMessage
| order by ErrorCount desc
| take 20
```

#### 4. Inbound Correlation Success Rate

```kusto
customEvents
| where name == "InboundMapper"
| extend CorrelationStatus = tostring(customDimensions.correlationStatus)
| summarize 
    Total = count(),
    Successful = countif(CorrelationStatus == "SUCCESS"),
    Orphaned = countif(CorrelationStatus == "ORPHANED"),
    OrphanedRate = round(100.0 * countif(CorrelationStatus == "ORPHANED") / count(), 2)
    by bin(timestamp, 30m)
| where OrphanedRate > 1.0  // Alert if > 1% orphaned
| order by timestamp desc
```

#### 5. Mapping Rules Cache Hit Rate

```kusto
customEvents
| where name == "MappingRulesLoad"
| extend CacheHit = tobool(customDimensions.cacheHit)
| summarize 
    Total = count(),
    CacheHits = countif(CacheHit == true),
    CacheHitRate = round(100.0 * countif(CacheHit == true) / count(), 2)
    by bin(timestamp, 15m)
| order by timestamp desc
```

#### 6. Transformation Throughput (Messages/Minute)

```kusto
customEvents
| where name == "MapperTransformation"
| extend PartnerId = tostring(customDimensions.partnerId)
| summarize MessageCount = count() by PartnerId, bin(timestamp, 1m)
| order by timestamp desc, MessageCount desc
```

#### 7. Average Payload Sizes (Input vs Output)

```kusto
customEvents
| where name == "MapperTransformation"
| extend InputSizeKB = todouble(customDimensions.inputSizeBytes) / 1024
| extend OutputSizeKB = todouble(customDimensions.outputSizeBytes) / 1024
| extend CompressionRatio = round(OutputSizeKB / InputSizeKB, 2)
| summarize 
    AvgInputKB = avg(InputSizeKB),
    AvgOutputKB = avg(OutputSizeKB),
    AvgCompressionRatio = avg(CompressionRatio)
    by bin(timestamp, 1h)
| order by timestamp desc
```

#### 8. Partner-Specific Override Usage

```kusto
customEvents
| where name == "MapperTransformation"
| extend PartnerOverrideApplied = tobool(customDimensions.partnerOverrideApplied)
| extend PartnerId = tostring(customDimensions.partnerId)
| summarize 
    TotalTransformations = count(),
    OverridesApplied = countif(PartnerOverrideApplied == true),
    OverrideUsageRate = round(100.0 * countif(PartnerOverrideApplied == true) / count(), 2)
    by PartnerId
| order by OverrideUsageRate desc
```

### Troubleshooting Scenarios

#### Scenario 1: Mapper Transformation Failures

**Symptoms**:
- Service Bus messages in dead-letter queue (DLQ)
- Application Insights shows "MapperTransformation" status = "FAILED"
- Alert triggered: "Mapper failure rate > 5% for 15 minutes"

**Diagnosis Steps**:

1. **Query Application Insights for recent failures**:
   ```kusto
   customEvents
   | where name == "MapperTransformation"
   | where customDimensions.status == "FAILED"
   | extend RoutingId = tostring(customDimensions.routingId)
   | extend ErrorMessage = tostring(customDimensions.errorMessage)
   | extend PartnerId = tostring(customDimensions.partnerId)
   | order by timestamp desc
   | take 20
   ```

2. **Check DLQ messages in Service Bus**:
   ```powershell
   # Connect to Azure
   Connect-AzAccount
   
   # Get DLQ messages
   $namespace = "sb-edi-prod"
   $topic = "edi-routing"
   $subscription = "sub-claims-partner-a"
   
   # View dead-lettered messages
   $dlqMessages = Get-AzServiceBusMessage `
     -ResourceGroupName "rg-edi-prod" `
     -NamespaceName $namespace `
     -TopicName $topic `
     -SubscriptionName $subscription `
     -DeadLetterQueue
   
   $dlqMessages | Select-Object MessageId, DeadLetterReason, DeadLetterErrorDescription
   ```

3. **Examine specific routing message**:
   - Retrieve routingId from DLQ
   - Query raw EDI file from Blob Storage: `raw/{fileBlobPath}`
   - Manually test X12 parsing with EDI.Net library

4. **Check mapping rules validity**:
   - Download mapping rule JSON from `config/mappers/claim-systems/{partnerId}/`
   - Validate JSON schema
   - Check for recent rule changes in Git history

**Resolution Actions**:

| Error Type | Resolution |
|------------|-----------|
| **X12 Parsing Error** | Validate EDI file structure, check for non-standard segments, update parser to handle variations |
| **Mapping Rule Not Found** | Verify mapping rule file exists in Blob Storage, check file path in configuration |
| **Schema Validation Failure** | Update XSD schema to accommodate partner format changes, or fix transformation logic |
| **Missing Required Field** | Add default value in mapping rule, or add conditional logic to skip validation |
| **Blob Storage Access Denied** | Verify Function App Managed Identity has "Storage Blob Data Contributor" role on container |
| **Service Bus Timeout** | Increase lock duration in subscription properties, optimize transformation logic to reduce processing time |

**Remediation Script** (Resubmit DLQ Messages):

```powershell
# Resubmit messages from DLQ to main queue after fixing root cause
$dlqMessages = Get-AzServiceBusMessage `
  -ResourceGroupName "rg-edi-prod" `
  -NamespaceName "sb-edi-prod" `
  -TopicName "edi-routing" `
  -SubscriptionName "sub-claims-partner-a" `
  -DeadLetterQueue

foreach ($msg in $dlqMessages) {
    # Move from DLQ back to main subscription
    Complete-AzServiceBusMessage -Message $msg -DeadLetterQueue $false
    Write-Host "Resubmitted message: $($msg.MessageId)"
}
```

#### Scenario 2: Slow Mapper Performance

**Symptoms**:
- Mapper latency p95 > 2000ms (target: < 500ms)
- Function App CPU utilization > 80%
- Service Bus message backlog growing

**Diagnosis Steps**:

1. **Check Application Insights performance metrics**:
   ```kusto
   requests
   | where name == "OutboundMapper837_PartnerA"
   | summarize 
       AvgDuration = avg(duration),
       P95Duration = percentile(duration, 95),
       Count = count()
       by bin(timestamp, 5m)
   | order by timestamp desc
   ```

2. **Identify performance bottlenecks**:
   ```kusto
   dependencies
   | where operation_Name == "OutboundMapper837_PartnerA"
   | summarize 
       AvgDuration = avg(duration),
       Count = count()
       by target, type
   | order by AvgDuration desc
   ```

3. **Check Function App scaling**:
   - Azure Portal → Function App → Scale out (App Service plan)
   - Verify current instance count vs. max instances
   - Review scale-out metrics (CPU, queue depth)

**Resolution Actions**:

| Bottleneck | Optimization |
|------------|--------------|
| **Blob Storage Downloads** | Implement caching for frequently accessed EDI files, use streaming instead of loading full file into memory |
| **Mapping Rules Load** | Cache mapping rules in Function memory (60 min TTL), lazy load only when changed |
| **X12 Parsing** | Use memory-efficient parsers, consider pre-parsing in ADF pipeline |
| **XML/JSON Serialization** | Use System.Text.Json instead of Newtonsoft.Json where possible, enable streaming serialization |
| **Database Correlation Lookups** | Add indexes on PartnerCorrelationId column, use connection pooling, implement in-memory cache |
| **Insufficient Scaling** | Increase max instances in Function App plan, consider Premium EP2 or EP3 for more resources |

**Performance Tuning Configuration**:

```json
// Function App Application Settings
{
  "FUNCTIONS_WORKER_PROCESS_COUNT": "2",  // Multiple worker processes
  "MaxConcurrentCalls": "100",            // Increase concurrency
  "PrefetchCount": "10",                  // Prefetch Service Bus messages
  "MappingRulesCacheDurationMinutes": "60",  // Cache rules for 1 hour
  "BlobCacheDurationMinutes": "15"        // Cache frequently accessed blobs
}
```

#### Scenario 3: Orphaned Inbound Responses

**Symptoms**:
- Canonical responses written to `orphaned-responses` container
- Correlation lookup failures in Application Insights
- Partner reports successfully sent response, but no X12 acknowledgment generated

**Diagnosis Steps**:

1. **Query orphaned responses**:
   ```kusto
   customEvents
   | where name == "InboundMapper"
   | where customDimensions.correlationStatus == "ORPHANED"
   | extend PartnerCorrelationId = tostring(customDimensions.partnerCorrelationId)
   | extend PartnerId = tostring(customDimensions.partnerId)
   | order by timestamp desc
   | take 50
   ```

2. **Check correlation store for missing mappings**:
   ```sql
   SELECT * FROM CorrelationMapping
   WHERE PartnerID = 'partner-a'
     AND PartnerCorrelationID = 'PA123456'
   ```

3. **Verify outbound delivery completed**:
   ```kusto
   customEvents
   | where name == "ConnectorDelivery"
   | extend PartnerCorrelationId = tostring(customDimensions.partnerCorrelationId)
   | where PartnerCorrelationId == "PA123456"
   | order by timestamp desc
   ```

**Resolution Actions**:

| Root Cause | Resolution |
|------------|-----------|
| **Timing Issue** (response faster than expected) | Implement delayed retry: wait 5 minutes, retry correlation lookup |
| **Correlation ID Format Mismatch** | Update inbound mapper to handle format variations, add logging for correlation ID patterns |
| **Outbound Delivery Never Completed** | Manual investigation required, potentially resend original transaction |
| **Correlation Store Write Failure** | Check database connectivity, verify transaction committed, reprocess outbound mapper |

**Manual Correlation Recovery Script**:

```sql
-- Manually insert correlation mapping if found orphaned
INSERT INTO CorrelationMapping (
    RoutingID, 
    IngestionID, 
    PartnerID, 
    PartnerCorrelationID, 
    OutboundMappedUtc, 
    Status
)
VALUES (
    'original-routing-guid',
    'original-ingestion-guid',
    'partner-a',
    'PA123456',
    '2025-10-06T10:30:00Z',
    'RESPONDED'
);

-- Reprocess orphaned response
-- Move from orphaned-responses back to inbound-responses/raw
-- Inbound mapper will re-trigger via Blob Created event
```

#### Scenario 4: Mapping Rule Validation Failures

**Symptoms**:
- Transformed output fails schema validation
- Validation errors logged in Application Insights
- Partner rejects delivered files due to format issues

**Diagnosis Steps**:

1. **Query validation errors**:
   ```kusto
   customEvents
   | where name == "MapperTransformation"
   | extend ValidationErrors = parse_json(tostring(customDimensions.validationErrors))
   | where array_length(ValidationErrors) > 0
   | extend RoutingId = tostring(customDimensions.routingId)
   | order by timestamp desc
   | take 20
   ```

2. **Download failed output for inspection**:
   - Retrieve from `outbound-staging/{partnerId}/errors/{routingId}.xml`
   - Compare against partner XSD schema
   - Identify specific validation violations

3. **Review mapping rule changes**:
   ```powershell
   # Check Git history for recent changes
   cd c:\repos\ai-adf-edi-spec
   git log --oneline --all -- config/mappers/claim-systems/partner-a/
   ```

**Resolution Actions**:

| Validation Error | Resolution |
|------------------|-----------|
| **Missing Required Element** | Add field mapping in mapping rule JSON, or add default value |
| **Invalid Data Type** | Update transformation function (e.g., formatCurrency), ensure correct type conversion |
| **Pattern Mismatch** | Update validation regex pattern, or fix transformation logic |
| **XSD Schema Update** | Partner changed schema, update local XSD file, adjust mapping rules accordingly |
| **Conditional Logic Error** | Review conditionalEnrichment rules, fix condition expressions |

---

## Security

### RBAC Permissions

| Function Identity | Azure Resource | Role | Justification |
|------------------|----------------|------|---------------|
| **Outbound Mapper** | Storage Account (raw container) | Storage Blob Data Reader | Read EDI files for transformation |
| **Outbound Mapper** | Storage Account (config container) | Storage Blob Data Reader | Read mapping rules |
| **Outbound Mapper** | Storage Account (outbound-staging container) | Storage Blob Data Contributor | Write transformed outputs |
| **Outbound Mapper** | Service Bus (edi-routing topic) | Azure Service Bus Data Receiver | Receive routing messages |
| **Outbound Mapper** | Key Vault | Key Vault Secrets User | Retrieve database connection strings |
| **Inbound Mapper** | Storage Account (inbound-responses container) | Storage Blob Data Contributor | Read partner responses, move to archive |
| **Inbound Mapper** | Storage Account (outbound-staging container) | Storage Blob Data Contributor | Write canonical responses |
| **Inbound Mapper** | Key Vault | Key Vault Secrets User | Retrieve database connection strings |
| **Both Mappers** | Log Analytics Workspace | Monitoring Metrics Publisher | Emit custom telemetry |

**Bicep Configuration** (RBAC assignment example):

```bicep
// Assign Storage Blob Data Reader role to Mapper Function
resource mapperBlobReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(functionApp.id, storageAccount.id, 'BlobDataReader')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')  // Storage Blob Data Reader
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
```

### Data Encryption

| Data Stage | Encryption Method | Key Management |
|------------|------------------|----------------|
| **In Transit (Service Bus)** | TLS 1.2+ | Azure-managed |
| **In Transit (Blob Storage)** | HTTPS only | Azure-managed |
| **At Rest (Blob Storage)** | AES-256 | Azure-managed keys or CMK |
| **At Rest (Correlation Store)** | Transparent Data Encryption (TDE) | Azure-managed keys |
| **Mapping Rules (Blob)** | AES-256 | Azure-managed keys |
| **Application Insights** | Encryption at rest | Microsoft-managed |

### Network Isolation

- **VNet Integration**: Mapper functions deployed with VNet integration, private access to Storage and Service Bus
- **Private Endpoints**: Storage Account and Service Bus accessible only via private endpoints (no public access)
- **NSG Rules**: Function subnet allows outbound to Storage, Service Bus, SQL Database; denies all other outbound

---

## Performance & Scalability

### Throughput Targets

| Partner Type | Transaction Volume | Peak Rate | Mapper Throughput | Scaling Strategy |
|--------------|-------------------|-----------|-------------------|------------------|
| **High-Volume Partner (837)** | 50k claims/day | 200 claims/min | 500 transformations/min | Horizontal scale: 5-10 instances |
| **Real-Time Partner (270)** | 100k inquiries/day | 500 inquiries/min | 1000 transformations/min | Horizontal scale: 10+ instances, prefetch enabled |
| **Batch Partner (835)** | 10k remits/day | 50 remits/min | 200 transformations/min | Fewer instances with batching |

### Scaling Configuration

**Auto-Scale Rules** (Azure Functions Premium):

```json
{
  "scaleOutRules": [
    {
      "metricName": "ServiceBusQueueLength",
      "operator": "GreaterThan",
      "threshold": 1000,
      "scaleOutBy": 2
    },
    {
      "metricName": "CPUPercentage",
      "operator": "GreaterThan",
      "threshold": 70,
      "scaleOutBy": 1
    }
  ],
  "scaleInRules": [
    {
      "metricName": "ServiceBusQueueLength",
      "operator": "LessThan",
      "threshold": 100,
      "scaleInBy": 1,
      "cooldownMinutes": 10
    }
  ],
  "minInstances": 1,
  "maxInstances": 10
}
```

### Optimization Strategies

| Strategy | Implementation | Benefit |
|----------|---------------|---------|
| **Mapping Rules Caching** | In-memory cache with 60-min TTL, lazy reload on version change | 90% reduction in Blob Storage reads |
| **Connection Pooling** | Reuse SQL connections across invocations, configure min/max pool size | 70% reduction in connection overhead |
| **Parallel Processing** | Process multiple messages concurrently (MaxConcurrentCalls=100) | 5x throughput increase |
| **Message Prefetching** | Service Bus prefetch 10 messages ahead | Reduce latency by 30% |
| **Streaming Serialization** | Use streaming for large XML/JSON outputs (> 1MB) | Reduce memory usage by 60% |
| **Compiled Expressions** | Pre-compile conditional enrichment expressions | 40% faster transformation logic |

---

## Testing

### Unit Tests (xUnit)

**Test Scope**: Mapping rule application, transformation logic, validation

```csharp
[Fact]
public async Task OutboundMapper_Should_Transform_837_To_PartnerXml()
{
    // Arrange
    var x12Content = Load837TestFile();
    var mappingRules = LoadMappingRulesFromJson("837-to-xml-v1.json");
    var transformer = new X12ToXmlTransformer(mappingRules);
    var transaction = _x12Parser.ParseTransaction(x12Content, stPosition: 0);

    // Act
    var outputXml = await transformer.TransformAsync(transaction, new RoutingMessage());

    // Assert
    Assert.NotEmpty(outputXml);
    var xmlDoc = XDocument.Parse(outputXml);
    Assert.Equal("ClaimSystemA", xmlDoc.Root.Name.LocalName);
    Assert.NotNull(xmlDoc.Root.Element("Claim")?.Element("ClaimID"));
}

[Fact]
public void MappingRulesLoader_Should_Apply_Partner_Overrides()
{
    // Arrange
    var baseRules = LoadMappingRulesFromJson("837-to-xml-v1.json");
    var overrides = LoadPartnerOverridesFromJson("partner-a-overrides.json");
    var processor = new MappingRulesProcessor();

    // Act
    var mergedRules = processor.ApplyOverrides(baseRules, overrides);

    // Assert
    Assert.Contains(mergedRules.Mappings, m => m.TargetPath == "Claim.PartnerSpecificField");
}
```

### Integration Tests (TestContainers)

**Test Scope**: End-to-end mapper with Azure Storage and Service Bus emulators

```csharp
[Fact]
public async Task MapperFunction_Should_Process_RoutingMessage_EndToEnd()
{
    // Arrange: Start Azurite (Blob Storage emulator) and Service Bus emulator
    var storageContainer = new AzuriteContainer();
    await storageContainer.StartAsync();
    
    var serviceBusContainer = new ServiceBusEmulatorContainer();
    await serviceBusContainer.StartAsync();

    // Setup test data
    var ediFile = Load837TestFile();
    await UploadToBlobStorage(storageContainer, "raw/test.edi", ediFile);
    
    var routingMessage = CreateRoutingMessage("test.edi");
    await SendToServiceBus(serviceBusContainer, "edi-routing", routingMessage);

    // Act: Trigger mapper function
    var function = new OutboundMapper837(/* inject test dependencies */);
    await function.Run(routingMessage, mockMessageActions);

    // Assert: Verify output in staging
    var outputBlob = await DownloadFromBlobStorage(storageContainer, "outbound-staging/partner-a/pending/test.xml");
    Assert.NotEmpty(outputBlob);
    var xmlDoc = XDocument.Parse(outputBlob);
    Assert.NotNull(xmlDoc.Root);
}
```

---

## Code Repositories

### Related Repositories

Based on the GitHub repositories created summary, the mapper functions are organized across these repositories:

| Repository | Purpose | Technologies | Status |
|------------|---------|-------------|--------|
| **edi-mappers** | Transaction mapping functions (270/271, 834, 835, 837) | Azure Functions (C#), EDI.Net, Newtonsoft.Json | Active |
| **edi-platform-core** | Shared libraries (X12Parser, MappingRulesLoader, TransformationEngine) | .NET 9 Class Libraries | Active |
| **ai-adf-edi-spec** | Infrastructure as Code (Bicep), specifications | Bicep, Markdown | Active |

**Repository URLs**:
- Mappers: https://github.com/PointCHealth/edi-mappers
- Shared Libraries: https://github.com/PointCHealth/edi-platform-core
- Specifications: https://github.com/PointCHealth/ai-adf-edi-spec

### Mapper Functions Structure (edi-mappers repository)

```text
edi-mappers/
├── src/
│   ├── OutboundMappers/
│   │   ├── Mapper837/
│   │   │   ├── Function.cs
│   │   │   ├── Mapper837.csproj
│   │   │   └── host.json
│   │   ├── Mapper270/
│   │   ├── Mapper834/
│   │   └── Mapper835/
│   ├── InboundMappers/
│   │   ├── Mapper271/
│   │   ├── Mapper277/
│   │   └── Mapper999/
│   └── Shared/
│       ├── Models/
│       │   ├── RoutingMessage.cs
│       │   ├── CanonicalResponse.cs
│       │   └── MappingRules.cs
│       └── Services/
│           ├── MappingRulesLoader.cs
│           ├── TransformationEngine.cs
│           └── CorrelationService.cs
├── tests/
│   ├── UnitTests/
│   └── IntegrationTests/
├── infra/
│   └── bicep/
│       └── mappers.bicep
└── README.md
```

---

## Cross-References

### Related Documentation

- **[02-processing-pipeline.md](02-processing-pipeline.md)**: ADF pipeline validation that precedes mapper transformation
- **[03-routing-messaging.md](03-routing-messaging.md)**: Service Bus routing layer that triggers mappers
- **[05-outbound-delivery.md](05-outbound-delivery.md)**: Connector layer that delivers transformed outputs
- **[07-database-layer.md](07-database-layer.md)**: Correlation store schema for routingId tracking
- **[11-transaction-flow-834.md](11-transaction-flow-834.md)**: Complete 834 enrollment flow with mapper transformation

### Specification Documents

- **[13-mapper-connector-spec.md](../13-mapper-connector-spec.md)**: Complete mapper/connector specification (1,372 lines)
- **[02-data-flow-spec.md](../02-data-flow-spec.md)**: Routing message schema and validation rules
- **[08-transaction-routing-outbound-spec.md](../08-transaction-routing-outbound-spec.md)**: Correlation store and control numbers

---

**Document Version**: 1.0  
**Last Updated**: October 6, 2025  
**Status**: Complete  
**Next Review**: Q1 2026
