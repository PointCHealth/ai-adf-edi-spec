# Phase 3 Quick Start Guide - EligibilityMapper Implementation

**Goal:** Implement first complete end-to-end transaction flow (270/271 Eligibility)  
**Timeline:** Weeks 11-14 (Current week: 11)  
**Priority:** ⭐ Critical Path Item

---

## Overview

This guide provides step-by-step instructions for implementing the **EligibilityMapper Azure Function**, the first business logic function that processes X12 270 (Eligibility Request) and 271 (Eligibility Response) transactions.

---

## Prerequisites

✅ **Already Complete:**
- Infrastructure deployed (Bicep)
- InboundRouter function operational
- All 6 shared libraries built and tested
- Service Bus queues created
- Storage containers configured

📋 **Required Before Starting:**
- Access to edi-platform-core repository
- Understanding of X12 270/271 transaction structure
- Familiarity with InboundRouter implementation patterns

---

## Phase 3.1: EligibilityMapper Function

### Step 1: Review X12 270/271 Specifications

**X12 270 (Eligibility Request):**
```
ISA*00*          *00*          *ZZ*SENDER         *ZZ*RECEIVER       *250106*1200*^*00501*000000001*0*P*:~
GS*HS*SENDERAPP*RECEIVERAPP*20250106*1200*1*X*005010X279A1~
ST*270*0001*005010X279A1~
BHT*0022*13*REF123*20250106*1200~
HL*1**20*1~
NM1*PR*2*INSURANCE CO*****PI*12345~
HL*2*1*21*1~
NM1*1P*2*PROVIDER*****XX*1234567890~
HL*3*2*22*0~
TRN*1*REF456*1234567890~
NM1*IL*1*DOE*JOHN****MI*MEMBER123~
DMG*D8*19800115*M~
DTP*291*D8*20250106~
EQ*30~
SE*13*0001~
GE*1*1~
IEA*1*000000001~
```

**X12 271 (Eligibility Response):**
```
ISA*00*          *00*          *ZZ*RECEIVER       *ZZ*SENDER         *250106*1201*^*00501*000000002*0*P*:~
GS*HB*RECEIVERAPP*SENDERAPP*20250106*1201*2*X*005010X279A1~
ST*271*0002*005010X279A1~
BHT*0022*11*REF123*20250106*1201~
HL*1**20*1~
NM1*PR*2*INSURANCE CO*****PI*12345~
HL*2*1*21*1~
NM1*1P*2*PROVIDER*****XX*1234567890~
HL*3*2*22*0~
TRN*2*REF456*1234567890~
NM1*IL*1*DOE*JOHN****MI*MEMBER123~
N3*123 MAIN ST~
N4*ANYTOWN*CA*12345~
DMG*D8*19800115*M~
DTP*291*D8*20250106~
EB*1*FAM*30**HEALTH BENEFIT PLAN COVERAGE~
SE*15*0002~
GE*1*2~
IEA*1*000000002~
```

**Key Elements to Extract:**
- **270 Request:**
  - Transaction Reference Number (TRN)
  - Member ID (NM1*IL)
  - Provider NPI (NM1*1P)
  - Service Date (DTP*291)
  - Service Type (EQ segments)

- **271 Response:**
  - All 270 elements plus:
  - Eligibility status (EB segments)
  - Coverage details
  - Member demographics (DMG, N3, N4)

---

### Step 2: Create Configuration Model

**File:** `functions/EligibilityMapper.Function/Configuration/MappingOptions.cs`

```csharp
using System.ComponentModel.DataAnnotations;

namespace HealthcareEDI.EligibilityMapper.Configuration;

/// <summary>
/// Configuration for eligibility mapping operations
/// </summary>
public class MappingOptions
{
    /// <summary>
    /// Enable strict mapping validation
    /// </summary>
    [Required]
    public bool EnableStrictValidation { get; set; } = true;

    /// <summary>
    /// Maximum transaction age in days
    /// </summary>
    [Range(1, 90)]
    public int MaxTransactionAgeDays { get; set; } = 30;

    /// <summary>
    /// Output format (JSON or XML)
    /// </summary>
    [Required]
    public string OutputFormat { get; set; } = "JSON";

    /// <summary>
    /// Output container for mapped transactions
    /// </summary>
    [Required]
    public string OutputContainerName { get; set; } = "mapped";

    /// <summary>
    /// Enable field-level validation
    /// </summary>
    public bool ValidateFields { get; set; } = true;

    /// <summary>
    /// Required field paths (dot notation)
    /// </summary>
    public List<string> RequiredFields { get; set; } = new()
    {
        "TransactionReferenceNumber",
        "MemberId",
        "ProviderNpi"
    };

    /// <summary>
    /// Partner-specific mapping overrides
    /// </summary>
    public Dictionary<string, Dictionary<string, string>> PartnerOverrides { get; set; } = new();
}
```

---

### Step 3: Create Internal Data Models

**File:** `functions/EligibilityMapper.Function/Models/EligibilityRequest.cs`

```csharp
using System.Text.Json.Serialization;

namespace HealthcareEDI.EligibilityMapper.Models;

/// <summary>
/// Internal representation of X12 270 eligibility request
/// </summary>
public class EligibilityRequest
{
    [JsonPropertyName("transactionReferenceNumber")]
    public string TransactionReferenceNumber { get; set; } = string.Empty;

    [JsonPropertyName("requestDate")]
    public DateTime RequestDate { get; set; }

    [JsonPropertyName("memberId")]
    public string MemberId { get; set; } = string.Empty;

    [JsonPropertyName("memberFirstName")]
    public string? MemberFirstName { get; set; }

    [JsonPropertyName("memberLastName")]
    public string? MemberLastName { get; set; }

    [JsonPropertyName("memberDateOfBirth")]
    public DateTime? MemberDateOfBirth { get; set; }

    [JsonPropertyName("memberGender")]
    public string? MemberGender { get; set; }

    [JsonPropertyName("providerNpi")]
    public string ProviderNpi { get; set; } = string.Empty;

    [JsonPropertyName("providerName")]
    public string? ProviderName { get; set; }

    [JsonPropertyName("serviceDate")]
    public DateTime? ServiceDate { get; set; }

    [JsonPropertyName("serviceTypeCodes")]
    public List<string> ServiceTypeCodes { get; set; } = new();

    [JsonPropertyName("metadata")]
    public RequestMetadata Metadata { get; set; } = new();
}

public class RequestMetadata
{
    [JsonPropertyName("partnerCode")]
    public string PartnerCode { get; set; } = string.Empty;

    [JsonPropertyName("controlNumber")]
    public string ControlNumber { get; set; } = string.Empty;

    [JsonPropertyName("receivedTimestamp")]
    public DateTime ReceivedTimestamp { get; set; }

    [JsonPropertyName("blobPath")]
    public string BlobPath { get; set; } = string.Empty;
}
```

**File:** `functions/EligibilityMapper.Function/Models/EligibilityResponse.cs`

```csharp
using System.Text.Json.Serialization;

namespace HealthcareEDI.EligibilityMapper.Models;

/// <summary>
/// Internal representation of X12 271 eligibility response
/// </summary>
public class EligibilityResponse
{
    [JsonPropertyName("transactionReferenceNumber")]
    public string TransactionReferenceNumber { get; set; } = string.Empty;

    [JsonPropertyName("responseDate")]
    public DateTime ResponseDate { get; set; }

    [JsonPropertyName("memberId")]
    public string MemberId { get; set; } = string.Empty;

    [JsonPropertyName("memberFirstName")]
    public string? MemberFirstName { get; set; }

    [JsonPropertyName("memberLastName")]
    public string? MemberLastName { get; set; }

    [JsonPropertyName("memberDateOfBirth")]
    public DateTime? MemberDateOfBirth { get; set; }

    [JsonPropertyName("memberGender")]
    public string? MemberGender { get; set; }

    [JsonPropertyName("memberAddress")]
    public Address? MemberAddress { get; set; }

    [JsonPropertyName("providerNpi")]
    public string ProviderNpi { get; set; } = string.Empty;

    [JsonPropertyName("providerName")]
    public string? ProviderName { get; set; }

    [JsonPropertyName("coverageDetails")]
    public List<CoverageDetail> CoverageDetails { get; set; } = new();

    [JsonPropertyName("metadata")]
    public ResponseMetadata Metadata { get; set; } = new();
}

public class Address
{
    [JsonPropertyName("street")]
    public string? Street { get; set; }

    [JsonPropertyName("city")]
    public string? City { get; set; }

    [JsonPropertyName("state")]
    public string? State { get; set; }

    [JsonPropertyName("zipCode")]
    public string? ZipCode { get; set; }
}

public class CoverageDetail
{
    [JsonPropertyName("serviceTypeCode")]
    public string ServiceTypeCode { get; set; } = string.Empty;

    [JsonPropertyName("serviceTypeName")]
    public string? ServiceTypeName { get; set; }

    [JsonPropertyName("coverageLevel")]
    public string? CoverageLevel { get; set; }

    [JsonPropertyName("planDescription")]
    public string? PlanDescription { get; set; }

    [JsonPropertyName("benefitAmount")]
    public decimal? BenefitAmount { get; set; }

    [JsonPropertyName("timePeriod")]
    public string? TimePeriod { get; set; }
}

public class ResponseMetadata
{
    [JsonPropertyName("partnerCode")]
    public string PartnerCode { get; set; } = string.Empty;

    [JsonPropertyName("controlNumber")]
    public string ControlNumber { get; set; } = string.Empty;

    [JsonPropertyName("receivedTimestamp")]
    public DateTime ReceivedTimestamp { get; set; }

    [JsonPropertyName("mappedTimestamp")]
    public DateTime MappedTimestamp { get; set; }

    [JsonPropertyName("blobPath")]
    public string BlobPath { get; set; } = string.Empty;
}
```

---

### Step 4: Implement Mapping Service

**File:** `functions/EligibilityMapper.Function/Services/EligibilityMappingService.cs`

```csharp
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using EDI.X12;
using EDI.X12.Models;
using HealthcareEDI.EligibilityMapper.Configuration;
using HealthcareEDI.EligibilityMapper.Models;

namespace HealthcareEDI.EligibilityMapper.Services;

public interface IEligibilityMappingService
{
    Task<EligibilityRequest> MapRequestAsync(X12Envelope envelope, string partnerCode, string blobPath);
    Task<EligibilityResponse> MapResponseAsync(X12Envelope envelope, string partnerCode, string blobPath);
}

public class EligibilityMappingService : IEligibilityMappingService
{
    private readonly ILogger<EligibilityMappingService> _logger;
    private readonly MappingOptions _options;

    public EligibilityMappingService(
        ILogger<EligibilityMappingService> logger,
        IOptions<MappingOptions> options)
    {
        _logger = logger;
        _options = options.Value;
    }

    public async Task<EligibilityRequest> MapRequestAsync(X12Envelope envelope, string partnerCode, string blobPath)
    {
        _logger.LogInformation("Mapping 270 eligibility request for partner {PartnerCode}", partnerCode);

        var transaction = envelope.FunctionalGroups[0].Transactions[0];
        
        var request = new EligibilityRequest
        {
            // Extract TRN segment (Transaction Reference Number)
            TransactionReferenceNumber = ExtractTransactionReference(transaction),
            
            // Extract BHT segment (Beginning of Hierarchical Transaction)
            RequestDate = ExtractRequestDate(transaction),
            
            // Extract member information from NM1*IL segment
            MemberId = ExtractMemberId(transaction),
            MemberFirstName = ExtractMemberFirstName(transaction),
            MemberLastName = ExtractMemberLastName(transaction),
            
            // Extract DMG segment (Demographics)
            MemberDateOfBirth = ExtractMemberDateOfBirth(transaction),
            MemberGender = ExtractMemberGender(transaction),
            
            // Extract provider information from NM1*1P segment
            ProviderNpi = ExtractProviderNpi(transaction),
            ProviderName = ExtractProviderName(transaction),
            
            // Extract DTP*291 segment (Service Date)
            ServiceDate = ExtractServiceDate(transaction),
            
            // Extract EQ segments (Service Type Codes)
            ServiceTypeCodes = ExtractServiceTypeCodes(transaction),
            
            Metadata = new RequestMetadata
            {
                PartnerCode = partnerCode,
                ControlNumber = envelope.ControlNumber,
                ReceivedTimestamp = DateTime.UtcNow,
                BlobPath = blobPath
            }
        };

        // Validate mapped request
        if (_options.EnableStrictValidation)
        {
            ValidateRequest(request);
        }

        return await Task.FromResult(request);
    }

    public async Task<EligibilityResponse> MapResponseAsync(X12Envelope envelope, string partnerCode, string blobPath)
    {
        _logger.LogInformation("Mapping 271 eligibility response for partner {PartnerCode}", partnerCode);

        var transaction = envelope.FunctionalGroups[0].Transactions[0];
        
        var response = new EligibilityResponse
        {
            // Extract TRN segment
            TransactionReferenceNumber = ExtractTransactionReference(transaction),
            
            // Extract BHT segment
            ResponseDate = ExtractResponseDate(transaction),
            
            // Extract member information
            MemberId = ExtractMemberId(transaction),
            MemberFirstName = ExtractMemberFirstName(transaction),
            MemberLastName = ExtractMemberLastName(transaction),
            
            // Extract DMG segment
            MemberDateOfBirth = ExtractMemberDateOfBirth(transaction),
            MemberGender = ExtractMemberGender(transaction),
            
            // Extract N3/N4 segments (Member Address)
            MemberAddress = ExtractMemberAddress(transaction),
            
            // Extract provider information
            ProviderNpi = ExtractProviderNpi(transaction),
            ProviderName = ExtractProviderName(transaction),
            
            // Extract EB segments (Eligibility/Benefit Information)
            CoverageDetails = ExtractCoverageDetails(transaction),
            
            Metadata = new ResponseMetadata
            {
                PartnerCode = partnerCode,
                ControlNumber = envelope.ControlNumber,
                ReceivedTimestamp = DateTime.UtcNow,
                MappedTimestamp = DateTime.UtcNow,
                BlobPath = blobPath
            }
        };

        // Validate mapped response
        if (_options.EnableStrictValidation)
        {
            ValidateResponse(response);
        }

        return await Task.FromResult(response);
    }

    // Private helper methods for segment extraction
    private string ExtractTransactionReference(X12Transaction transaction)
    {
        var trnSegment = transaction.Segments.FirstOrDefault(s => s.SegmentId == "TRN");
        return trnSegment?.Elements.ElementAtOrDefault(1) ?? string.Empty;
    }

    private DateTime ExtractRequestDate(X12Transaction transaction)
    {
        var bhtSegment = transaction.Segments.FirstOrDefault(s => s.SegmentId == "BHT");
        var dateStr = bhtSegment?.Elements.ElementAtOrDefault(3);
        var timeStr = bhtSegment?.Elements.ElementAtOrDefault(4);
        
        if (DateTime.TryParseExact(dateStr, "yyyyMMdd", null, System.Globalization.DateTimeStyles.None, out var date))
        {
            return date;
        }
        
        return DateTime.UtcNow;
    }

    // TODO: Implement remaining extraction methods
    // - ExtractMemberId
    // - ExtractMemberFirstName
    // - ExtractMemberLastName
    // - ExtractMemberDateOfBirth
    // - ExtractMemberGender
    // - ExtractProviderNpi
    // - ExtractProviderName
    // - ExtractServiceDate
    // - ExtractServiceTypeCodes
    // - ExtractMemberAddress
    // - ExtractCoverageDetails

    private void ValidateRequest(EligibilityRequest request)
    {
        if (string.IsNullOrEmpty(request.TransactionReferenceNumber))
            throw new InvalidOperationException("Transaction reference number is required");
        
        if (string.IsNullOrEmpty(request.MemberId))
            throw new InvalidOperationException("Member ID is required");
        
        if (string.IsNullOrEmpty(request.ProviderNpi))
            throw new InvalidOperationException("Provider NPI is required");
    }

    private void ValidateResponse(EligibilityResponse response)
    {
        if (string.IsNullOrEmpty(response.TransactionReferenceNumber))
            throw new InvalidOperationException("Transaction reference number is required");
        
        if (string.IsNullOrEmpty(response.MemberId))
            throw new InvalidOperationException("Member ID is required");
        
        if (string.IsNullOrEmpty(response.ProviderNpi))
            throw new InvalidOperationException("Provider NPI is required");
        
        if (!response.CoverageDetails.Any())
            _logger.LogWarning("No coverage details found in 271 response");
    }
}
```

---

### Step 5: Implement Function Triggers

**File:** `functions/EligibilityMapper.Function/MapperFunction.cs`

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
            
            // Determine transaction type (270 or 271)
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

            // Serialize to JSON
            var jsonData = JsonSerializer.Serialize(mappedData, new JsonSerializerOptions
            {
                WriteIndented = true
            });

            // Upload to mapped container
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

// Helper class for routing message
public class RoutingMessage
{
    public string BlobPath { get; set; } = string.Empty;
    public string PartnerCode { get; set; } = string.Empty;
    public string TransactionType { get; set; } = string.Empty;
    public string CorrelationId { get; set; } = string.Empty;
}
```

---

### Step 6: Configure DI Registration

**File:** `functions/EligibilityMapper.Function/Program.cs`

```csharp
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Azure.Storage.Blobs;
using Azure.Messaging.ServiceBus;
using EDI.X12;
using EDI.Storage;
using HealthcareEDI.EligibilityMapper.Services;
using HealthcareEDI.EligibilityMapper.Configuration;

var builder = FunctionsApplication.CreateBuilder(args);

builder.ConfigureFunctionsWebApplication();

// Azure SDK Clients
builder.Services.AddSingleton(sp =>
{
    var connectionString = builder.Configuration["StorageOptions:ConnectionString"];
    return new BlobServiceClient(connectionString);
});

builder.Services.AddSingleton(sp =>
{
    var connectionString = builder.Configuration["ServiceBusOptions:ConnectionString"];
    return new ServiceBusClient(connectionString);
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

---

### Step 7: Create Unit Tests

**File:** `tests/EligibilityMapper.Tests/EligibilityMappingServiceTests.cs`

```csharp
using Xunit;
using Moq;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using HealthcareEDI.EligibilityMapper.Services;
using HealthcareEDI.EligibilityMapper.Configuration;
using EDI.X12.Models;

namespace HealthcareEDI.EligibilityMapper.Tests;

public class EligibilityMappingServiceTests
{
    private readonly Mock<ILogger<EligibilityMappingService>> _loggerMock;
    private readonly IOptions<MappingOptions> _options;

    public EligibilityMappingServiceTests()
    {
        _loggerMock = new Mock<ILogger<EligibilityMappingService>>();
        _options = Options.Create(new MappingOptions
        {
            EnableStrictValidation = true
        });
    }

    [Fact]
    public async Task MapRequestAsync_ValidX12_ReturnsEligibilityRequest()
    {
        // Arrange
        var service = new EligibilityMappingService(_loggerMock.Object, _options);
        var envelope = CreateSampleX12270Envelope();

        // Act
        var result = await service.MapRequestAsync(envelope, "test-partner", "/test/path.x12");

        // Assert
        Assert.NotNull(result);
        Assert.NotEmpty(result.TransactionReferenceNumber);
        Assert.NotEmpty(result.MemberId);
        Assert.NotEmpty(result.ProviderNpi);
    }

    [Fact]
    public async Task MapResponseAsync_ValidX12_ReturnsEligibilityResponse()
    {
        // Arrange
        var service = new EligibilityMappingService(_loggerMock.Object, _options);
        var envelope = CreateSampleX12271Envelope();

        // Act
        var result = await service.MapResponseAsync(envelope, "test-partner", "/test/path.x12");

        // Assert
        Assert.NotNull(result);
        Assert.NotEmpty(result.TransactionReferenceNumber);
        Assert.NotEmpty(result.MemberId);
        Assert.NotEmpty(result.ProviderNpi);
        Assert.NotEmpty(result.CoverageDetails);
    }

    // TODO: Add more test cases
    // - Invalid transaction type
    // - Missing required fields
    // - Partner-specific mappings
    // - Date parsing edge cases

    private X12Envelope CreateSampleX12270Envelope()
    {
        // TODO: Create sample envelope for testing
        throw new NotImplementedException();
    }

    private X12Envelope CreateSampleX12271Envelope()
    {
        // TODO: Create sample envelope for testing
        throw new NotImplementedException();
    }
}
```

---

## Next Steps After EligibilityMapper

1. **Partner Configuration System** (Parallel work)
   - Define partner configuration schema
   - Implement PartnerConfigService
   - Create sample partner configs

2. **SQL Database Projects** (Week 13)
   - Control Numbers database
   - Enrollment Event Store database

3. **SFTP Connector** (Week 13-14)
   - SFTP client implementation
   - Connection pooling
   - File transfer operations

4. **Integration Tests** (Week 14)
   - End-to-end flow testing
   - Performance testing

---

## Success Criteria

✅ **EligibilityMapper Complete When:**
- [ ] Processes both 270 and 271 transactions
- [ ] Maps to internal JSON format
- [ ] Validates all required fields
- [ ] Handles errors gracefully
- [ ] Unit test coverage > 80%
- [ ] Integration tests pass
- [ ] Deployed to dev environment
- [ ] Documentation complete

---

## Resources

- **X12 270/271 Spec:** [CAQH CORE 270/271](https://www.caqh.org/core/eligibility-and-benefits)
- **InboundRouter Implementation:** `docs/functions/inbound-router-spec.md`
- **X12 Library:** Shared library `EDI.X12`
- **Sample X12 Files:** `tests/test-data/eligibility/`

---

**Ready to implement! 🚀**
