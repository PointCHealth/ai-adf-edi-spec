# Partner Configuration Integration Guide

**Document Type**: Implementation Guide  
**Created**: October 5, 2025  
**Target**: EligibilityMapper, InboundRouter, and future mappers  
**Related Docs**: [19-partner-configuration-schema.md](19-partner-configuration-schema.md), [02-azure-function-projects.md](02-azure-function-projects.md)

---

## Overview

This guide provides step-by-step instructions for integrating the **EDI.Configuration** shared library into Azure Functions. This integration enables functions to:

- ✅ Load partner configurations from Azure Blob Storage
- ✅ Validate partner existence and transaction support
- ✅ Access partner-specific endpoints and SLA targets
- ✅ Make routing decisions based on partner type
- ✅ Use partner settings without code changes

---

## Prerequisites

✅ **Required**:
- EDI.Configuration library built and available (completed)
- Azure Storage Account with `partner-configs` container
- Sample partner configurations uploaded to blob storage
- Managed Identity configured with Storage Blob Data Reader role

---

## Integration Steps

### Step 1: Add Package Reference

Add the EDI.Configuration project reference to your function's `.csproj` file.

**Example: EligibilityMapper.Function.csproj**

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <AzureFunctionsVersion>v4</AzureFunctionsVersion>
    <OutputType>Exe</OutputType>
  </PropertyGroup>

  <ItemGroup>
    <!-- Existing project references -->
    <ProjectReference Include="..\..\..\shared\EDI.Core\EDI.Core.csproj" />
    <ProjectReference Include="..\..\..\shared\EDI.X12\EDI.X12.csproj" />
    <ProjectReference Include="..\..\..\shared\EDI.Storage\EDI.Storage.csproj" />
    
    <!-- NEW: Add EDI.Configuration reference -->
    <ProjectReference Include="..\..\..\shared\EDI.Configuration\EDI.Configuration.csproj" />
  </ItemGroup>

  <!-- Package references remain the same -->
</Project>
```

---

### Step 2: Configure Settings

Add partner configuration settings to `appsettings.json` and `local.settings.json`.

**appsettings.json**

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.Azure.Functions": "Warning"
    }
  },
  "StorageOptions": {
    "ConnectionString": "",
    "RawContainer": "raw-files",
    "MappedContainer": "mapped-data"
  },
  "ServiceBusOptions": {
    "ConnectionString": "",
    "QueueName": "eligibility-mapper-queue"
  },
  "MappingOptions": {
    "EnableValidation": true,
    "OutputFormat": "json"
  },
  
  "PartnerConfig": {
    "StorageAccountName": "stedideveasus2",
    "ContainerName": "partner-configs",
    "BlobPrefix": "partners/",
    "CacheDurationSeconds": 300,
    "AutoRefreshEnabled": true,
    "ChangeDetectionIntervalSeconds": 60
  }
}
```

**local.settings.json**

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    
    "StorageOptions__ConnectionString": "DefaultEndpointsProtocol=https;AccountName=stedideveasus2;...",
    "ServiceBusOptions__ConnectionString": "Endpoint=sb://...",
    
    "PartnerConfig__StorageAccountName": "stedideveasus2",
    "PartnerConfig__ContainerName": "partner-configs",
    "PartnerConfig__BlobPrefix": "partners/",
    "PartnerConfig__CacheDurationSeconds": "300",
    "PartnerConfig__AutoRefreshEnabled": "true",
    "PartnerConfig__ChangeDetectionIntervalSeconds": "60"
  }
}
```

---

### Step 3: Register Service in DI

Update `Program.cs` to register the Partner Configuration Service.

**Program.cs (Before)**

```csharp
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Azure.Storage.Blobs;
using EDI.X12;
using EDI.Storage;
using HealthcareEDI.EligibilityMapper.Services;

var builder = FunctionsApplication.CreateBuilder(args);

builder.ConfigureFunctionsWebApplication();

// Azure SDK Clients
builder.Services.AddSingleton(sp =>
{
    var connectionString = builder.Configuration["StorageOptions:ConnectionString"];
    return new BlobServiceClient(connectionString);
});

// EDI Services
builder.Services.AddScoped<IX12Parser, X12Parser>();
builder.Services.AddScoped<BlobStorageService>();

// EligibilityMapper Services
builder.Services.AddScoped<IEligibilityMappingService, EligibilityMappingService>();

// Configuration
builder.Services.Configure<MappingOptions>(
    builder.Configuration.GetSection("MappingOptions"));

// Application Insights
builder.Services
    .AddApplicationInsightsTelemetryWorkerService()
    .ConfigureFunctionsApplicationInsights();

var app = builder.Build();
app.Run();
```

**Program.cs (After - with Partner Config)**

```csharp
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Azure.Storage.Blobs;
using EDI.X12;
using EDI.Storage;
using EDI.Configuration.Extensions;  // NEW
using HealthcareEDI.EligibilityMapper.Services;

var builder = FunctionsApplication.CreateBuilder(args);

builder.ConfigureFunctionsWebApplication();

// Azure SDK Clients
builder.Services.AddSingleton(sp =>
{
    var connectionString = builder.Configuration["StorageOptions:ConnectionString"];
    return new BlobServiceClient(connectionString);
});

// EDI Services
builder.Services.AddScoped<IX12Parser, X12Parser>();
builder.Services.AddScoped<BlobStorageService>();

// Partner Configuration Service (NEW)
builder.Services.AddPartnerConfigService(builder.Configuration);

// EligibilityMapper Services
builder.Services.AddScoped<IEligibilityMappingService, EligibilityMappingService>();

// Configuration
builder.Services.Configure<MappingOptions>(
    builder.Configuration.GetSection("MappingOptions"));

// Application Insights
builder.Services
    .AddApplicationInsightsTelemetryWorkerService()
    .ConfigureFunctionsApplicationInsights();

var app = builder.Build();
app.Run();
```

**Key Changes**:
- ✅ Added `using EDI.Configuration.Extensions;`
- ✅ Added `builder.Services.AddPartnerConfigService(builder.Configuration);`

---

### Step 4: Update Function to Use Partner Config

Inject `IPartnerConfigService` into your function and use it to validate partners and access configuration.

**MapperFunction.cs (Before)**

```csharp
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Azure.Messaging.ServiceBus;
using EDI.X12;
using EDI.Storage;
using HealthcareEDI.EligibilityMapper.Services;
using System.Text.Json;

namespace HealthcareEDI.EligibilityMapper;

public class MapperFunction
{
    private readonly ILogger<MapperFunction> _logger;
    private readonly IX12Parser _parser;
    private readonly IEligibilityMappingService _mappingService;
    private readonly BlobStorageService _storageService;

    public MapperFunction(
        ILogger<MapperFunction> logger,
        IX12Parser parser,
        IEligibilityMappingService mappingService,
        BlobStorageService storageService)
    {
        _logger = logger;
        _parser = parser;
        _mappingService = mappingService;
        _storageService = storageService;
    }

    [Function("ProcessEligibilityTransaction")]
    public async Task ProcessEligibilityTransaction(
        [ServiceBusTrigger("eligibility-mapper-queue", Connection = "ServiceBusOptions:ConnectionString")]
        ServiceBusReceivedMessage message)
    {
        var correlationId = message.CorrelationId ?? Guid.NewGuid().ToString();
        
        _logger.LogInformation(
            "Processing eligibility transaction. CorrelationId: {CorrelationId}",
            correlationId);

        try
        {
            // Deserialize routing message
            var routingMessage = JsonSerializer.Deserialize<RoutingMessage>(message.Body.ToString());
            if (routingMessage == null)
            {
                throw new InvalidOperationException("Invalid routing message format");
            }

            // Download X12 file from blob storage
            var blobStream = await _storageService.DownloadAsync(routingMessage.BlobPath);
            
            // Parse X12 envelope
            var envelope = await _parser.ParseAsync(blobStream);
            
            // Determine transaction type
            var transactionType = envelope.FunctionalGroups[0].Transactions[0].TransactionSetId;
            
            // Map to internal format
            object mappedData;
            string outputFileName;
            
            if (transactionType == "270")
            {
                mappedData = await _mappingService.MapRequestAsync(
                    envelope, 
                    routingMessage.PartnerCode, 
                    routingMessage.BlobPath);
                outputFileName = $"270_{correlationId}_{DateTime.UtcNow:yyyyMMddHHmmss}.json";
            }
            else if (transactionType == "271")
            {
                mappedData = await _mappingService.MapResponseAsync(
                    envelope, 
                    routingMessage.PartnerCode, 
                    routingMessage.BlobPath);
                outputFileName = $"271_{correlationId}_{DateTime.UtcNow:yyyyMMddHHmmss}.json";
            }
            else
            {
                throw new InvalidOperationException($"Unsupported transaction type: {transactionType}");
            }

            // Serialize and upload
            var jsonData = JsonSerializer.Serialize(mappedData, new JsonSerializerOptions
            {
                WriteIndented = true
            });

            var outputPath = $"mapped/{routingMessage.PartnerCode}/{outputFileName}";
            await _storageService.UploadAsync(outputPath, jsonData);

            _logger.LogInformation(
                "Successfully mapped {TransactionType} transaction. Output: {OutputPath}",
                transactionType,
                outputPath);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing eligibility transaction. CorrelationId: {CorrelationId}", correlationId);
            throw;
        }
    }
}
```

**MapperFunction.cs (After - with Partner Config)**

```csharp
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Azure.Messaging.ServiceBus;
using EDI.X12;
using EDI.Storage;
using EDI.Configuration.Services;  // NEW
using EDI.Configuration.Exceptions;  // NEW
using HealthcareEDI.EligibilityMapper.Services;
using System.Text.Json;

namespace HealthcareEDI.EligibilityMapper;

public class MapperFunction
{
    private readonly ILogger<MapperFunction> _logger;
    private readonly IX12Parser _parser;
    private readonly IEligibilityMappingService _mappingService;
    private readonly BlobStorageService _storageService;
    private readonly IPartnerConfigService _partnerConfig;  // NEW

    public MapperFunction(
        ILogger<MapperFunction> logger,
        IX12Parser parser,
        IEligibilityMappingService mappingService,
        BlobStorageService storageService,
        IPartnerConfigService partnerConfig)  // NEW
    {
        _logger = logger;
        _parser = parser;
        _mappingService = mappingService;
        _storageService = storageService;
        _partnerConfig = partnerConfig;  // NEW
    }

    [Function("ProcessEligibilityTransaction")]
    public async Task ProcessEligibilityTransaction(
        [ServiceBusTrigger("eligibility-mapper-queue", Connection = "ServiceBusOptions:ConnectionString")]
        ServiceBusReceivedMessage message)
    {
        var correlationId = message.CorrelationId ?? Guid.NewGuid().ToString();
        
        _logger.LogInformation(
            "Processing eligibility transaction. CorrelationId: {CorrelationId}",
            correlationId);

        try
        {
            // Deserialize routing message
            var routingMessage = JsonSerializer.Deserialize<RoutingMessage>(message.Body.ToString());
            if (routingMessage == null)
            {
                throw new InvalidOperationException("Invalid routing message format");
            }

            // NEW: Validate partner exists and is active
            var partner = await _partnerConfig.GetPartnerAsync(routingMessage.PartnerCode);
            if (partner == null)
            {
                throw new PartnerNotFoundException(routingMessage.PartnerCode);
            }

            if (!partner.IsActive())
            {
                _logger.LogWarning(
                    "Partner {PartnerCode} is not active (status: {Status}). Skipping processing.",
                    routingMessage.PartnerCode,
                    partner.Status);
                return;
            }

            // Download X12 file from blob storage
            var blobStream = await _storageService.DownloadAsync(routingMessage.BlobPath);
            
            // Parse X12 envelope
            var envelope = await _parser.ParseAsync(blobStream);
            
            // Determine transaction type
            var transactionType = envelope.FunctionalGroups[0].Transactions[0].TransactionSetId;

            // NEW: Validate partner supports this transaction type
            if (!partner.SupportsTransaction(transactionType))
            {
                throw new UnsupportedTransactionException(
                    routingMessage.PartnerCode, 
                    transactionType);
            }

            // NEW: Log SLA targets for monitoring
            _logger.LogInformation(
                "Processing {TransactionType} for partner {PartnerCode}. " +
                "SLA targets: Ingestion={IngestionP95}s, Ack999={Ack999}min",
                transactionType,
                routingMessage.PartnerCode,
                partner.Sla.IngestionLatencySecondsP95,
                partner.Sla.Ack999Minutes);
            
            // Map to internal format
            object mappedData;
            string outputFileName;
            
            if (transactionType == "270")
            {
                mappedData = await _mappingService.MapRequestAsync(
                    envelope, 
                    partner,  // NEW: Pass partner config instead of just code
                    routingMessage.BlobPath);
                outputFileName = $"270_{correlationId}_{DateTime.UtcNow:yyyyMMddHHmmss}.json";
            }
            else if (transactionType == "271")
            {
                mappedData = await _mappingService.MapResponseAsync(
                    envelope, 
                    partner,  // NEW: Pass partner config instead of just code
                    routingMessage.BlobPath);
                outputFileName = $"271_{correlationId}_{DateTime.UtcNow:yyyyMMddHHmmss}.json";
            }
            else
            {
                throw new InvalidOperationException($"Unsupported transaction type: {transactionType}");
            }

            // Serialize and upload
            var jsonData = JsonSerializer.Serialize(mappedData, new JsonSerializerOptions
            {
                WriteIndented = true
            });

            var outputPath = $"mapped/{routingMessage.PartnerCode}/{outputFileName}";
            await _storageService.UploadAsync(outputPath, jsonData);

            _logger.LogInformation(
                "Successfully mapped {TransactionType} transaction for {PartnerCode}. Output: {OutputPath}",
                transactionType,
                partner.Name,  // NEW: Use partner name for better logging
                outputPath);
        }
        catch (PartnerNotFoundException ex)
        {
            _logger.LogError(ex, "Partner not found: {PartnerCode}", ex.PartnerCode);
            throw;
        }
        catch (UnsupportedTransactionException ex)
        {
            _logger.LogError(
                ex, 
                "Partner {PartnerCode} does not support transaction type {TransactionType}",
                ex.PartnerCode,
                ex.TransactionType);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing eligibility transaction. CorrelationId: {CorrelationId}", correlationId);
            throw;
        }
    }
}
```

**Key Changes**:
1. ✅ Injected `IPartnerConfigService`
2. ✅ Added partner existence validation
3. ✅ Added active status check
4. ✅ Added transaction type validation
5. ✅ Logged SLA targets for monitoring
6. ✅ Pass full `PartnerConfig` object to mapping service
7. ✅ Added specific exception handling

---

### Step 5: Update Mapping Service Interface (Optional)

If you want to pass the full partner configuration to the mapping service for partner-specific logic, update the interface.

**IEligibilityMappingService.cs (Before)**

```csharp
public interface IEligibilityMappingService
{
    Task<EligibilityRequest> MapRequestAsync(
        X12Envelope envelope, 
        string partnerCode, 
        string blobPath);
        
    Task<EligibilityResponse> MapResponseAsync(
        X12Envelope envelope, 
        string partnerCode, 
        string blobPath);
}
```

**IEligibilityMappingService.cs (After)**

```csharp
using EDI.Configuration.Models;  // NEW

public interface IEligibilityMappingService
{
    Task<EligibilityRequest> MapRequestAsync(
        X12Envelope envelope, 
        PartnerConfig partner,  // Changed from string partnerCode
        string blobPath);
        
    Task<EligibilityResponse> MapResponseAsync(
        X12Envelope envelope, 
        PartnerConfig partner,  // Changed from string partnerCode
        string blobPath);
}
```

**Benefits of passing PartnerConfig**:
- Access to partner name for better logging
- Access to SLA targets for performance monitoring
- Access to routing priority overrides
- Access to custom partner settings in the future

---

### Step 6: Build and Test

**Build the function**:

```powershell
cd C:\repos\edi-platform-core\src\functions\EligibilityMapper
dotnet build
```

**Expected output**:

```
Build succeeded.
    0 Warning(s)
    0 Error(s)
```

**Run locally** (when Docker is available):

```powershell
func start
```

---

## Sample Partner Configurations

Create these sample partner configurations in blob storage for testing.

### PARTNERA (External SFTP)

**Blob Path**: `partner-configs/partners/PARTNERA.json`

```json
{
  "partnerCode": "PARTNERA",
  "name": "Partner A Healthcare",
  "partnerType": "EXTERNAL",
  "status": "active",
  "expectedTransactions": ["270", "271", "837", "835"],
  "dataFlow": {
    "direction": "BIDIRECTIONAL"
  },
  "routingPriorityOverrides": {
    "270": "high",
    "837": "standard"
  },
  "endpoint": {
    "type": "SFTP",
    "sftp": {
      "host": "sftp.partnera.com",
      "port": 22,
      "username": "edi_user",
      "homePath": "/inbound",
      "pgpRequired": true
    }
  },
  "acknowledgments": {
    "expectsTA1": true,
    "expects999": true
  },
  "sla": {
    "ingestionLatencySecondsP95": 30,
    "ack999Minutes": 15,
    "responseLatencyMinutes": 60
  }
}
```

### PARTNERB (External Service Bus)

**Blob Path**: `partner-configs/partners/PARTNERB.json`

```json
{
  "partnerCode": "PARTNERB",
  "name": "Partner B Payer",
  "partnerType": "EXTERNAL",
  "status": "active",
  "expectedTransactions": ["270", "271"],
  "dataFlow": {
    "direction": "BIDIRECTIONAL"
  },
  "routingPriorityOverrides": {},
  "endpoint": {
    "type": "SERVICE_BUS",
    "serviceBus": {
      "topicName": "partnerb-edi-topic",
      "subscriptionName": "eligibility-sub"
    }
  },
  "acknowledgments": {
    "expectsTA1": false,
    "expects999": true
  },
  "sla": {
    "ingestionLatencySecondsP95": 60,
    "ack999Minutes": 30
  }
}
```

### INTERNAL-CLAIMS (Internal System)

**Blob Path**: `partner-configs/partners/INTERNAL-CLAIMS.json`

```json
{
  "partnerCode": "INTERNAL-CLAIMS",
  "name": "Internal Claims Processing System",
  "partnerType": "INTERNAL",
  "status": "active",
  "expectedTransactions": ["837", "277"],
  "dataFlow": {
    "direction": "OUTBOUND"
  },
  "routingPriorityOverrides": {},
  "endpoint": {
    "type": "DATABASE",
    "database": {
      "connectionStringSecretName": "claims-db-connection",
      "stagingTable": "claims_staging"
    }
  },
  "acknowledgments": {
    "expectsTA1": false,
    "expects999": false
  },
  "sla": {
    "ingestionLatencySecondsP95": 10,
    "ack999Minutes": 0,
    "responseLatencyMinutes": 5
  },
  "integration": {
    "adapterType": "EVENT_SOURCING",
    "customAdapterConfig": {
      "eventStoreConnectionString": "claims-eventstore",
      "snapshotInterval": 10
    }
  }
}
```

### TEST001 (Test Partner - Inactive)

**Blob Path**: `partner-configs/partners/TEST001.json`

```json
{
  "partnerCode": "TEST001",
  "name": "Test Partner (Inactive)",
  "partnerType": "EXTERNAL",
  "status": "inactive",
  "expectedTransactions": ["270", "271"],
  "dataFlow": {
    "direction": "BIDIRECTIONAL"
  },
  "routingPriorityOverrides": {},
  "endpoint": {
    "type": "SFTP",
    "sftp": {
      "host": "localhost",
      "port": 2222,
      "username": "test",
      "homePath": "/test",
      "pgpRequired": false
    }
  },
  "acknowledgments": {
    "expectsTA1": true,
    "expects999": true
  },
  "sla": {
    "ingestionLatencySecondsP95": 300,
    "ack999Minutes": 120
  }
}
```

---

## Upload Sample Configurations

**Using Azure CLI**:

```powershell
# Set variables
$storageAccount = "stedideveasus2"
$container = "partner-configs"

# Upload partner configs
az storage blob upload `
  --account-name $storageAccount `
  --container-name $container `
  --name "partners/PARTNERA.json" `
  --file ".\configs\PARTNERA.json" `
  --auth-mode login

az storage blob upload `
  --account-name $storageAccount `
  --container-name $container `
  --name "partners/PARTNERB.json" `
  --file ".\configs\PARTNERB.json" `
  --auth-mode login

az storage blob upload `
  --account-name $storageAccount `
  --container-name $container `
  --name "partners/INTERNAL-CLAIMS.json" `
  --file ".\configs\INTERNAL-CLAIMS.json" `
  --auth-mode login

az storage blob upload `
  --account-name $storageAccount `
  --container-name $container `
  --name "partners/TEST001.json" `
  --file ".\configs\TEST001.json" `
  --auth-mode login
```

**Using Azure Storage Explorer**:
1. Open Azure Storage Explorer
2. Navigate to `stedideveasus2` → `Blob Containers` → `partner-configs`
3. Create folder `partners/`
4. Upload JSON files to `partners/` folder

---

## Testing the Integration

### Test 1: Verify Cache Loading

```csharp
// In a test or startup method
var partnerConfig = serviceProvider.GetRequiredService<IPartnerConfigService>();

// Get all partners
var partners = await partnerConfig.GetAllPartnersAsync();
Console.WriteLine($"Loaded {partners.Count()} partner configurations");

// Get specific partner
var partner = await partnerConfig.GetPartnerAsync("PARTNERA");
Console.WriteLine($"Partner: {partner?.Name}, Status: {partner?.Status}");
```

### Test 2: Verify Transaction Support

```csharp
var partner = await partnerConfig.GetPartnerAsync("PARTNERA");

if (partner != null)
{
    Console.WriteLine($"Supports 270: {partner.SupportsTransaction("270")}");
    Console.WriteLine($"Supports 271: {partner.SupportsTransaction("271")}");
    Console.WriteLine($"Supports 834: {partner.SupportsTransaction("834")}");
}
```

### Test 3: Verify Active Filtering

```csharp
var activePartners = await partnerConfig.GetActivePartnersAsync();
Console.WriteLine($"Active partners: {activePartners.Count()}");

foreach (var p in activePartners)
{
    Console.WriteLine($"  - {p.PartnerCode}: {p.Name} ({p.Status})");
}
```

### Test 4: Verify SLA Targets

```csharp
var partner = await partnerConfig.GetPartnerAsync("PARTNERA");

if (partner != null)
{
    Console.WriteLine($"Ingestion P95: {partner.Sla.IngestionLatencySecondsP95}s");
    Console.WriteLine($"Ack 999: {partner.Sla.Ack999Minutes} minutes");
    Console.WriteLine($"Response: {partner.Sla.ResponseLatencyMinutes} minutes");
}
```

---

## Monitoring and Telemetry

### Application Insights Metrics

Track partner configuration usage with custom metrics:

```csharp
// In MapperFunction.cs
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;

public class MapperFunction
{
    private readonly TelemetryClient _telemetry;

    // ... constructor with TelemetryClient injected

    [Function("ProcessEligibilityTransaction")]
    public async Task ProcessEligibilityTransaction(...)
    {
        var startTime = DateTime.UtcNow;
        
        try
        {
            var partner = await _partnerConfig.GetPartnerAsync(partnerCode);
            
            // Track partner usage
            _telemetry.TrackEvent("PartnerTransactionProcessed", new Dictionary<string, string>
            {
                { "PartnerCode", partner.PartnerCode },
                { "PartnerName", partner.Name },
                { "TransactionType", transactionType },
                { "PartnerType", partner.PartnerType.ToString() }
            });

            // Track SLA compliance
            var processingTime = (DateTime.UtcNow - startTime).TotalSeconds;
            var slaTarget = partner.Sla.IngestionLatencySecondsP95;
            var slaMet = processingTime <= slaTarget;

            _telemetry.TrackMetric("ProcessingTime", processingTime, new Dictionary<string, string>
            {
                { "PartnerCode", partner.PartnerCode },
                { "TransactionType", transactionType },
                { "SLATarget", slaTarget.ToString() },
                { "SLAMet", slaMet.ToString() }
            });
        }
        catch (Exception ex)
        {
            _telemetry.TrackException(ex);
            throw;
        }
    }
}
```

### KQL Queries for Monitoring

**Query 1: Partner transaction volume**

```kusto
customEvents
| where name == "PartnerTransactionProcessed"
| summarize Count=count() by PartnerCode=tostring(customDimensions.PartnerCode), 
                              TransactionType=tostring(customDimensions.TransactionType)
| order by Count desc
```

**Query 2: SLA compliance rate**

```kusto
customMetrics
| where name == "ProcessingTime"
| extend PartnerCode = tostring(customDimensions.PartnerCode)
| extend SLAMet = tobool(customDimensions.SLAMet)
| summarize TotalTransactions=count(), 
            SLAMetCount=countif(SLAMet == true),
            ComplianceRate=round(100.0 * countif(SLAMet == true) / count(), 2)
        by PartnerCode
| order by ComplianceRate asc
```

**Query 3: Cache hit rate**

```kusto
traces
| where message contains "Cache hit" or message contains "Cache miss"
| extend CacheResult = iff(message contains "Cache hit", "Hit", "Miss")
| summarize HitRate=round(100.0 * countif(CacheResult == "Hit") / count(), 2)
| project HitRate
```

---

## Troubleshooting

### Issue 1: Partner Not Found

**Symptoms**: `PartnerNotFoundException` thrown

**Solutions**:
1. Verify blob exists: `az storage blob list --account-name stedideveasus2 --container-name partner-configs --prefix partners/`
2. Check partner code spelling (case-sensitive)
3. Manually refresh cache: `await _partnerConfig.RefreshCacheAsync();`
4. Check Managed Identity has Storage Blob Data Reader role

### Issue 2: Configuration Not Updating

**Symptoms**: Changes to JSON files not reflected in function

**Solutions**:
1. Wait for auto-refresh interval (60 seconds default)
2. Manually trigger refresh: `await _partnerConfig.RefreshCacheAsync();`
3. Check auto-refresh enabled: `PartnerConfig__AutoRefreshEnabled=true`
4. Restart function app to clear cache

### Issue 3: Authentication Failed

**Symptoms**: `StorageConnectionException` thrown

**Solutions**:
1. Verify Managed Identity enabled on function app
2. Verify Storage Blob Data Reader role assigned to Managed Identity
3. Check storage account name correct: `PartnerConfig__StorageAccountName`
4. For local dev, ensure logged in: `az login`

### Issue 4: Invalid JSON

**Symptoms**: Partner config returns null despite blob existing

**Solutions**:
1. Validate JSON syntax: `Get-Content PARTNERA.json | ConvertFrom-Json`
2. Check required fields present (partnerCode, name, partnerType, status, etc.)
3. Check enum values match exactly (EXTERNAL, INTERNAL, active, inactive, etc.)
4. Review function logs for deserialization errors

---

## Performance Optimization

### Cache Tuning

Adjust cache settings based on your workload:

```json
{
  "PartnerConfig": {
    "CacheDurationSeconds": 600,  // Increase to 10 minutes for less frequent changes
    "ChangeDetectionIntervalSeconds": 120  // Check every 2 minutes
  }
}
```

### Preload Cache

Preload cache at startup for faster first requests:

```csharp
// In Program.cs after app.Build()
using (var scope = app.Services.CreateScope())
{
    var partnerConfig = scope.ServiceProvider.GetRequiredService<IPartnerConfigService>();
    await partnerConfig.GetAllPartnersAsync();  // Preload cache
}

app.Run();
```

### Disable Auto-Refresh (High-Volume Scenarios)

For extremely high-volume scenarios where timer overhead matters:

```json
{
  "PartnerConfig": {
    "AutoRefreshEnabled": false
  }
}
```

Manually refresh on a schedule using a Timer trigger function.

---

## Next Steps

1. ✅ Add EDI.Configuration project reference
2. ✅ Configure settings in appsettings.json
3. ✅ Register service in Program.cs
4. ✅ Update MapperFunction to use partner config
5. ✅ Upload sample partner configurations
6. ✅ Build and test locally
7. ⏳ Deploy to Azure Dev environment
8. ⏳ Configure Managed Identity permissions
9. ⏳ Run end-to-end integration tests
10. ⏳ Monitor with Application Insights

---

## Related Documents

- [EDI.Configuration README](../../../edi-platform-core/shared/EDI.Configuration/README.md)
- [Partner Configuration Overview](../../../edi-platform-core/shared/EDI.Configuration/PARTNER_CONFIG_OVERVIEW.md)
- [Partner Configuration Schema](19-partner-configuration-schema.md)
- [Partner Onboarding Playbook](12-partner-onboarding-playbook.md)
- [EligibilityMapper Implementation](../docs/functions/eligibility-mapper-implementation.md)

---

**Status**: ✅ Ready for Implementation  
**Estimated Integration Time**: 2-3 hours per function
