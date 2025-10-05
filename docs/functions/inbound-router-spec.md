# Function Specification: InboundRouter

**Repository:** edi-platform-core  
**Project Path:** `/functions/InboundRouter.Function`  
**Azure Function Name:** `func-edi-inbound-{env}-eastus2`  
**Runtime:** .NET 9 Isolated  
**Last Updated:** 2025-10-05

---

## Overview

The InboundRouter function is the entry point for all incoming EDI files. It performs lightweight envelope parsing to determine transaction type and routing destination, then publishes messages to appropriate Service Bus queues for downstream processing.

---

## Responsibilities

1. **File Detection:** Triggered when EDI files arrive in Azure Storage
2. **Envelope Parsing:** Extract ISA/GS/ST headers to identify transaction type and partners
3. **Validation:** Verify file structure and required control segments
4. **Routing Decision:** Determine target Service Bus queue based on transaction type
5. **Message Publishing:** Send routing message to Service Bus with metadata
6. **Error Handling:** Move malformed files to error container with diagnostics
7. **Telemetry:** Log routing decisions and performance metrics

**Out of Scope:**
- Full X12 parsing (delegated to downstream mappers)
- Business validation (delegated to mappers)
- File transformation (delegated to mappers)

---

## Triggers

### 1. Event Grid Blob Created (Primary)

**Trigger Type:** `EventGridTrigger`  
**Event Type:** `Microsoft.Storage.BlobCreated`  
**Source:** Storage account `stediprodeastus2`, container `raw/inbound/{partnerId}/`

**Configuration:**

```json
{
  "bindings": [
    {
      "type": "eventGridTrigger",
      "name": "eventGridEvent",
      "direction": "in"
    }
  ]
}
```

**Event Schema:**

```json
{
  "topic": "/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{storageAccount}",
  "subject": "/blobServices/default/containers/raw/blobs/inbound/partner001/270_20251005_001.x12",
  "eventType": "Microsoft.Storage.BlobCreated",
  "eventTime": "2025-10-05T14:30:00.0000000Z",
  "id": "unique-event-id",
  "data": {
    "api": "PutBlob",
    "contentType": "text/plain",
    "contentLength": 4567,
    "blobType": "BlockBlob",
    "url": "https://stediprodeastus2.blob.core.windows.net/raw/inbound/partner001/270_20251005_001.x12"
  }
}
```

**Processing Logic:**
1. Extract blob URL from event data
2. Download blob content
3. Parse and route

### 2. HTTP Manual Routing (Secondary)

**Trigger Type:** `HttpTrigger`  
**Route:** `POST /api/route`  
**Auth Level:** `Function` (requires function key)

**Request Body:**

```json
{
  "blobUrl": "https://stediprodeastus2.blob.core.windows.net/raw/inbound/partner001/270_20251005_001.x12",
  "partnerId": "partner001",
  "force": false
}
```

**Use Cases:**
- Manual reprocessing of failed files
- Testing and debugging
- Replay scenarios

---

## Outputs

### 1. Service Bus Message

**Binding Type:** `ServiceBusOutput`  
**Queue Name:** Dynamic (based on transaction type)

**Queue Routing Map:**

| Transaction Type | Service Bus Queue | Downstream Processor |
|-----------------|-------------------|---------------------|
| 270 | `eligibility-mapper-queue` | EligibilityMapper |
| 271 | `eligibility-mapper-queue` | EligibilityMapper |
| 834 | `enrollment-mapper-queue` | EnrollmentMapper |
| 835 | `remittance-mapper-queue` | RemittanceMapper |
| 837 | `claims-mapper-queue` | ClaimsMapper |
| 277 | `claims-mapper-queue` | ClaimsMapper |

**Message Schema:**

```json
{
  "messageId": "guid",
  "correlationId": "guid",
  "timestamp": "2025-10-05T14:30:00Z",
  "eventType": "InboundFileRouted",
  "data": {
    "blobUrl": "https://stediprodeastus2.blob.core.windows.net/raw/inbound/partner001/270_20251005_001.x12",
    "partnerId": "partner001",
    "transactionType": "270",
    "interchangeControlNumber": "000000001",
    "functionalGroupControlNumber": "1",
    "transactionSetControlNumber": "0001",
    "senderId": "SENDER01",
    "receiverId": "RECEIVER01",
    "fileSize": 4567,
    "routingDecision": {
      "queueName": "eligibility-mapper-queue",
      "reason": "Transaction type 270",
      "timestamp": "2025-10-05T14:30:01Z"
    }
  },
  "metadata": {
    "routerVersion": "1.0.0",
    "environment": "prod"
  }
}
```

### 2. Blob Output (Error Cases)

**Container:** `raw/errors/{partnerId}/`  
**Naming Pattern:** `{originalFileName}_error_{timestamp}.json`

**Error File Content:**

```json
{
  "originalFile": {
    "blobUrl": "...",
    "fileName": "270_20251005_001.x12",
    "fileSize": 4567,
    "uploadedAt": "2025-10-05T14:30:00Z"
  },
  "error": {
    "errorType": "ParsingError",
    "message": "Missing ISA segment",
    "timestamp": "2025-10-05T14:30:01Z",
    "stackTrace": "..."
  },
  "diagnostics": {
    "firstBytes": "ISA*00*...",
    "lineCount": 45,
    "detectedDelimiters": {
      "segment": "~",
      "element": "*",
      "subelement": ":"
    }
  }
}
```

---

## Processing Logic

### Main Function Flow

```csharp
[Function("InboundRouter")]
public async Task<RouteResult> Run(
    [EventGridTrigger] EventGridEvent eventGridEvent,
    FunctionContext context)
{
    var logger = context.GetLogger<InboundRouter>();
    var correlationId = Guid.NewGuid();
    
    try
    {
        // 1. Extract blob info from event
        var blobUrl = eventGridEvent.Data["url"].ToString();
        var blobClient = new BlobClient(new Uri(blobUrl), _credential);
        
        // 2. Download blob content
        var content = await DownloadBlobAsync(blobClient);
        
        // 3. Parse envelope
        var envelope = ParseEnvelope(content);
        
        // 4. Validate envelope
        var validationResult = ValidateEnvelope(envelope);
        if (!validationResult.IsValid)
        {
            await HandleValidationError(blobUrl, validationResult);
            return RouteResult.Failed(validationResult.Errors);
        }
        
        // 5. Determine routing
        var queueName = DetermineTargetQueue(envelope.TransactionType);
        
        // 6. Publish to Service Bus
        var message = BuildRoutingMessage(blobUrl, envelope, correlationId);
        await _serviceBusSender.SendMessageAsync(message);
        
        // 7. Log telemetry
        logger.LogInformation(
            "Routed {TransactionType} from {PartnerId} to {QueueName}",
            envelope.TransactionType,
            envelope.PartnerId,
            queueName);
        
        return RouteResult.Success(queueName);
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Failed to route file");
        await HandleProcessingError(blobUrl, ex, correlationId);
        throw;
    }
}
```

### Envelope Parsing Logic

```csharp
private Envelope ParseEnvelope(string x12Content)
{
    // Use HealthcareEDI.X12 library
    var parser = new X12EnvelopeParser();
    
    // Parse only ISA/GS/ST headers (lightweight)
    var interchange = parser.ParseInterchangeHeader(x12Content);
    var functionalGroup = parser.ParseFunctionalGroupHeader(x12Content);
    var transaction = parser.ParseTransactionHeader(x12Content);
    
    return new Envelope
    {
        InterchangeControlNumber = interchange.ControlNumber,
        SenderId = interchange.SenderId,
        ReceiverId = interchange.ReceiverId,
        GroupControlNumber = functionalGroup.ControlNumber,
        TransactionType = transaction.TransactionSetIdentifier,
        TransactionControlNumber = transaction.ControlNumber,
        PartnerId = ExtractPartnerIdFromPath(blobUrl)
    };
}
```

### Routing Decision Logic

```csharp
private string DetermineTargetQueue(string transactionType)
{
    return transactionType switch
    {
        "270" => "eligibility-mapper-queue",
        "271" => "eligibility-mapper-queue",
        "834" => "enrollment-mapper-queue",
        "835" => "remittance-mapper-queue",
        "837" => "claims-mapper-queue",
        "277" => "claims-mapper-queue",
        _ => throw new UnsupportedTransactionTypeException(
            $"Transaction type {transactionType} is not supported")
    };
}
```

---

## Configuration

### Application Settings

```json
{
  "StorageAccount__ConnectionString": "@Microsoft.KeyVault(SecretUri=https://kv-edi-prod.vault.azure.net/secrets/storage-connection-string)",
  "ServiceBus__ConnectionString": "@Microsoft.KeyVault(SecretUri=https://kv-edi-prod.vault.azure.net/secrets/servicebus-connection-string)",
  "ServiceBus__EligibilityQueueName": "eligibility-mapper-queue",
  "ServiceBus__EnrollmentQueueName": "enrollment-mapper-queue",
  "ServiceBus__RemittanceQueueName": "remittance-mapper-queue",
  "ServiceBus__ClaimsQueueName": "claims-mapper-queue",
  "Logging__LogLevel__Default": "Information",
  "Logging__LogLevel__InboundRouter": "Information",
  "Telemetry__InstrumentationKey": "@Microsoft.KeyVault(SecretUri=https://kv-edi-prod.vault.azure.net/secrets/appinsights-key)",
  "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
  "FUNCTIONS_EXTENSION_VERSION": "~4"
}
```

### Host Configuration (host.json)

```json
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond": 20
      }
    }
  },
  "extensions": {
    "serviceBus": {
      "prefetchCount": 0,
      "maxConcurrentCalls": 16,
      "autoCompleteMessages": true
    }
  },
  "functionTimeout": "00:05:00"
}
```

---

## Error Handling

### Error Categories

| Error Type | Action | Retry Strategy |
|-----------|--------|----------------|
| **Blob Not Found** | Log warning, skip | No retry |
| **Parsing Error** | Move to error container | No retry (manual fix needed) |
| **Validation Error** | Move to error container | No retry |
| **Service Bus Unavailable** | Throw exception | Let Event Grid retry (max 24 hours) |
| **Transient Network Error** | Retry with backoff | 3 attempts, exponential backoff |
| **Unknown Transaction Type** | Move to error container | No retry |

### Dead Letter Handling

**Event Grid Subscription:**
- Max delivery attempts: 30
- Event TTL: 24 hours
- Dead letter destination: `raw/deadletter/` container

**Manual Recovery Process:**
1. Investigate error file in error container
2. Fix file or update configuration
3. Re-upload to inbound folder or use HTTP manual routing endpoint

---

## Performance

### Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Latency (P95)** | < 2 seconds | Trigger to Service Bus publish |
| **Throughput** | 1,000 files/hour | Sustained load |
| **Concurrency** | 50 concurrent executions | Max parallel instances |
| **Success Rate** | > 99% | Valid files successfully routed |

### Optimization Strategies

1. **Lightweight Parsing:** Only parse ISA/GS/ST headers, not full transaction
2. **Caching:** Cache Service Bus sender clients
3. **Parallel Processing:** Event Grid naturally distributes load
4. **Blob Streaming:** Use streaming API for large files (not loading entire file to memory)

---

## Monitoring & Telemetry

### Application Insights Metrics

**Custom Metrics:**
- `InboundRouter.FilesProcessed` (counter)
- `InboundRouter.RoutingDuration` (histogram, milliseconds)
- `InboundRouter.FileSize` (histogram, bytes)
- `InboundRouter.ParsingErrors` (counter)
- `InboundRouter.ValidationErrors` (counter)

**Custom Dimensions:**
- `partnerId`
- `transactionType`
- `targetQueue`
- `environment`

### KQL Queries

**Routing throughput by transaction type:**

```kql
customMetrics
| where name == "InboundRouter.FilesProcessed"
| extend transactionType = tostring(customDimensions.transactionType)
| summarize count() by transactionType, bin(timestamp, 1h)
| render timechart
```

**P95 routing latency:**

```kql
customMetrics
| where name == "InboundRouter.RoutingDuration"
| summarize percentile(value, 95) by bin(timestamp, 5m)
| render timechart
```

### Alerts

| Alert Name | Condition | Severity | Action |
|-----------|-----------|----------|--------|
| High Error Rate | Error rate > 5% over 15 min | High | Page on-call engineer |
| Slow Routing | P95 latency > 5 seconds | Medium | Slack notification |
| Service Bus Unavailable | Service Bus publish failures > 10 in 5 min | Critical | Page on-call + auto-escalate |

---

## Testing

### Unit Tests

```csharp
[Fact]
public void ParseEnvelope_ValidX12_ExtractsMetadata()
{
    // Arrange
    var x12Content = File.ReadAllText("TestData/270_sample.x12");
    var parser = new EnvelopeParser();
    
    // Act
    var envelope = parser.ParseEnvelope(x12Content);
    
    // Assert
    Assert.Equal("270", envelope.TransactionType);
    Assert.Equal("SENDER01", envelope.SenderId);
}

[Theory]
[InlineData("270", "eligibility-mapper-queue")]
[InlineData("834", "enrollment-mapper-queue")]
[InlineData("837", "claims-mapper-queue")]
public void DetermineTargetQueue_ReturnsCorrectQueue(
    string transactionType, 
    string expectedQueue)
{
    // Act
    var queue = InboundRouter.DetermineTargetQueue(transactionType);
    
    // Assert
    Assert.Equal(expectedQueue, queue);
}
```

### Integration Tests

```csharp
[Fact]
public async Task EndToEnd_ValidFile_RoutesToServiceBus()
{
    // Arrange: Upload test file to blob storage
    var blobClient = _storageClient.GetBlobClient("raw/inbound/partner001/270_test.x12");
    await blobClient.UploadAsync(File.OpenRead("TestData/270_sample.x12"));
    
    // Act: Wait for Event Grid trigger (max 30 seconds)
    await Task.Delay(TimeSpan.FromSeconds(30));
    
    // Assert: Check Service Bus queue for message
    var message = await _serviceBusReceiver.ReceiveMessageAsync();
    Assert.NotNull(message);
    Assert.Equal("270", message.ApplicationProperties["transactionType"]);
}
```

---

## Dependencies

### NuGet Packages

```xml
<ItemGroup>
  <PackageReference Include="Microsoft.Azure.Functions.Worker" Version="1.21.0" />
  <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.EventGrid" Version="3.3.0" />
  <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http" Version="3.1.0" />
  <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.ServiceBus" Version="5.16.0" />
  <PackageReference Include="Azure.Storage.Blobs" Version="12.19.0" />
  <PackageReference Include="Azure.Messaging.ServiceBus" Version="7.17.0" />
  <PackageReference Include="Azure.Identity" Version="1.11.0" />
</ItemGroup>

<ItemGroup>
  <ProjectReference Include="..\..\src\HealthcareEDI.X12\HealthcareEDI.X12.csproj" />
  <ProjectReference Include="..\..\src\HealthcareEDI.Messaging\HealthcareEDI.Messaging.csproj" />
</ItemGroup>
```

### Azure Resources

- **Storage Account:** Read access to `raw/inbound/{partnerId}/` container
- **Service Bus Namespace:** Send permission to all mapper queues
- **Key Vault:** Read access to connection strings
- **Application Insights:** Write telemetry
- **Managed Identity:** Used for authentication (no connection strings in code)

---

## Security

### Authentication

- **Managed Identity:** Use Azure AD authentication for Storage, Service Bus, Key Vault
- **No Secrets in Code:** All connection strings from Key Vault
- **Function Keys:** HTTP endpoint secured with function key (rotated quarterly)

### Authorization

**RBAC Roles:**
- `Storage Blob Data Reader` on storage account
- `Azure Service Bus Data Sender` on Service Bus namespace
- `Key Vault Secrets User` on Key Vault

### Data Protection

- **No PHI Logging:** Never log file content or PHI elements
- **Encrypted Transit:** TLS 1.2+ for all Azure SDK calls
- **Audit Trail:** Log routing decisions with correlation IDs

---

## Deployment

### CI/CD Workflow

**Trigger:** Push to `main` branch in `/functions/InboundRouter.Function/**`

**Steps:**
1. Build .NET project
2. Run unit tests
3. Publish function package
4. Deploy to dev (auto)
5. Run integration tests in dev
6. Deploy to test (1 approval)
7. Deploy to prod staging slot (2 approvals)
8. Swap to prod (after warmup)

### Deployment Checklist

- [ ] Update Application Settings if new config added
- [ ] Verify Managed Identity has correct RBAC roles
- [ ] Test Event Grid subscription is active
- [ ] Verify Service Bus queues exist
- [ ] Run smoke test after deployment
- [ ] Monitor Application Insights for 15 minutes post-deployment

---

**Last Updated:** 2025-10-05  
**Owner:** Platform Engineering Team  
**Review Schedule:** Quarterly
