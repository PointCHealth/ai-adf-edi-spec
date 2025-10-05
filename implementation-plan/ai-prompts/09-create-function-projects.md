# AI Prompt: Create Azure Function Projects

## Objective

Create all Azure Function projects across the three function repositories with proper structure, dependency injection, logging, and testing frameworks.

## Prerequisites

- Three repositories ready: edi-platform-core, edi-mappers, edi-connectors
- .NET 9 SDK installed
- Azure Functions Core Tools v4 installed
- Shared libraries scaffolded (or will reference from Azure Artifacts)
- Understanding of isolated worker model

## Prompt

```text
I need you to create Azure Function projects for the EDI Healthcare Platform using .NET 9 isolated worker model.

Context:
- Project: Healthcare EDI transaction processing platform
- Runtime: .NET 9 Isolated Worker (not in-process)
- Cloud: Azure Functions Premium Plan (EP1+)
- Architecture: Event-driven with Service Bus triggers, HTTP triggers, Timer triggers
- Logging: Structured logging to Application Insights
- Configuration: Azure Key Vault for secrets
- Testing: xUnit with Moq for unit tests, Testcontainers for integration tests
- Timeline: 18-week AI-accelerated implementation

Please create function projects in the following repositories:

---

## Repository: edi-platform-core

### Function 1: InboundRouter.Function

Purpose: Route incoming EDI files from storage to appropriate processing queues

Structure:
```text
InboundRouter.Function/
├── InboundRouter.csproj
├── Program.cs (DI setup, logging configuration)
├── Functions/
│   └── RouterFunction.cs (HTTP triggered + Event Grid triggered)
├── Services/
│   ├── IRoutingService.cs
│   └── RoutingService.cs
├── Models/
│   ├── RoutingContext.cs
│   └── RoutingResult.cs
├── Configuration/
│   └── RoutingOptions.cs
├── host.json
├── local.settings.json.template
└── .gitignore
```

Requirements:
- **Triggers:**
  - Event Grid trigger for blob created events
  - HTTP trigger for manual routing (POST /api/route)
- **Functionality:**
  - Download blob metadata (first 10KB)
  - Parse ISA/GS segments to determine transaction type
  - Publish routing message to Service Bus topic with filters
  - Log correlation ID for end-to-end tracking
- **Dependencies:**
  - Azure.Storage.Blobs
  - Azure.Messaging.ServiceBus
  - Microsoft.Extensions.Logging
  - Reference shared library: HealthcareEDI.X12Parser (from Azure Artifacts)
- **Configuration:**
  - Connection strings from Key Vault
  - Routing rules from configuration
- **Error Handling:**
  - Retry with exponential backoff
  - Dead-letter queue for permanent failures
  - Structured exception logging

---

### Function 2: EnterpriseScheduler.Function

Purpose: Schedule recurring EDI processing jobs (e.g., nightly 834 enrollment snapshots)

Structure:
```text
EnterpriseScheduler.Function/
├── EnterpriseScheduler.csproj
├── Program.cs
├── Functions/
│   ├── ScheduledJobTrigger.cs (Timer triggered)
│   └── ManualJobTrigger.cs (HTTP triggered for RunNow)
├── Services/
│   ├── IJobScheduler.cs
│   └── JobScheduler.cs
├── Jobs/
│   ├── IScheduledJob.cs
│   └── EnrollmentSnapshotJob.cs
├── Models/
│   └── JobExecutionContext.cs
├── host.json
└── local.settings.json.template
```

Requirements:
- **Triggers:**
  - Timer trigger with NCRONTAB expressions (configurable)
  - HTTP trigger for manual execution
- **Functionality:**
  - Load job definitions from configuration
  - Execute jobs on schedule
  - Track job execution history in SQL database
  - Send notifications on job completion/failure
- **Dependencies:**
  - Microsoft.Azure.Functions.Worker.Extensions.Timer
  - Dapper (for SQL access)
  - Reference shared library: HealthcareEDI.Messaging

---

## Repository: edi-mappers

Create four mapper function projects:

### Function 1: EligibilityMapper.Function (270/271)

Purpose: Transform 270 eligibility requests to partner format, transform 271 responses to canonical format

Structure:
```text
EligibilityMapper.Function/
├── EligibilityMapper.csproj
├── Program.cs
├── Functions/
│   ├── OutboundMapper.cs (Service Bus triggered - 270)
│   └── InboundMapper.cs (HTTP/Queue triggered - 271)
├── Mappers/
│   ├── X12ToCanonicalMapper.cs
│   └── CanonicalToPartnerMapper.cs
├── Models/
│   ├── CanonicalEligibilityRequest.cs
│   └── CanonicalEligibilityResponse.cs
├── host.json
└── local.settings.json.template
```

Requirements:
- **Triggers:**
  - Service Bus queue trigger for outbound mapping
  - HTTP trigger for inbound mapping
- **Functionality:**
  - Parse X12 270 transaction set
  - Map to canonical model
  - Apply partner-specific transformation rules (from config)
  - Generate partner API payload or X12 271
- **Dependencies:**
  - Reference shared library: HealthcareEDI.X12Parser
  - Reference shared library: HealthcareEDI.MappingEngine

### Function 2: ClaimsMapper.Function (837/277)

Similar structure to EligibilityMapper but for claims transactions

### Function 3: EnrollmentMapper.Function (834)

Similar structure but includes event sourcing for enrollment changes

### Function 4: RemittanceMapper.Function (835)

Similar structure for remittance advice

---

## Repository: edi-connectors

Create three connector function projects:

### Function 1: SftpConnector.Function

Purpose: Send/receive files via SFTP to/from trading partners

Structure:
```text
SftpConnector.Function/
├── SftpConnector.csproj
├── Program.cs
├── Functions/
│   ├── SftpUploadFunction.cs (Queue triggered)
│   └── SftpDownloadFunction.cs (Timer triggered)
├── Services/
│   ├── ISftpClient.cs
│   └── SftpClient.cs (wrapper around SSH.NET)
├── Models/
│   └── SftpConnectionConfig.cs
├── host.json
└── local.settings.json.template
```

Requirements:
- **Triggers:**
  - Service Bus queue for uploads
  - Timer trigger for scheduled downloads
- **Functionality:**
  - Connect to partner SFTP servers
  - Upload files with retry logic
  - Download files and trigger processing
  - Archive transferred files
- **Dependencies:**
  - SSH.NET or Renci.SshNet
  - Azure.Storage.Blobs

### Function 2: ApiConnector.Function

Purpose: Send/receive data via RESTful APIs to/from trading partners

### Function 3: DatabaseConnector.Function

Purpose: Read/write data from partner databases (if applicable)

---

## Common Requirements for ALL Functions

1. **Project File (.csproj):**
   - TargetFramework: net9.0
   - AzureFunctionsVersion: v4
   - OutputType: Exe (isolated worker)

2. **Program.cs:**
   - Configure HostBuilder
   - Set up dependency injection
   - Configure Application Insights
   - Configure structured logging (Serilog or default)
   - Register services

3. **host.json:**
   - Configure retry policies
   - Set concurrency limits
   - Configure Application Insights sampling

4. **local.settings.json.template:**
   - Template for local development
   - Placeholder values for connection strings
   - DO NOT include actual secrets

5. **Dependency Injection:**
   - Register services in Program.cs
   - Use IOptions pattern for configuration
   - Inject ILogger<T> for logging

6. **Error Handling:**
   - Try-catch with structured exception logging
   - Return appropriate HTTP status codes
   - Use dead-letter queues for permanent failures

7. **Testing:**
   - Create corresponding test project: `<FunctionName>.Tests`
   - Use xUnit, Moq, FluentAssertions
   - Mock Azure SDK clients
   - Test functions independently

8. **.gitignore:**
   - Ignore local.settings.json
   - Ignore bin/obj folders
   - Ignore __azurite__ folders

Also provide:
1. PowerShell script to create all projects with `dotnet new`
2. Sample Program.cs with DI setup
3. Sample function with Service Bus trigger
4. Sample unit test class
5. README for each repository explaining how to run locally
```

## Expected Outcome

After running this prompt, you should have:

- ✅ All function projects created with proper structure
- ✅ Program.cs configured with DI and logging
- ✅ Sample functions implemented
- ✅ Test projects scaffolded
- ✅ Configuration templates provided
- ✅ README documentation

## Validation Steps

1. Build all function projects:

   ```powershell
   cd edi-platform-core\functions\InboundRouter.Function
   dotnet build
   
   cd ..\..\..
   cd edi-mappers\functions\EligibilityMapper.Function
   dotnet build
   
   # Repeat for all functions
   ```

2. Run a function locally:

   ```powershell
   cd edi-platform-core\functions\InboundRouter.Function
   # Copy local.settings.json.template to local.settings.json
   # Fill in connection strings
   func start
   ```

3. Test HTTP trigger:

   ```powershell
   curl http://localhost:7071/api/route -Method POST -Body '{"filePath": "test.edi"}'
   ```

4. Run unit tests:

   ```powershell
   cd edi-platform-core\tests\InboundRouter.Tests
   dotnet test
   ```

## Troubleshooting

**Build errors about missing references:**

- Ensure shared libraries are published to Azure Artifacts
- Update NuGet.config with Azure Artifacts feed
- Restore packages: `dotnet restore`

**Function runtime errors:**

- Check .NET 9 SDK installed: `dotnet --version`
- Check Azure Functions Core Tools: `func --version` (should be v4.x)
- Verify isolated worker model in .csproj

**Local testing issues:**

- Ensure Azurite running for local storage
- Check local.settings.json has all required connection strings
- Verify port 7071 not in use

## Next Steps

After successful completion:

- Implement core function logic
- Create integration tests [14-create-integration-tests.md](14-create-integration-tests.md)
- Set up CI/CD workflows [05-create-function-workflows.md](05-create-function-workflows.md)
- Deploy to dev environment
