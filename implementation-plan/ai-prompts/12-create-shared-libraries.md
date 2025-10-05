# AI Prompt: Create Shared Library Projects

## Objective

Create shared NuGet library projects in the edi-platform-core repository that will be consumed by all function projects across repositories.

## Prerequisites

- edi-platform-core repository created
- .NET 9 SDK installed
- Azure Artifacts feed configured
- Understanding of NuGet package versioning

## Prompt

```text
I need you to create shared .NET class library projects for the EDI Healthcare Platform that will be packaged as NuGet packages and consumed across all function projects.

Context:
- Repository: edi-platform-core/shared/
- Framework: .NET 9
- Packaging: NuGet packages to Azure Artifacts feed
- Consumers: All function projects in edi-platform-core, edi-mappers, edi-connectors
- Architecture: Clean architecture with clear separation of concerns
- Timeline: 18-week AI-accelerated implementation

Please create the following library projects:

---

## Library 1: HealthcareEDI.Core

Purpose: Core abstractions, interfaces, and common models

Structure:
```text
shared/HealthcareEDI.Core/
├── HealthcareEDI.Core.csproj
├── Interfaces/
│   ├── IRepository.cs
│   ├── IMessagePublisher.cs
│   └── IStorageService.cs
├── Models/
│   ├── TransactionEnvelope.cs
│   ├── RoutingContext.cs
│   └── ProcessingResult.cs
├── Exceptions/
│   ├── EDIException.cs
│   ├── ParsingException.cs
│   └── ValidationException.cs
├── Constants/
│   ├── TransactionTypes.cs
│   └── ErrorCodes.cs
└── Extensions/
    ├── StringExtensions.cs
    └── DateTimeExtensions.cs
```

Requirements:
- Pure interfaces and models (no implementation)
- XML documentation comments on all public members
- Strong naming for security
- Nullable reference types enabled
- No external dependencies (only .NET BCL)

---

## Library 2: HealthcareEDI.X12

Purpose: X12 EDI parsing, validation, and generation

Structure:
```text
shared/HealthcareEDI.X12/
├── HealthcareEDI.X12.csproj
├── Parser/
│   ├── IX12Parser.cs
│   ├── X12Parser.cs
│   ├── SegmentParser.cs
│   └── ElementParser.cs
├── Models/
│   ├── X12Envelope.cs
│   ├── ISASegment.cs
│   ├── GSSegment.cs
│   └── STSegment.cs
├── Validators/
│   ├── IX12Validator.cs
│   ├── EnvelopeValidator.cs
│   └── TransactionValidator.cs
├── Generators/
│   ├── IX12Generator.cs
│   └── X12Generator.cs
└── Specifications/
    ├── Transaction270.cs (Eligibility Inquiry)
    ├── Transaction271.cs (Eligibility Response)
    ├── Transaction834.cs (Enrollment)
    ├── Transaction837.cs (Claims)
    └── Transaction999.cs (Acknowledgment)
```

Requirements:
- Support X12 005010 standard
- Handle segment/element/sub-element parsing
- Validate segment order and required elements
- Generate compliant X12 transactions
- Exception handling for malformed EDI
- Dependencies: System.Text.Json for models

---

## Library 3: HealthcareEDI.Configuration

Purpose: Configuration management and partner metadata

Structure:
```text
shared/HealthcareEDI.Configuration/
├── HealthcareEDI.Configuration.csproj
├── Interfaces/
│   ├── IConfigurationProvider.cs
│   └── IPartnerConfigService.cs
├── Models/
│   ├── PartnerConfiguration.cs
│   ├── MappingRuleSet.cs
│   └── RoutingRule.cs
├── Services/
│   ├── ConfigurationProvider.cs
│   └── PartnerConfigService.cs (loads from storage/config repo)
└── Validation/
    └── ConfigurationValidator.cs
```

Requirements:
- Load configurations from Azure Blob Storage or config repository
- Cache configurations with refresh mechanism
- Validate configuration schemas
- Support environment-specific overrides
- Dependencies: Azure.Storage.Blobs, Microsoft.Extensions.Caching

---

## Library 4: HealthcareEDI.Storage

Purpose: Storage abstractions for Blob, Queue, and Table storage

Structure:
```text
shared/HealthcareEDI.Storage/
├── HealthcareEDI.Storage.csproj
├── Interfaces/
│   ├── IBlobStorageService.cs
│   └── IQueueService.cs
├── Services/
│   ├── BlobStorageService.cs
│   └── QueueService.cs
└── Models/
    ├── BlobMetadata.cs
    └── QueueMessage.cs
```

Requirements:
- Wrapper around Azure.Storage.Blobs SDK
- Simplified API for common operations
- Automatic retry with exponential backoff
- Structured logging
- Dependencies: Azure.Storage.Blobs, Azure.Storage.Queues

---

## Library 5: HealthcareEDI.Messaging

Purpose: Service Bus abstractions for publishing and consuming messages

Structure:
```text
shared/HealthcareEDI.Messaging/
├── HealthcareEDI.Messaging.csproj
├── Interfaces/
│   ├── IMessagePublisher.cs
│   └── IMessageProcessor.cs
├── Services/
│   ├── ServiceBusPublisher.cs
│   └── ServiceBusProcessor.cs
└── Models/
    ├── RoutingMessage.cs
    └── ProcessingMessage.cs
```

Requirements:
- Wrapper around Azure.Messaging.ServiceBus SDK
- Support for topics, queues, and subscriptions
- Automatic dead-lettering configuration
- Correlation ID propagation
- Dependencies: Azure.Messaging.ServiceBus

---

## Library 6: HealthcareEDI.Logging

Purpose: Structured logging with Application Insights integration

Structure:
```text
shared/HealthcareEDI.Logging/
├── HealthcareEDI.Logging.csproj
├── Extensions/
│   ├── LoggerExtensions.cs
│   └── TelemetryExtensions.cs
├── Models/
│   ├── LogContext.cs
│   └── CorrelationContext.cs
└── Middleware/
    └── CorrelationMiddleware.cs (for Functions)
```

Requirements:
- Extension methods for common log patterns
- Correlation ID management
- PII scrubbing for HIPAA compliance
- Integration with Application Insights
- Dependencies: Microsoft.ApplicationInsights

---

## Common Requirements for ALL Libraries

1. **Project File (.csproj):**
   - TargetFramework: net9.0
   - GeneratePackageOnBuild: true
   - PackageId: HealthcareEDI.<LibraryName>
   - Version: 1.0.0 (SemVer)
   - Authors: PointCHealth EDI Platform Team
   - Company: PointCHealth
   - PackageLicenseExpression: Proprietary
   - PackageProjectUrl: https://github.com/PointCHealth/edi-platform-core
   - RepositoryUrl: https://github.com/PointCHealth/edi-platform-core
   - Nullable: enable
   - TreatWarningsAsErrors: true

2. **NuGet Package Settings:**
   - Include XML documentation
   - Include symbols package (.snupkg)
   - Sign package (optional but recommended)

3. **Testing:**
   - Create corresponding test project: `HealthcareEDI.<LibraryName>.Tests`
   - Use xUnit, Moq, FluentAssertions
   - Aim for >80% code coverage

4. **Documentation:**
   - XML documentation on all public members
   - README.md explaining purpose and usage
   - Sample code snippets

5. **CI/CD:**
   - Build and test on every PR
   - Pack and publish to Azure Artifacts on merge to main
   - Automatic versioning (GitVersion or manual)

Also provide:
1. PowerShell script to create all library projects
2. Sample .csproj with NuGet metadata
3. NuGet.config for publishing to Azure Artifacts
4. GitHub Actions workflow to build and publish packages
5. README template for each library
```

## Expected Outcome

After running this prompt, you should have:

- ✅ Six shared library projects created in edi-platform-core/shared/
- ✅ Proper project structure with separation of concerns
- ✅ NuGet packaging configuration
- ✅ Test projects scaffolded
- ✅ CI/CD workflow for package publishing
- ✅ Documentation templates

## Validation Steps

1. Build all library projects:

   ```powershell
   cd edi-platform-core\shared
   dotnet build
   ```

2. Run tests:

   ```powershell
   cd edi-platform-core\shared
   dotnet test
   ```

3. Pack libraries:

   ```powershell
   cd edi-platform-core\shared\HealthcareEDI.Core
   dotnet pack --configuration Release
   
   # Should create bin/Release/HealthcareEDI.Core.1.0.0.nupkg
   ```

4. Publish to Azure Artifacts (one-time setup):

   ```powershell
   # Add Azure Artifacts as source
   dotnet nuget add source https://pkgs.dev.azure.com/PointCHealth/_packaging/edi-packages/nuget/v3/index.json `
     --name AzureArtifacts `
     --username az `
     --password $env:AZURE_ARTIFACTS_PAT `
     --store-password-in-clear-text
   
   # Push package
   dotnet nuget push bin/Release/HealthcareEDI.Core.1.0.0.nupkg --source AzureArtifacts
   ```

5. Consume in function project:

   ```powershell
   cd edi-platform-core\functions\InboundRouter.Function
   dotnet add package HealthcareEDI.Core --version 1.0.0
   dotnet add package HealthcareEDI.X12 --version 1.0.0
   ```

## Troubleshooting

**Build errors:**

- Check .NET 9 SDK installed: `dotnet --version`
- Restore dependencies: `dotnet restore`
- Clean and rebuild: `dotnet clean && dotnet build`

**Package not found when consuming:**

- Verify NuGet.config has Azure Artifacts feed
- Check package published: Browse Azure Artifacts in Azure DevOps
- Ensure PAT has packaging read permissions

**Versioning conflicts:**

- Use GitVersion for automatic semantic versioning
- Manually update version in .csproj before major releases
- Document breaking changes in CHANGELOG.md

## Next Steps

After successful completion:

- Implement core logic in each library
- Achieve >80% test coverage
- Set up automatic package publishing [24-cicd-pipeline-implementation.md](../24-cicd-pipeline-implementation.md)
- Reference libraries in function projects [09-create-function-projects.md](09-create-function-projects.md)
- Document API usage in centralized docs
