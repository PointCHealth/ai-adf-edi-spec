# Azure Functions - Healthcare EDI Platform

This directory contains all Azure Function projects for the Healthcare EDI Platform, organized by functional category.

## 📁 Project Structure

```
functions/
├── platform-core/           # Core platform functions
│   ├── InboundRouter.Function          ✅ IMPLEMENTED
│   ├── EnterpriseScheduler.Function    🔄 SCAFFOLDED
│   ├── ControlNumberGenerator.Function 🔄 SCAFFOLDED
│   ├── FileArchiver.Function           🔄 SCAFFOLDED
│   └── NotificationService.Function    🔄 SCAFFOLDED
│
├── mappers/                 # Transaction mapping functions
│   ├── EligibilityMapper.Function      🔄 SCAFFOLDED
│   ├── ClaimsMapper.Function           🔄 SCAFFOLDED
│   ├── EnrollmentMapper.Function       🔄 SCAFFOLDED
│   └── RemittanceMapper.Function       🔄 SCAFFOLDED
│
└── connectors/              # External integration functions
    ├── SftpConnector.Function          🔄 SCAFFOLDED
    ├── ApiConnector.Function           🔄 SCAFFOLDED
    └── DatabaseConnector.Function      🔄 SCAFFOLDED
```

## 🚀 Functions Overview

### Platform Core Functions

| Function | Purpose | Triggers | Status |
|----------|---------|----------|--------|
| **InboundRouter** | Routes EDI files to processing queues | Event Grid, HTTP | ✅ Implemented |
| **EnterpriseScheduler** | Schedules recurring jobs | Timer, HTTP | 🔄 Scaffolded |
| **ControlNumberGenerator** | Manages control numbers | Service Bus, HTTP | 🔄 Scaffolded |
| **FileArchiver** | Archives processed files | Timer, Queue | 🔄 Scaffolded |
| **NotificationService** | Sends notifications | Service Bus, HTTP | 🔄 Scaffolded |

### Mapper Functions

| Function | Transactions | Purpose | Status |
|----------|--------------|---------|--------|
| **EligibilityMapper** | 270/271 | Eligibility requests/responses | 🔄 Scaffolded |
| **ClaimsMapper** | 837/277 | Claims and responses | 🔄 Scaffolded |
| **EnrollmentMapper** | 834 | Benefit enrollment | 🔄 Scaffolded |
| **RemittanceMapper** | 835 | Payment remittance | 🔄 Scaffolded |

### Connector Functions

| Function | Protocol | Purpose | Status |
|----------|----------|---------|--------|
| **SftpConnector** | SFTP | File transfer with partners | 🔄 Scaffolded |
| **ApiConnector** | REST API | API integration | 🔄 Scaffolded |
| **DatabaseConnector** | SQL | Direct database access | 🔄 Scaffolded |

## 🛠️ Technology Stack

- **.NET Runtime**: .NET 9
- **Function Runtime**: Azure Functions v4 (Isolated Worker Model)
- **Triggers**: HTTP, Service Bus, Event Grid, Timer, Queue
- **Storage**: Azure Blob Storage, Azure Tables
- **Messaging**: Azure Service Bus
- **Monitoring**: Application Insights
- **Configuration**: Azure Key Vault

## 📋 Prerequisites

- [.NET 9 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)
- [Azure Functions Core Tools v4](https://docs.microsoft.com/azure/azure-functions/functions-run-local)
- [Azurite](https://docs.microsoft.com/azure/storage/common/storage-use-azurite) (for local testing)
- Azure subscription (for deployment)

## 🏃 Getting Started

### 1. Restore Dependencies

```powershell
# Restore all function projects
cd src/functions
Get-ChildItem -Recurse -Filter "*.csproj" | ForEach-Object {
    Push-Location $_.Directory
    dotnet restore
    Pop-Location
}
```

### 2. Configure Local Settings

Each function has a `local.settings.json.template` file. Copy and configure:

```powershell
# For InboundRouter example
cd platform-core/InboundRouter.Function
Copy-Item local.settings.json.template local.settings.json
# Edit local.settings.json with your connection strings
```

### 3. Start Local Development

```powershell
# Start Azurite (local storage emulator)
azurite --silent

# Start a function app
cd platform-core/InboundRouter.Function
func start
```

### 4. Test Functions

```powershell
# HTTP Trigger example
Invoke-RestMethod `
    -Uri "http://localhost:7071/api/route" `
    -Method POST `
    -Body '{"filePath":"inbound/test.edi"}' `
    -ContentType "application/json"
```

## 🏗️ Development Guidelines

### Project Structure

Each function follows this structure:

```
FunctionName.Function/
├── Program.cs                  # DI container setup
├── Functions/
│   └── MainFunction.cs         # Function entry points
├── Services/
│   ├── IService.cs             # Service interfaces
│   └── ServiceImpl.cs          # Service implementations
├── Models/
│   └── DataModels.cs           # DTOs and domain models
├── Configuration/
│   └── Options.cs              # Configuration classes
├── host.json                   # Function host configuration
├── local.settings.json.template # Configuration template
├── .gitignore                  # Git ignore rules
└── README.md                   # Function documentation
```

### Coding Standards

- **Nullable Reference Types**: Enabled (`<Nullable>enable</Nullable>`)
- **Implicit Usings**: Enabled for common namespaces
- **Dependency Injection**: Use constructor injection for all dependencies
- **Logging**: Use `ILogger<T>` with structured logging
- **Configuration**: Use `IOptions<T>` pattern
- **Error Handling**: Implement retry logic and dead-letter queues

### Testing

```powershell
# Run unit tests
dotnet test

# Run with coverage
dotnet test --collect:"XPlat Code Coverage"
```

## 🚢 Deployment

Functions are deployed via GitHub Actions workflows:

- **CI**: Build, test, and package on PR
- **CD**: Deploy to dev/test/prod environments
- **Deployment Slots**: Blue-green deployments for zero downtime

### Deployment Targets

| Environment | Resource Group | Function App Prefix |
|-------------|----------------|---------------------|
| Dev | rg-edi-dev-eastus2 | func-*-dev-eastus2 |
| Test | rg-edi-test-eastus2 | func-*-test-eastus2 |
| Prod | rg-edi-prod-eastus2 | func-*-prod-eastus2 |

## 📊 Monitoring

### Application Insights

All functions log to Application Insights with:
- **Correlation IDs**: End-to-end transaction tracking
- **Custom Metrics**: Processing times, success rates
- **Dependencies**: External service calls tracked
- **Exceptions**: Structured exception logging

### Key Metrics

- Transaction processing time
- Success/failure rates by transaction type
- Service Bus queue depths
- Storage account operations
- Partner-specific processing metrics

### Alerts

- Function execution failures
- Processing time thresholds
- Dead-letter queue depth
- HTTP 5xx errors

## 🔒 Security

- **Managed Identity**: Functions use system-assigned managed identities
- **Key Vault**: Secrets stored in Azure Key Vault
- **Network Security**: VNet integration for premium plans
- **Authentication**: Function-level keys for HTTP triggers
- **HIPAA Compliance**: PHI data handling following HIPAA guidelines

## 📝 Next Steps

1. ✅ **Step 09 Complete**: Function projects scaffolded
2. 🔄 **Implement Core Logic**: Complete business logic for each function
3. 🔄 **Create Unit Tests**: Add comprehensive test coverage
4. 🔄 **Integration Tests**: End-to-end testing with testcontainers
5. 🔄 **CI/CD Configuration**: Update workflows for new functions
6. 🔄 **Deploy to Dev**: First deployment to development environment

## 📚 Resources

- [Azure Functions .NET Isolated Worker Guide](https://docs.microsoft.com/azure/azure-functions/dotnet-isolated-process-guide)
- [Azure Functions Best Practices](https://docs.microsoft.com/azure/azure-functions/functions-best-practices)
- [X12 EDI Standards](https://x12.org/)
- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/index.html)

## 🤝 Contributing

1. Create feature branch from `main`
2. Implement changes with tests
3. Run `dotnet format` for code formatting
4. Create pull request with description
5. Wait for CI/CD validation
6. Request code review

## 📞 Support

For questions or issues:
- Create GitHub Issue
- Contact: Platform Team
- Documentation: See individual function READMEs
