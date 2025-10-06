# InboundRouter Function Configuration

## Overview

This document describes all configuration options for the InboundRouter Azure Function, including application settings, environment variables, and configuration files.

---

## Configuration Models

### 1. RoutingOptions

Controls the core routing behavior and retry logic.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `RoutingTopicName` | string | `"transaction-routing"` | Service Bus topic name for routing messages |
| `MaxRetryAttempts` | int | `3` | Maximum number of retry attempts for failed routing |
| `RetryDelay` | TimeSpan | `00:00:05` | Delay between retry attempts |
| `TransactionTypeMapping` | Dictionary<string,string> | `{}` | Maps transaction codes to friendly names |

**Example Configuration:**

```json
{
  "RoutingOptions": {
    "RoutingTopicName": "transaction-routing",
    "MaxRetryAttempts": 3,
    "RetryDelay": "00:00:05",
    "TransactionTypeMapping": {
      "270": "Eligibility Request",
      "271": "Eligibility Response",
      "834": "Enrollment",
      "835": "Remittance",
      "837": "Claim"
    }
  }
}
```

---

### 2. StorageOptions

Configures Azure Storage account connections and container names.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `ConnectionString` | string | `""` | Storage account connection string (use Key Vault reference) |
| `InboundContainerName` | string | `"inbound"` | Container for raw inbound files |
| `ProcessedContainerName` | string | `"processed"` | Container for successfully routed files |
| `ArchiveContainerName` | string | `"archive"` | Container for long-term archive |
| `ErrorContainerName` | string | `"error"` | Container for files that failed routing |
| `DeadLetterContainerName` | string | `"deadletter"` | Container for Event Grid dead letters |
| `ErrorRetentionDays` | int | `30` | Days to retain files in error container |
| `EnableSoftDelete` | bool | `true` | Enable soft delete for blobs |
| `SoftDeleteRetentionDays` | int | `7` | Soft delete retention period |

**Example Configuration:**

```json
{
  "StorageOptions": {
    "ConnectionString": "@Microsoft.KeyVault(SecretUri=https://kv-edi-prod.vault.azure.net/secrets/storage-connection)",
    "InboundContainerName": "inbound",
    "ProcessedContainerName": "processed",
    "ArchiveContainerName": "archive",
    "ErrorContainerName": "error",
    "DeadLetterContainerName": "deadletter",
    "ErrorRetentionDays": 30,
    "EnableSoftDelete": true,
    "SoftDeleteRetentionDays": 7
  }
}
```

---

### 3. ServiceBusOptions

Configures Service Bus connections and queue/topic names.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `ConnectionString` | string | `""` | Service Bus connection string (use Key Vault reference) |
| `RoutingTopicName` | string | `"transaction-routing"` | Topic name for routing messages |
| `EligibilityQueueName` | string | `"eligibility-mapper-queue"` | Queue for 270/271 transactions |
| `EnrollmentQueueName` | string | `"enrollment-mapper-queue"` | Queue for 834 transactions |
| `RemittanceQueueName` | string | `"remittance-mapper-queue"` | Queue for 835 transactions |
| `ClaimsQueueName` | string | `"claims-mapper-queue"` | Queue for 837 transactions |
| `OutboundReadyQueueName` | string | `"outbound-ready-queue"` | Queue for outbound acknowledgments |
| `ErrorQueueName` | string | `"error-queue"` | Queue for error messages |
| `PrefetchCount` | int | `0` | Number of messages to prefetch |
| `MaxConcurrentCalls` | int | `16` | Maximum concurrent message processing |
| `AutoCompleteMessages` | bool | `true` | Auto-complete messages after processing |
| `MessageTimeToLiveHours` | int | `72` | Message TTL in hours (3 days default) |
| `EnableDeadLetterQueue` | bool | `true` | Enable dead letter queue |

**Example Configuration:**

```json
{
  "ServiceBusOptions": {
    "ConnectionString": "@Microsoft.KeyVault(SecretUri=https://kv-edi-prod.vault.azure.net/secrets/servicebus-connection)",
    "RoutingTopicName": "transaction-routing",
    "EligibilityQueueName": "eligibility-mapper-queue",
    "EnrollmentQueueName": "enrollment-mapper-queue",
    "RemittanceQueueName": "remittance-mapper-queue",
    "ClaimsQueueName": "claims-mapper-queue",
    "OutboundReadyQueueName": "outbound-ready-queue",
    "ErrorQueueName": "error-queue",
    "PrefetchCount": 0,
    "MaxConcurrentCalls": 16,
    "AutoCompleteMessages": true,
    "MessageTimeToLiveHours": 72,
    "EnableDeadLetterQueue": true
  }
}
```

---

### 4. ValidationOptions

Controls X12 envelope and transaction validation.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `EnableStrictValidation` | bool | `true` | Enable strict X12 envelope validation |
| `ValidateControlNumbers` | bool | `true` | Validate control numbers are unique |
| `ValidatePartnerIdentifiers` | bool | `true` | Validate sender/receiver match partner config |
| `ValidateTransactionStructure` | bool | `true` | Validate transaction set structure |
| `ValidateSegmentCounts` | bool | `true` | Validate segment counts match trailer values |
| `RejectOnValidationError` | bool | `true` | Reject files with validation errors |
| `MoveInvalidToError` | bool | `true` | Move invalid files to error container |
| `MaxFileSizeMB` | int | `50` | Maximum file size in MB |
| `AllowedTransactionTypes` | List<string> | `[]` | Allowed transaction types (empty = all) |
| `BlockedTransactionTypes` | List<string> | `[]` | Blocked transaction types |

**Example Configuration:**

```json
{
  "ValidationOptions": {
    "EnableStrictValidation": true,
    "ValidateControlNumbers": true,
    "ValidatePartnerIdentifiers": true,
    "ValidateTransactionStructure": true,
    "ValidateSegmentCounts": true,
    "RejectOnValidationError": true,
    "MoveInvalidToError": true,
    "MaxFileSizeMB": 50,
    "AllowedTransactionTypes": ["270", "271", "834", "835", "837"],
    "BlockedTransactionTypes": []
  }
}
```

---

### 5. PerformanceOptions

Performance and concurrency settings.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `MaxConcurrentExecutions` | int | `50` | Maximum concurrent function executions |
| `TargetLatencyMs` | int | `2000` | Target latency (P95) in milliseconds |
| `TargetThroughput` | int | `1000` | Target throughput (files/hour) |
| `TimeoutMinutes` | int | `5` | Function execution timeout |
| `EnablePerformanceMonitoring` | bool | `true` | Enable performance monitoring |
| `LogSlowOperations` | bool | `true` | Log operations exceeding threshold |
| `SlowOperationThresholdMs` | int | `3000` | Slow operation threshold |

**Example Configuration:**

```json
{
  "PerformanceOptions": {
    "MaxConcurrentExecutions": 50,
    "TargetLatencyMs": 2000,
    "TargetThroughput": 1000,
    "TimeoutMinutes": 5,
    "EnablePerformanceMonitoring": true,
    "LogSlowOperations": true,
    "SlowOperationThresholdMs": 3000
  }
}
```

---

### 6. EventGridOptions

Event Grid trigger configuration.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `MaxDeliveryAttempts` | int | `30` | Maximum delivery attempts |
| `EventTimeToLiveHours` | int | `24` | Event TTL in hours |
| `MaxEventsPerBatch` | int | `10` | Maximum events per batch |
| `EnableDeadLetter` | bool | `true` | Enable dead letter destination |
| `FileExtensionFilters` | List<string> | `["*.x12", "*.edi", "*.txt"]` | File extension filters |
| `IgnorePathPatterns` | List<string> | `["*/archive/*", "*/error/*", "*/deadletter/*"]` | Paths to ignore |
| `EnableAdvancedFiltering` | bool | `true` | Enable advanced filtering |

**Example Configuration:**

```json
{
  "EventGridOptions": {
    "MaxDeliveryAttempts": 30,
    "EventTimeToLiveHours": 24,
    "MaxEventsPerBatch": 10,
    "EnableDeadLetter": true,
    "FileExtensionFilters": ["*.x12", "*.edi", "*.txt"],
    "IgnorePathPatterns": ["*/archive/*", "*/error/*", "*/deadletter/*"],
    "EnableAdvancedFiltering": true
  }
}
```

---

### 7. PartnerMappingOptions

Partner identification and configuration.

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `PartnerConfigContainerName` | string | `"partner-configs"` | Container for partner configurations |
| `PartnerConfigBlobPrefix` | string | `"partners/"` | Blob prefix for partner configs |
| `ConfigurationCacheDurationSeconds` | int | `300` | Configuration cache duration (5 minutes) |
| `AutoRefreshConfiguration` | bool | `true` | Auto-refresh partner configurations |
| `UnknownPartnerHandling` | enum | `Reject` | Strategy for unknown partners |
| `DefaultPartnerCode` | string? | `null` | Default partner for unknown (when handling = AssignDefault) |
| `EnableFuzzyMatching` | bool | `false` | Enable fuzzy matching for partner identification |
| `QualifierMappings` | Dictionary<string,string> | `{}` | ISA qualifier to partner code mappings |

**UnknownPartnerHandling Values:**
- `Reject` - Reject files from unknown partners
- `AssignDefault` - Assign to default partner for manual review
- `RouteToError` - Route to error queue for investigation
- `AutoGenerate` - Auto-generate partner code

**Example Configuration:**

```json
{
  "PartnerMappingOptions": {
    "PartnerConfigContainerName": "partner-configs",
    "PartnerConfigBlobPrefix": "partners/",
    "ConfigurationCacheDurationSeconds": 300,
    "AutoRefreshConfiguration": true,
    "UnknownPartnerHandling": "Reject",
    "DefaultPartnerCode": null,
    "EnableFuzzyMatching": false,
    "QualifierMappings": {
      "ZZ:PARTNER001": "partner001",
      "30:987654321": "bcbs-001"
    }
  }
}
```

---

## Complete appsettings.json Example

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "HealthcareEDI.InboundRouter": "Debug",
      "Microsoft": "Warning",
      "Microsoft.Hosting.Lifetime": "Information"
    }
  },
  
  "StorageOptions": {
    "ConnectionString": "@Microsoft.KeyVault(SecretUri=https://kv-edi-prod.vault.azure.net/secrets/storage-connection)",
    "InboundContainerName": "inbound",
    "ProcessedContainerName": "processed",
    "ArchiveContainerName": "archive",
    "ErrorContainerName": "error",
    "DeadLetterContainerName": "deadletter",
    "ErrorRetentionDays": 30,
    "EnableSoftDelete": true,
    "SoftDeleteRetentionDays": 7
  },
  
  "ServiceBusOptions": {
    "ConnectionString": "@Microsoft.KeyVault(SecretUri=https://kv-edi-prod.vault.azure.net/secrets/servicebus-connection)",
    "RoutingTopicName": "transaction-routing",
    "EligibilityQueueName": "eligibility-mapper-queue",
    "EnrollmentQueueName": "enrollment-mapper-queue",
    "RemittanceQueueName": "remittance-mapper-queue",
    "ClaimsQueueName": "claims-mapper-queue",
    "OutboundReadyQueueName": "outbound-ready-queue",
    "ErrorQueueName": "error-queue",
    "PrefetchCount": 0,
    "MaxConcurrentCalls": 16,
    "AutoCompleteMessages": true,
    "MessageTimeToLiveHours": 72,
    "EnableDeadLetterQueue": true
  },
  
  "RoutingOptions": {
    "RoutingTopicName": "transaction-routing",
    "MaxRetryAttempts": 3,
    "RetryDelay": "00:00:05",
    "TransactionTypeMapping": {
      "270": "Eligibility Request",
      "271": "Eligibility Response",
      "834": "Enrollment",
      "835": "Remittance",
      "837": "Claim"
    }
  },
  
  "ValidationOptions": {
    "EnableStrictValidation": true,
    "ValidateControlNumbers": true,
    "ValidatePartnerIdentifiers": true,
    "ValidateTransactionStructure": true,
    "ValidateSegmentCounts": true,
    "RejectOnValidationError": true,
    "MoveInvalidToError": true,
    "MaxFileSizeMB": 50,
    "AllowedTransactionTypes": [],
    "BlockedTransactionTypes": []
  },
  
  "PerformanceOptions": {
    "MaxConcurrentExecutions": 50,
    "TargetLatencyMs": 2000,
    "TargetThroughput": 1000,
    "TimeoutMinutes": 5,
    "EnablePerformanceMonitoring": true,
    "LogSlowOperations": true,
    "SlowOperationThresholdMs": 3000
  },
  
  "EventGridOptions": {
    "MaxDeliveryAttempts": 30,
    "EventTimeToLiveHours": 24,
    "MaxEventsPerBatch": 10,
    "EnableDeadLetter": true,
    "FileExtensionFilters": ["*.x12", "*.edi", "*.txt"],
    "IgnorePathPatterns": ["*/archive/*", "*/error/*", "*/deadletter/*"],
    "EnableAdvancedFiltering": true
  },
  
  "PartnerMappingOptions": {
    "PartnerConfigContainerName": "partner-configs",
    "PartnerConfigBlobPrefix": "partners/",
    "ConfigurationCacheDurationSeconds": 300,
    "AutoRefreshConfiguration": true,
    "UnknownPartnerHandling": "Reject",
    "DefaultPartnerCode": null,
    "EnableFuzzyMatching": false,
    "QualifierMappings": {}
  }
}
```

---

## Environment-Specific Configuration

### Development (local.settings.json)

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    "FUNCTIONS_EXTENSION_VERSION": "~4",
    
    "StorageOptions__ConnectionString": "UseDevelopmentStorage=true",
    "ServiceBusOptions__ConnectionString": "Endpoint=sb://localhost;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=YOUR_LOCAL_KEY",
    
    "ValidationOptions__EnableStrictValidation": "false",
    "PerformanceOptions__MaxConcurrentExecutions": "10",
    
    "APPLICATIONINSIGHTS_CONNECTION_STRING": "",
    
    "Logging__LogLevel__Default": "Debug",
    "Logging__LogLevel__HealthcareEDI.InboundRouter": "Debug"
  }
}
```

### Test Environment

Use same structure as appsettings.json but with test-specific values:

- Storage account: `steditesteasus2`
- Service Bus namespace: `sb-edi-test-eastus2`
- Relaxed validation for testing
- Lower concurrency limits
- Shorter retention periods

### Production Environment

- Storage account: `stediprodeastus2`
- Service Bus namespace: `sb-edi-prod-eastus2`
- Strict validation enabled
- Higher concurrency limits (50+)
- Longer retention periods (90 days for errors)
- All secrets from Key Vault

---

## Key Vault References

All connection strings and sensitive values should use Key Vault references:

```json
{
  "StorageOptions__ConnectionString": "@Microsoft.KeyVault(SecretUri=https://kv-edi-prod.vault.azure.net/secrets/storage-connection)",
  "ServiceBusOptions__ConnectionString": "@Microsoft.KeyVault(SecretUri=https://kv-edi-prod.vault.azure.net/secrets/servicebus-connection)",
  "APPLICATIONINSIGHTS_CONNECTION_STRING": "@Microsoft.KeyVault(SecretUri=https://kv-edi-prod.vault.azure.net/secrets/appinsights-connection)"
}
```

**Required Key Vault Secrets:**
- `storage-connection` - Storage account connection string
- `servicebus-connection` - Service Bus namespace connection string
- `appinsights-connection` - Application Insights connection string

**Required RBAC Roles:**
- `Key Vault Secrets User` on Key Vault (Function managed identity)
- `Storage Blob Data Reader` on storage account
- `Azure Service Bus Data Sender` on Service Bus namespace

---

## Configuration Validation

Validate configuration at startup using the Options pattern:

```csharp
builder.Services.AddOptions<RoutingOptions>()
    .Bind(builder.Configuration.GetSection("RoutingOptions"))
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

---

## Monitoring Configuration

Key metrics to monitor:

- **Routing Latency:** Average time from blob created to Service Bus message published
- **Success Rate:** Percentage of files successfully routed
- **Error Rate:** Percentage of files moved to error container
- **Throughput:** Files processed per hour
- **Concurrency:** Current concurrent executions

**Application Insights Queries:**

```kusto
// Average routing latency
traces
| where message contains "Routing completed"
| summarize avg(todouble(customDimensions["DurationMs"])) by bin(timestamp, 5m)

// Error rate
requests
| where name contains "RouteFile"
| summarize ErrorRate = 100.0 * countif(success == false) / count() by bin(timestamp, 1h)
```

---

## Troubleshooting

### Common Issues

**Issue:** Files not being routed
- Check Event Grid subscription is active
- Verify storage account event grid integration
- Check Application Insights for errors

**Issue:** Validation errors
- Review ValidationOptions settings
- Check X12 envelope structure
- Verify partner configuration exists

**Issue:** Performance issues
- Increase MaxConcurrentExecutions
- Optimize partner configuration caching
- Check Service Bus throttling

---

## References

- [InboundRouter Function Specification](./inbound-router-spec.md)
- [Partner Configuration Schema](../../config/partners/partners.schema.json)
- [Azure Functions Configuration](https://learn.microsoft.com/en-us/azure/azure-functions/functions-app-settings)
- [Options Pattern in .NET](https://learn.microsoft.com/en-us/dotnet/core/extensions/options)
