# InboundRouter Function

Routes incoming EDI files from Azure Storage to appropriate processing queues based on transaction type.

## Features

- **Event Grid Trigger**: Automatically processes files when they arrive in storage
- **HTTP Trigger**: Manual routing endpoint for testing and administrative operations
- **Transaction Type Detection**: Analyzes ISA/GS segments to determine X12 transaction type
- **Service Bus Integration**: Routes messages to topic with transaction-type filters
- **Correlation Tracking**: End-to-end correlation IDs for observability

## Local Development

### Prerequisites

- .NET 9 SDK
- Azure Functions Core Tools v4
- Azurite (for local storage emulation)
- Azure Service Bus Emulator or connection to Azure Service Bus

### Setup

1. Copy configuration template:
   ```powershell
   Copy-Item local.settings.json.template local.settings.json
   ```

2. Update `local.settings.json` with your connection strings

3. Start Azurite:
   ```powershell
   azurite --silent --location c:\azurite --debug c:\azurite\debug.log
   ```

4. Run the function:
   ```powershell
   func start
   ```

### Testing

**HTTP Endpoint**:
```powershell
curl http://localhost:7071/api/route `
  -Method POST `
  -Headers @{"Content-Type"="application/json"} `
  -Body '{"filePath": "inbound/test-270.edi"}'
```

**Event Grid Event** (requires Event Grid local forwarding):
```powershell
# Configure Event Grid to forward to: http://localhost:7071/runtime/webhooks/EventGrid?functionName=RouteFileOnBlobCreated
```

## Configuration

| Setting | Description | Example |
|---------|-------------|---------|
| `StorageAccountConnectionString` | Azure Storage connection | `DefaultEndpointsProtocol=https;...` |
| `ServiceBusConnectionString` | Azure Service Bus connection | `Endpoint=sb://...` |
| `RoutingOptions__RoutingTopicName` | Service Bus topic for routing | `transaction-routing` |
| `RoutingOptions__MaxRetryAttempts` | Max retry attempts | `3` |

## Architecture

```
[Blob Storage] --> [Event Grid] --> [InboundRouter]
                                         |
                                         v
                               [Service Bus Topic]
                                  /    |    \
                            270/271  837/277  834/835
```

## Dependencies

- Azure.Storage.Blobs
- Azure.Messaging.ServiceBus
- Microsoft.Azure.Functions.Worker
- Microsoft.ApplicationInsights

## Deployment

Deployed via GitHub Actions workflow to:
- Dev: func-inbound-router-dev-eastus2
- Test: func-inbound-router-test-eastus2  
- Prod: func-inbound-router-prod-eastus2

## Monitoring

- Application Insights: Structured logging with correlation IDs
- Metrics: Processing time, success rate, transaction type distribution
- Alerts: Failed routing attempts, unknown transaction types
