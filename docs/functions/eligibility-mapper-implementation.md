# EligibilityMapper Function - Implementation Log

**Status:** 🚧 In Progress  
**Started:** January 6, 2025  
**Priority:** Phase 3 - Critical Path

---

## Implementation Progress

### ✅ Phase 1: Project Setup (Complete)
- [x] Created `functions/EligibilityMapper.Function` directory
- [x] Created project structure (Configuration, Models, Services, Functions)
- [x] Copied base `.csproj` from InboundRouter as template

### ✅ Phase 2: Configuration Models (Complete)
- [x] Create `MappingOptions.cs` - Mapping configuration
- [x] Update `.csproj` with correct package references (namespace updated to HealthcareEDI.EligibilityMapper)
- [x] Create `appsettings.json` with EligibilityMapper settings
- [x] Create `host.json` with Service Bus configuration
- [x] Create `Program.cs` with DI setup

### ✅ Phase 3: Data Models (Complete)
- [x] Create `EligibilityRequest.cs` - 270 internal model with RequestMetadata
- [x] Create `EligibilityResponse.cs` - 271 internal model with ResponseMetadata, Address, CoverageDetail
- [x] Create `RoutingMessage.cs` - Service Bus message model

### ✅ Phase 4: Mapping Service (Complete)
- [x] Create `IEligibilityMappingService` interface (1,471 bytes)
- [x] Implement `EligibilityMappingService` class (22,735 bytes)
- [x] Implement X12 segment extraction methods:
  - [x] `ExtractTransactionReference` (TRN segment)
  - [x] `ExtractRequestDate` / `ExtractResponseDate` (BHT segment)
  - [x] `ExtractMemberId` (NM1*IL segment)
  - [x] `ExtractMemberNames` (NM1*IL segment for both request/response)
  - [x] `ExtractMemberDateOfBirth` (DMG segment for both request/response)
  - [x] `ExtractMemberGender` (DMG segment for both request/response)
  - [x] `ExtractProviderNpi` (NM1*1P segment)
  - [x] `ExtractProviderName` (NM1*1P segment for both request/response)
  - [x] `ExtractServiceDate` (DTP*291 segment)
  - [x] `ExtractServiceTypeCodes` (EQ segments - 270 only)
  - [x] `ExtractMemberAddress` (N3/N4 segments - 271 only)
  - [x] `ExtractCoverageDetails` (EB segments - 271 only)
- [x] Implement validation logic (ValidateRequest, ValidateResponse)
- [x] Add helper methods (ParseX12Date, ParseX12DateTime, GetServiceTypeName)
- [x] Add partner-specific mapping overrides support (configured in MappingOptions)

### ✅ Phase 5: Function Implementation (Complete)
- [x] Create `MapperFunction.cs` (7,847 bytes)
- [x] Implement Service Bus trigger listening to `eligibility-mapper-queue`
- [x] Add blob download logic (DownloadX12FileAsync)
- [x] Add X12 parsing (ParseX12TransactionAsync using IX12Parser)
- [x] Add mapping orchestration (270 vs 271 routing logic)
- [x] Add JSON serialization with camelCase property naming
- [x] Add output blob upload (UploadMappedDataAsync to `mapped` container)
- [x] Add error handling with retry and dead-letter logic (max 3 delivery attempts)
- [x] Add comprehensive logging at all stages

### ✅ Phase 6: Dependency Injection (Complete)
- [x] Create `Program.cs` with FunctionsApplication.CreateBuilder pattern
- [x] Register Azure SDK clients (BlobServiceClient, ServiceBusClient as singletons)
- [x] Register EDI services (IX12Parser, BlobStorageService as scoped)
- [x] Register EligibilityMapper services (IEligibilityMappingService as scoped)
- [x] Configure options (MappingOptions from appsettings.json)
- [x] Add Application Insights (telemetry worker service)

### ⏭️ Phase 7: Testing (Not Started)
- [ ] Create `EligibilityMapper.Tests` project
- [ ] Create `EligibilityMappingServiceTests.cs`
- [ ] Add test for 270 request mapping
- [ ] Add test for 271 response mapping
- [ ] Add test for validation errors
- [ ] Add test for missing required fields
- [ ] Create sample X12 test data (270 and 271)
- [ ] Add integration tests (Service Bus → Mapper → Storage)

### ⏭️ Phase 8: Configuration & Deployment (Not Started)
- [ ] Create `local.settings.json` template
- [ ] Document Service Bus queue configuration
- [ ] Document storage container configuration
- [ ] Add to CI/CD pipeline
- [ ] Deploy to dev environment
- [ ] Run end-to-end tests

---

## Current File Structure

```
functions/EligibilityMapper.Function/
├── Configuration/
│   └── MappingOptions.cs                    ✅ Created
├── Models/
│   ├── EligibilityRequest.cs                ✅ Created
│   ├── EligibilityResponse.cs               ✅ Created
│   └── RoutingMessage.cs                    ✅ Created
├── Services/
│   ├── IEligibilityMappingService.cs        ✅ Created (1,471 bytes)
│   └── EligibilityMappingService.cs         ✅ Created (22,735 bytes, 15+ methods)
├── Functions/
│   └── MapperFunction.cs                    ✅ Created (7,847 bytes)
├── EligibilityMapper.Function.csproj        ✅ Updated
├── Program.cs                               ✅ Created & Updated
├── host.json                                ✅ Created
└── appsettings.json                         ✅ Created
```

---

## Next Immediate Actions

### 7. Create Unit Tests (Next - High Priority)
Files:
- Create `tests/EligibilityMapper.Tests` project
- Create `EligibilityMappingServiceTests.cs` with tests for all segment extraction methods
- Create test fixtures with sample X12 270/271 data

Focus: Validate mapping logic with comprehensive test coverage (>80%)

### 8. Create Integration Tests
- Test end-to-end flow: Service Bus → MapperFunction → Blob Storage
- Test with real X12 samples from Phase 3 Quick Start guide
- Verify JSON output format and structure

### 9. Deploy and Test
- Create `local.settings.json` for local development
- Deploy to dev environment
- Run end-to-end validation

---

## X12 270/271 Segment Reference

### X12 270 (Eligibility Request) Key Segments

```
ST*270*0001*005010X279A1~           Transaction Set Header
BHT*0022*13*REF123*20250106*1200~   Beginning of Hierarchical Transaction
HL*1**20*1~                         Hierarchical Level (Information Source)
NM1*PR*2*INSURANCE CO*****PI*12345~ Name (Payer)
HL*2*1*21*1~                        Hierarchical Level (Information Receiver)
NM1*1P*2*PROVIDER*****XX*1234567890~ Name (Provider)
HL*3*2*22*0~                        Hierarchical Level (Subscriber)
TRN*1*REF456*1234567890~            Trace Number
NM1*IL*1*DOE*JOHN****MI*MEMBER123~  Name (Insured/Member)
DMG*D8*19800115*M~                  Demographics
DTP*291*D8*20250106~                Date/Time (Service Date)
EQ*30~                              Service Type Code
SE*13*0001~                         Transaction Set Trailer
```

### X12 271 (Eligibility Response) Key Segments

```
ST*271*0002*005010X279A1~           Transaction Set Header
BHT*0022*11*REF123*20250106*1201~   Beginning of Hierarchical Transaction
HL*1**20*1~                         Hierarchical Level (Information Source)
NM1*PR*2*INSURANCE CO*****PI*12345~ Name (Payer)
HL*2*1*21*1~                        Hierarchical Level (Information Receiver)
NM1*1P*2*PROVIDER*****XX*1234567890~ Name (Provider)
HL*3*2*22*0~                        Hierarchical Level (Subscriber)
TRN*2*REF456*1234567890~            Trace Number
NM1*IL*1*DOE*JOHN****MI*MEMBER123~  Name (Insured/Member)
N3*123 MAIN ST~                     Address
N4*ANYTOWN*CA*12345~                City/State/ZIP
DMG*D8*19800115*M~                  Demographics
DTP*291*D8*20250106~                Date/Time (Service Date)
EB*1*FAM*30**HEALTH BENEFIT PLAN~   Eligibility/Benefit Information
SE*15*0002~                         Transaction Set Trailer
```

### Segment Extraction Mapping

| Segment | Purpose | Used In | Extract Method |
|---------|---------|---------|----------------|
| TRN | Transaction Reference Number | 270, 271 | `ExtractTransactionReference` |
| BHT | Transaction Date/Time | 270, 271 | `ExtractRequestDate` / `ExtractResponseDate` |
| NM1*IL | Member ID and Name | 270, 271 | `ExtractMemberId`, `ExtractMemberNames` |
| NM1*1P | Provider NPI and Name | 270, 271 | `ExtractProviderNpi`, `ExtractProviderName` |
| DMG | Member Demographics | 270, 271 | `ExtractMemberDateOfBirth`, `ExtractMemberGender` |
| DTP*291 | Service Date | 270, 271 | `ExtractServiceDate` |
| EQ | Service Type Code | 270 only | `ExtractServiceTypeCodes` |
| N3 | Member Street Address | 271 only | `ExtractMemberAddress` |
| N4 | Member City/State/ZIP | 271 only | `ExtractMemberAddress` |
| EB | Coverage Details | 271 only | `ExtractCoverageDetails` |

---

## Implementation Notes

### EDI.X12 Library Usage

The EligibilityMapper uses the shared `EDI.X12` library for X12 parsing:

```csharp
// Parse X12 envelope
var envelope = await _parser.ParseAsync(blobStream);

// Access transaction
var transaction = envelope.FunctionalGroups[0].Transactions[0];

// Access segments
var trnSegment = transaction.Segments.FirstOrDefault(s => s.SegmentId == "TRN");
var element1 = trnSegment?.Elements.ElementAtOrDefault(1); // Reference Number
```

### Service Bus Message Format

Expected message from InboundRouter:

```json
{
  "blobPath": "inbound/partner001/file_20250106_120000.x12",
  "partnerCode": "partner001",
  "transactionType": "270",
  "correlationId": "abc123-def456-ghi789"
}
```

### Output Format

Mapped transactions are saved as JSON in the `mapped` container:

```
mapped/
  ├── partner001/
  │   ├── 270_abc123_20250106120000.json  (eligibility request)
  │   └── 271_def456_20250106120100.json  (eligibility response)
  └── partner002/
      └── ...
```

---

## Success Criteria

✅ **EligibilityMapper is complete when:**
- [x] All configuration models created (MappingOptions)
- [x] All data models created (EligibilityRequest, EligibilityResponse, RoutingMessage)
- [x] Mapping service fully implemented (IEligibilityMappingService, EligibilityMappingService with 15+ methods)
- [x] Function triggers configured (MapperFunction with Service Bus trigger)
- [x] DI registration complete (Program.cs)
- [x] Build successful (dotnet build completes without errors)
- [ ] Unit tests > 80% coverage
- [ ] Integration tests pass
- [ ] Processes 270 transactions successfully
- [ ] Processes 271 transactions successfully
- [ ] Handles errors gracefully
- [ ] Deployed to dev environment
- [ ] End-to-end test successful (blob → router → mapper → storage)

**Progress: 6 of 13 criteria complete (46%)**

**Code Statistics:**
- Total lines: ~31,000 bytes across 11 files
- Mapping service: 22,735 bytes (570+ lines, 15+ extraction methods)
- Function implementation: 7,847 bytes (260+ lines)
- Build status: ✅ Successful

---

## Resources

- **Phase 3 Quick Start:** [PHASE_3_QUICK_START.md](../../PHASE_3_QUICK_START.md)
- **X12 270/271 Spec:** CAQH CORE 270/271 Implementation Guide
- **InboundRouter Spec:** [inbound-router-spec.md](./inbound-router-spec.md)
- **EDI.X12 Library:** `libs/EDI.X12/`
- **Test Data:** To be created in `tests/test-data/eligibility/`

---

**Last Updated:** January 6, 2025 9:02 PM  
**Next Update:** After completing Phase 2 (Configuration Models)
