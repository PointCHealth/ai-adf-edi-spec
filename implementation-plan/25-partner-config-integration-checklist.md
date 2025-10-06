# Partner Configuration Integration - Quick Start Checklist

**Target**: EligibilityMapper Function  
**Time Estimate**: 2-3 hours  
**Prerequisites**: EDI.Configuration library built, sample configs ready  
**Related**: [Integration Guide](24-partner-config-integration-guide.md)

---

## Pre-Integration Checklist

Before starting integration:

- [ ] EDI.Configuration library builds successfully
- [ ] Sample partner configs created (PARTNERA, PARTNERB, INTERNAL-CLAIMS, TEST001)
- [ ] Access to edi-platform-core repository
- [ ] EligibilityMapper function currently working
- [ ] Local dev environment setup (Azure CLI logged in)

---

## Integration Steps

### Step 1: Add Project Reference (5 minutes)

**File**: `src/functions/EligibilityMapper/EligibilityMapper.csproj`

```xml
<!-- Add this inside <ItemGroup> with other project references -->
<ProjectReference Include="..\..\..\shared\EDI.Configuration\EDI.Configuration.csproj" />
```

**Verify**:
```powershell
cd C:\repos\edi-platform-core\src\functions\EligibilityMapper
dotnet build
# Should build with no errors
```

---

### Step 2: Update Configuration Files (10 minutes)

#### 2a. Update appsettings.json

**File**: `src/functions/EligibilityMapper/appsettings.json`

Add this section:
```json
{
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

#### 2b. Update local.settings.json

**File**: `src/functions/EligibilityMapper/local.settings.json`

Add these values:
```json
{
  "Values": {
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

### Step 3: Register Service in DI (5 minutes)

**File**: `src/functions/EligibilityMapper/Program.cs`

Add using statement at top:
```csharp
using EDI.Configuration.Extensions;
```

Add service registration (after other services, before `var app = builder.Build();`):
```csharp
// Partner Configuration Service
builder.Services.AddPartnerConfigService(builder.Configuration);
```

**Verify**:
```powershell
dotnet build
# Should build with no errors
```

---

### Step 4: Update Function Code (45-60 minutes)

#### 4a. Update Constructor

**File**: `src/functions/EligibilityMapper/Functions/EligibilityMapperFunction.cs`

Add using statements:
```csharp
using EDI.Configuration.Services;
using EDI.Configuration.Exceptions;
```

Add field and update constructor:
```csharp
private readonly IPartnerConfigService _partnerConfig;

public MapperFunction(
    ILogger<MapperFunction> logger,
    IX12Parser parser,
    IEligibilityMappingService mappingService,
    BlobStorageService storageService,
    IPartnerConfigService partnerConfig)  // NEW parameter
{
    _logger = logger;
    _parser = parser;
    _mappingService = mappingService;
    _storageService = storageService;
    _partnerConfig = partnerConfig;  // NEW assignment
}
```

#### 4b. Add Partner Validation

**File**: Same file, in the main function method

Add after deserializing routing message:
```csharp
// Validate partner exists and is active
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

// Validate partner supports this transaction type (after determining transactionType)
if (!partner.SupportsTransaction(transactionType))
{
    throw new UnsupportedTransactionException(
        routingMessage.PartnerCode, 
        transactionType);
}

// Log SLA targets for monitoring
_logger.LogInformation(
    "Processing {TransactionType} for partner {PartnerCode}. " +
    "SLA targets: Ingestion={IngestionP95}s, Ack999={Ack999}min",
    transactionType,
    routingMessage.PartnerCode,
    partner.Sla.IngestionLatencySecondsP95,
    partner.Sla.Ack999Minutes);
```

#### 4c. Update Exception Handling

Add catch blocks before the general catch:
```csharp
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
```

**Verify**:
```powershell
dotnet build
# Should build with no errors
```

---

### Step 5: Upload Sample Configs to Blob Storage (15 minutes)

#### 5a. Create Container (if not exists)

```powershell
az storage container create `
  --name partner-configs `
  --account-name stedideveasus2 `
  --auth-mode login
```

#### 5b. Upload Sample Configs

```powershell
cd C:\repos\ai-adf-edi-spec\config\partners\samples

# Upload each config
az storage blob upload `
  --account-name stedideveasus2 `
  --container-name partner-configs `
  --name "partners/PARTNERA.json" `
  --file ".\PARTNERA.json" `
  --auth-mode login `
  --overwrite

az storage blob upload `
  --account-name stedideveasus2 `
  --container-name partner-configs `
  --name "partners/PARTNERB.json" `
  --file ".\PARTNERB.json" `
  --auth-mode login `
  --overwrite

az storage blob upload `
  --account-name stedideveasus2 `
  --container-name partner-configs `
  --name "partners/INTERNAL-CLAIMS.json" `
  --file ".\INTERNAL-CLAIMS.json" `
  --auth-mode login `
  --overwrite

az storage blob upload `
  --account-name stedideveasus2 `
  --container-name partner-configs `
  --name "partners/TEST001.json" `
  --file ".\TEST001.json" `
  --auth-mode login `
  --overwrite
```

#### 5c. Verify Upload

```powershell
az storage blob list `
  --account-name stedideveasus2 `
  --container-name partner-configs `
  --prefix partners/ `
  --auth-mode login `
  --output table
```

Expected output: 4 blobs listed

---

### Step 6: Test Locally (20-30 minutes)

#### 6a. Start Function

```powershell
cd C:\repos\edi-platform-core\src\functions\EligibilityMapper
func start
```

Look for startup logs:
```
[INFO] Loading partner configurations...
[INFO] Loaded 4 partner configurations
```

#### 6b. Test with Valid Active Partner

Send test message to Service Bus with:
```json
{
  "blobPath": "inbound/PARTNERA/test_270.x12",
  "partnerCode": "PARTNERA",
  "transactionType": "270",
  "correlationId": "test-001"
}
```

Expected logs:
```
[INFO] Processing 270 for partner PARTNERA. SLA targets: Ingestion=30s, Ack999=15min
[INFO] Successfully mapped 270 transaction for Partner A Healthcare
```

#### 6c. Test with Inactive Partner

Send test message with:
```json
{
  "partnerCode": "TEST001",
  ...
}
```

Expected logs:
```
[WARN] Partner TEST001 is not active (status: inactive). Skipping processing.
```

Function should return without processing.

#### 6d. Test with Unknown Partner

Send test message with:
```json
{
  "partnerCode": "UNKNOWN",
  ...
}
```

Expected logs:
```
[ERROR] Partner not found: UNKNOWN
```

Message should be dead-lettered.

#### 6e. Test with Unsupported Transaction

Send PARTNERA message with transaction type "834":
```json
{
  "partnerCode": "PARTNERA",
  "transactionType": "834",
  ...
}
```

Expected logs:
```
[ERROR] Partner PARTNERA does not support transaction type 834
```

Message should be dead-lettered.

---

### Step 7: Verify Cache Behavior (10 minutes)

#### 7a. Check Cache Hit Rate

Look for logs like:
```
[INFO] Cache hit for partner PARTNERA
[INFO] Cache miss for partner PARTNERB, loading from storage
```

After first load, all subsequent requests should be cache hits.

#### 7b. Test Auto-Refresh

1. Modify a partner config in blob storage (e.g., change PARTNERA status to "inactive")
2. Wait 60 seconds (change detection interval)
3. Send test message with PARTNERA
4. Verify it's now skipped due to inactive status

Expected logs:
```
[INFO] Detected changes in partner configurations, refreshing cache
[INFO] Cache refreshed with 4 partner configurations
[WARN] Partner PARTNERA is not active (status: inactive). Skipping processing.
```

---

### Step 8: Commit Changes (10 minutes)

```powershell
cd C:\repos\edi-platform-core

git add .
git commit -m "feat: Integrate Partner Configuration System with EligibilityMapper

- Add EDI.Configuration project reference
- Register PartnerConfigService in DI
- Add partner validation before processing
- Add active status check
- Add transaction support validation
- Add SLA target logging
- Add specific exception handling for partner errors

Related: Phase 3, Partner Configuration System"

git push
```

---

## Validation Checklist

After integration, verify:

- [ ] Function builds with no errors
- [ ] Function starts successfully
- [ ] Logs show "Loaded X partner configurations" on startup
- [ ] Valid active partner processes successfully
- [ ] Inactive partner skipped with warning log
- [ ] Unknown partner throws PartnerNotFoundException
- [ ] Unsupported transaction throws UnsupportedTransactionException
- [ ] SLA targets logged for each transaction
- [ ] Cache hit rate >95% after warm-up
- [ ] Config changes detected within 60 seconds
- [ ] All unit tests still pass

---

## Troubleshooting

### Issue: "Partner configurations not loading"

**Check**:
1. Verify blob storage account name correct
2. Verify container name is "partner-configs"
3. Verify prefix is "partners/"
4. Verify Azure CLI logged in: `az account show`
5. Check function logs for storage errors

### Issue: "Build errors after adding reference"

**Fix**:
```powershell
# Clean and rebuild
dotnet clean
dotnet restore
dotnet build
```

### Issue: "PartnerConfigService not registered"

**Check**:
1. Verify `using EDI.Configuration.Extensions;` added
2. Verify `AddPartnerConfigService()` called in Program.cs
3. Verify call is before `builder.Build()`

### Issue: "All partners returning null"

**Check**:
1. Verify JSON files uploaded to blob storage
2. Verify JSON syntax valid: `Get-Content file.json | ConvertFrom-Json`
3. Check function logs for deserialization errors
4. Verify property names match exactly (case-sensitive)

---

## Performance Checklist

After integration, monitor:

- [ ] **Cache Hit Rate**: >95%
- [ ] **Lookup Performance**: <10ms for cached partners
- [ ] **Memory Usage**: ~1KB per partner
- [ ] **Startup Time**: <2 seconds additional
- [ ] **Blob Storage Calls**: ~1 per 5 minutes

---

## Next Functions to Integrate

After EligibilityMapper is complete and tested:

1. **InboundRouter** (2-3 hours) - Use partner config for routing decisions
2. **ClaimsMapper** (2 hours) - Same pattern as EligibilityMapper
3. **EnrollmentMapper** (2 hours) - Same pattern + event sourcing integration
4. **RemittanceMapper** (2 hours) - Same pattern as EligibilityMapper
5. **SFTP Connector** (2-3 hours) - Use partner endpoint configs

---

## Success Criteria

✅ **Integration is successful when**:

1. Function builds and runs without errors
2. Partner validation working (blocks unknown partners)
3. Active status check working (skips inactive partners)
4. Transaction support validation working (rejects unsupported)
5. SLA targets logged in Application Insights
6. Cache hit rate >95%
7. Config changes reflected within 60 seconds
8. All existing unit tests still pass
9. All integration tests still pass
10. No performance degradation

---

## Time Tracking

| Step | Estimated | Actual | Notes |
|------|-----------|--------|-------|
| 1. Add reference | 5 min | | |
| 2. Update config | 10 min | | |
| 3. Register service | 5 min | | |
| 4. Update function | 60 min | | |
| 5. Upload configs | 15 min | | |
| 6. Test locally | 30 min | | |
| 7. Verify cache | 10 min | | |
| 8. Commit changes | 10 min | | |
| **Total** | **2h 25m** | | |

Add 30-45 minutes for troubleshooting buffer = **3 hours total**

---

## Related Documents

- [Integration Guide (Full)](24-partner-config-integration-guide.md) - Detailed instructions
- [Integration Summary](PARTNER_CONFIG_INTEGRATION_SUMMARY.md) - Architecture and benefits
- [Sample Configs](../config/partners/samples/) - Ready-to-upload JSON files
- [EDI.Configuration README](../../edi-platform-core/shared/EDI.Configuration/README.md) - API reference

---

**Status**: ✅ Ready to execute  
**Next Action**: Follow Steps 1-8 in edi-platform-core repository
