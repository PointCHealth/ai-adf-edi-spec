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

### 🚧 Phase 2: Configuration Models (In Progress)
- [ ] Create `MappingOptions.cs` - Mapping configuration
- [ ] Update `.csproj` with correct package references
- [ ] Create `appsettings.json` with EligibilityMapper settings

### ⏭️ Phase 3: Data Models (Not Started)
- [ ] Create `EligibilityRequest.cs` - 270 internal model
- [ ] Create `EligibilityResponse.cs` - 271 internal model
- [ ] Create `RoutingMessage.cs` - Service Bus message model

### ⏭️ Phase 4: Mapping Service (Not Started)
- [ ] Create `IEligibilityMappingService` interface
- [ ] Implement `EligibilityMappingService` class
- [ ] Implement X12 segment extraction methods:
  - [ ] `ExtractTransactionReference` (TRN segment)
  - [ ] `ExtractRequestDate` / `ExtractResponseDate` (BHT segment)
  - [ ] `ExtractMemberId` (NM1*IL segment)
  - [ ] `ExtractMemberNames` (NM1*IL segment)
  - [ ] `ExtractMemberDateOfBirth` (DMG segment)
  - [ ] `ExtractMemberGender` (DMG segment)
  - [ ] `ExtractProviderNpi` (NM1*1P segment)
  - [ ] `ExtractProviderName` (NM1*1P segment)
  - [ ] `ExtractServiceDate` (DTP*291 segment)
  - [ ] `ExtractServiceTypeCodes` (EQ segments - 270 only)
  - [ ] `ExtractMemberAddress` (N3/N4 segments - 271 only)
  - [ ] `ExtractCoverageDetails` (EB segments - 271 only)
- [ ] Implement validation logic
- [ ] Add partner-specific mapping overrides support

### ⏭️ Phase 5: Function Implementation (Not Started)
- [ ] Create `MapperFunction.cs`
- [ ] Implement Service Bus trigger (`ProcessEligibilityTransaction`)
- [ ] Add blob download logic
- [ ] Add X12 parsing
- [ ] Add mapping orchestration (270 vs 271 routing)
- [ ] Add JSON serialization
- [ ] Add output blob upload
- [ ] Add error handling and logging

### ⏭️ Phase 6: Dependency Injection (Not Started)
- [ ] Create `Program.cs`
- [ ] Register Azure SDK clients (BlobServiceClient, ServiceBusClient)
- [ ] Register EDI services (IX12Parser, BlobStorageService)
- [ ] Register EligibilityMapper services (IEligibilityMappingService)
- [ ] Configure options (MappingOptions)
- [ ] Add Application Insights

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
├── Configuration/               (created, empty)
├── Models/                      (created, empty)
├── Services/                    (created, empty)
├── Functions/                   (created, empty)
└── EligibilityMapper.Function.csproj  (copied from InboundRouter)
```

---

## Next Immediate Actions

### 1. Create MappingOptions Configuration (Next)
File: `Configuration/MappingOptions.cs`

### 2. Update Project File (Next)
File: `EligibilityMapper.Function.csproj`
- Update assembly name
- Update root namespace
- Verify package references

### 3. Create Data Models
Files:
- `Models/EligibilityRequest.cs`
- `Models/EligibilityResponse.cs`
- `Models/Address.cs`
- `Models/CoverageDetail.cs`
- `Models/RequestMetadata.cs`
- `Models/ResponseMetadata.cs`
- `Models/RoutingMessage.cs`

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
- [ ] All configuration models created
- [ ] All data models created
- [ ] Mapping service fully implemented
- [ ] Function triggers configured
- [ ] DI registration complete
- [ ] Unit tests > 80% coverage
- [ ] Integration tests pass
- [ ] Processes 270 transactions successfully
- [ ] Processes 271 transactions successfully
- [ ] Handles errors gracefully
- [ ] Deployed to dev environment
- [ ] End-to-end test successful (blob → router → mapper → storage)

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
