# SFTP Connector Implementation Summary

**Date:** October 6, 2025  
**Status:** ✅ Implementation Complete | ⚠️ Refactoring Required  
**Repository:** [edi-sftp-connector](https://github.com/PointCHealth/edi-sftp-connector)

---

## Executive Summary

Successfully created a **standalone Azure Function repository** for SFTP file transfers with trading partners. The implementation is functionally complete with 25 files (1,818 lines of code), builds successfully, and includes comprehensive monitoring and error handling.

**However**, a code review revealed significant duplication of interfaces and models that already exist in **edi-platform-core**. Refactoring is required before production deployment to ensure consistency and maintainability across the EDI platform.

---

## ✅ What Was Implemented

### Repository: edi-sftp-connector

**GitHub URL:** https://github.com/PointCHealth/edi-sftp-connector  
**Commits:** 4 commits, latest: acd1693  
**Build Status:** ✅ Success (no errors, no warnings)

### Core Features

#### 1. Timer-Triggered Downloads (Every 15 Minutes)
- Connects to partner SFTP servers
- Downloads new files to Azure Blob Storage
- Archives or deletes remote files per configuration
- Tracks downloads for idempotency

#### 2. ServiceBus-Triggered Uploads
- Reads from `sftp-upload-queue`
- Downloads files from Blob Storage
- Uploads to partner SFTP servers
- Verifies uploads and records completion

#### 3. Services Implemented (6 Total)

**ISftpService / SftpService** (223 lines)
- SFTP operations with SSH.NET 2023.0.0
- Retry logic with Polly exponential backoff
- File operations: list, download, upload, archive, delete
- Host key verification

**IKeyVaultService / KeyVaultService** (73 lines)
- Secure credential retrieval from Azure Key Vault
- SSH key and password authentication support

**ITrackingService / TrackingService** (113 lines)
- File tracking in SQL database with Dapper
- Idempotency checks to prevent duplicates
- Filter new files from remote servers

**IPartnerConfigService / PartnerConfigService** (105 lines) ⚠️ *Duplicated - See Issue #1*
- Partner configuration loading from Blob Storage
- In-memory caching with 5-minute auto-refresh

#### 4. Models Created (5 Total)

- ✅ **SftpUploadRequest** - ServiceBus message schema (keep)
- ✅ **SftpCredentials** - Authentication credentials (keep)
- ✅ **FileTrackingRecord** - Tracking database model (keep)
- ⚠️ **PartnerConfig** - Simplified partner config (REMOVE - use core)
- ⚠️ **SftpConnectionConfig** - SFTP connection details (REFACTOR)

#### 5. Azure Functions (2 Total)

**SftpDownloadFunction.cs** (185 lines)
- Timer trigger: `0 */15 * * * *` (every 15 minutes)
- Processes all active partners with SFTP inbound
- Downloads files concurrently
- Custom metrics for monitoring

**SftpUploadFunction.cs** (182 lines)
- ServiceBus queue trigger: `sftp-upload-queue`
- Dead letter queue for permanent failures
- File verification after upload
- Retry handling (3 attempts)

#### 6. Infrastructure

**SQL Database**
- FileTracking table with 3 indexes
- Supports idempotency and correlation tracking

**Configuration**
- host.json - ServiceBus and retry policies
- appsettings.json - Default settings
- local.settings.sample.json - Template
- SftpConnectorOptions - Configurable timeout, retries, schedule

**Documentation**
- README.md (comprehensive)
- IMPLEMENTATION_CHECKLIST.md
- REPOSITORY_CREATION_SUMMARY.md
- REFACTOR_PLAN.md ⭐

### Technology Stack

- .NET 8.0, Azure Functions Worker 1.21.0
- SSH.NET 2023.0.0
- Azure SDKs: Storage Blobs 12.19.0, Key Vault 4.5.0, Identity 1.13.1, ServiceBus 7.17.5
- Polly 8.2.0 (resilience)
- Dapper 2.1.24 (data access)
- Application Insights

---

## ⚠️ Issues Identified

### Issue #1: Duplicated IPartnerConfigService

**Problem:** Created custom `IPartnerConfigService` that duplicates the one in **edi-platform-core**.

**Core Interface (Already Exists):**
```csharp
// From: edi-platform-core/shared/EDI.Configuration/Services/IPartnerConfigService.cs
Task<PartnerConfig?> GetPartnerAsync(string partnerCode, CancellationToken cancellationToken = default);
Task<List<PartnerConfig>> GetAllPartnersAsync(CancellationToken cancellationToken = default);
Task<List<PartnerConfig>> GetActivePartnersAsync(CancellationToken cancellationToken = default);
Task<List<PartnerConfig>> GetPartnersByTypeAsync(PartnerType partnerType, CancellationToken cancellationToken = default);
Task RefreshCacheAsync(CancellationToken cancellationToken = default);
```

**What I Created (Wrong):**
```csharp
Task<IEnumerable<PartnerConfig>> GetInboundSftpPartnersAsync(CancellationToken cancellationToken = default);
Task<PartnerConfig?> GetPartnerConfigAsync(string partnerId, CancellationToken cancellationToken = default);
```

**Impact:** Configuration schema divergence, duplicate code, inconsistent naming.

---

### Issue #2: Duplicated PartnerConfig Model

**Problem:** Created simplified `PartnerConfig` instead of using the rich model from **edi-platform-core**.

**Core Model (Already Exists):**
```csharp
// From: edi-platform-core/shared/EDI.Configuration/Models/PartnerConfig.cs
public class PartnerConfig
{
    public string PartnerCode { get; set; }  // Not "PartnerId"
    public string Name { get; set; }
    public PartnerType PartnerType { get; set; }  // Enum: EXTERNAL/INTERNAL
    public PartnerStatus Status { get; set; }     // Enum: draft/active/inactive
    public List<string> ExpectedTransactions { get; set; }
    public DataFlowConfig DataFlow { get; set; }
    public EndpointConfig? Endpoint { get; set; }  // ⭐ Proper SFTP config location
    public IntegrationConfig? Integration { get; set; }
    public AcknowledgmentConfig Acknowledgments { get; set; }
    public SlaConfig Sla { get; set; }
}
```

**What I Created (Wrong):**
```csharp
public class PartnerConfig
{
    public required string PartnerId { get; set; }      // Should be "PartnerCode"
    public required string PartnerName { get; set; }    // Should be "Name"
    public required string Status { get; set; }         // Should be enum
    public required IntegrationConfig IntegrationConfig { get; set; }  // Wrong structure
}
```

**Impact:** 
- Field name mismatch: `partnerId` vs `partnerCode`
- Missing important fields: PartnerType, ExpectedTransactions, DataFlow, Endpoint, SLA
- String status instead of enum
- Wrong configuration structure

---

### Issue #3: Wrong SFTP Configuration Location

**Problem:** Created `SftpConnectionConfig` with server details in partner config. Should use `EndpointConfig.Sftp`.

**Core Structure (Already Exists):**
```csharp
// From: edi-platform-core/shared/EDI.Configuration/Models/EndpointConfig.cs
public class EndpointConfig
{
    public EndpointType Type { get; set; }  // SFTP, SERVICE_BUS, REST_API, DATABASE
    public SftpEndpointConfig? Sftp { get; set; }
}

public class SftpEndpointConfig
{
    public string HomePath { get; set; }
    public bool PgpRequired { get; set; }
}
```

**What I Created (Wrong):**
```csharp
public class SftpConnectionConfig
{
    public string Host { get; set; }              // Should be in Key Vault/App Config
    public int Port { get; set; }                 // Should be in Key Vault/App Config
    public string Username { get; set; }          // Should be in Key Vault/App Config
    public string AuthType { get; set; }          // Should be in Key Vault/App Config
    public string KeyVaultSecretName { get; set; }
    public string RemoteDirectory { get; set; }
    public string? FilePattern { get; set; }
    // ... etc
}
```

**Impact:** 
- Mixed partner-specific config (home path) with server connection details (host, port)
- SFTP credentials in partner config JSON (security concern)
- Doesn't align with core's endpoint abstraction

**Correct Approach:**
- **Partner Config** (in blob storage): `EndpointConfig.Sftp.HomePath`, `PgpRequired`
- **SFTP Server Details** (in Key Vault or App Configuration): Host, Port, Username, AuthType, Credentials

---

### Issue #4: IBlobStorageService Not Used

**Problem:** Used `BlobContainerClient` directly instead of core's `IBlobStorageService` abstraction.

**Core Interface (Available):**
```csharp
// From: edi-platform-core/shared/EDI.Storage/Interfaces/IBlobStorageService.cs
Task<string> UploadAsync(string containerName, string blobName, Stream content, ...);
Task<Stream> DownloadAsync(string containerName, string blobName, ...);
Task<bool> ExistsAsync(string containerName, string blobName, ...);
Task DeleteAsync(string containerName, string blobName, ...);
Task<IEnumerable<string>> ListBlobsAsync(string containerName, string? prefix = null, ...);
```

**Impact:** Tight coupling to Azure Storage SDK, harder to test, inconsistent with other functions.

---

## 📋 Refactoring Plan

**Document:** See `REFACTOR_PLAN.md` in edi-sftp-connector repository  
**Priority:** HIGH  
**Estimated Effort:** 6-9 hours  
**Status:** Documented, ready for implementation

### Phase 1: Add Core References (1 hour)
1. Add project reference to `EDI.Configuration` shared library
2. Add project reference to `EDI.Storage` shared library
3. Update .csproj and restore packages

### Phase 2: Remove Duplicated Models (1 hour)
1. ❌ Delete `Models/PartnerConfig.cs`
2. ❌ Delete `Services/IPartnerConfigService.cs`
3. ❌ Delete `Services/PartnerConfigService.cs`
4. ✅ Keep `Models/SftpUploadRequest.cs`
5. ✅ Keep `Models/SftpCredentials.cs`
6. ✅ Keep `Models/FileTrackingRecord.cs`

### Phase 3: Refactor SftpConnectionConfig (1-2 hours)
- Create `SftpServerConfig` for Key Vault/App Config stored settings (host, port, auth)
- Use core's `EndpointConfig.Sftp` for partner-specific settings (home path, PGP)
- Update Key Vault structure to store server connection details separately

### Phase 4: Update Functions (2-3 hours)
1. Update imports to use `EDI.Configuration.Models` and `EDI.Configuration.Services`
2. Change filtering logic in `SftpDownloadFunction`:
   ```csharp
   var partners = await _partnerConfigService.GetActivePartnersAsync(cancellationToken);
   var sftpPartners = partners.Where(p => 
       p.Endpoint?.Type == EndpointType.SFTP && 
       p.Endpoint.Sftp != null);
   ```
3. Update field access: `partner.PartnerId` → `partner.PartnerCode`
4. Handle `EndpointConfig.Sftp.HomePath` instead of `SftpConfig.RemoteDirectory`

### Phase 5: Update Configuration Schema (1 hour)
- Document new partner config structure
- Create migration guide for existing configs
- Update sample configurations in documentation

### Phase 6: Update DI & Testing (1-2 hours)
- Update `Program.cs` to register core services
- Update unit tests to use core models
- Verify builds and tests pass

---

## 🎯 Migration Path

### Old Config (Current - Wrong)
```json
{
  "partnerId": "PARTNERA",
  "partnerName": "Partner A",
  "status": "Active",
  "integrationConfig": {
    "inbound": {
      "adapterType": "SFTP",
      "sftpConfig": {
        "host": "sftp.partnera.com",
        "port": 22,
        "username": "edi-user",
        "authType": "SSHKey",
        "keyVaultSecretName": "partnera-sftp-key",
        "remoteDirectory": "/inbound"
      }
    }
  }
}
```

### New Config (Target - Correct)
```json
{
  "partnerCode": "PARTNERA",
  "name": "Partner A Corporation",
  "partnerType": "EXTERNAL",
  "status": "active",
  "expectedTransactions": ["837", "835"],
  "dataFlow": {
    "inbound": { "enabled": true, "priority": "high" },
    "outbound": { "enabled": true, "priority": "normal" }
  },
  "endpoint": {
    "type": "SFTP",
    "sftp": {
      "homePath": "/edi/partnera",
      "pgpRequired": false
    }
  },
  "sla": {
    "processingTimeMinutes": 30,
    "acknowledgmentTimeoutMinutes": 60
  }
}
```

### SFTP Server Config (Separate - Key Vault or App Config)
```json
{
  "partnera-sftp-server": {
    "host": "sftp.partnera.com",
    "port": 22,
    "username": "edi-user",
    "authType": "SSHKey",
    "keyVaultSecretName": "partnera-sftp-key"
  }
}
```

---

## 📊 Impact Assessment

### Benefits of Refactoring

✅ **Consistency** - All functions use same partner config schema  
✅ **Maintainability** - Single source of truth for partner config  
✅ **Code Reuse** - Leverage existing, tested implementations  
✅ **Type Safety** - Proper enums instead of strings  
✅ **Rich Features** - Access to SLA, acknowledgments, routing priorities  
✅ **Security** - Proper separation of partner config from credentials  

### Risks Without Refactoring

❌ **Schema Divergence** - Different configs for different functions  
❌ **Technical Debt** - Duplicated code hard to maintain  
❌ **Breaking Changes Later** - More painful to fix after deployment  
❌ **Testing Issues** - Need to test multiple config formats  
❌ **Security Concerns** - Credentials in partner config JSON  

---

## ✅ What Can Stay (SFTP-Specific)

These components are SFTP-specific and should remain:

1. ✅ **ISftpService / SftpService** - SSH.NET operations
2. ✅ **ITrackingService / TrackingService** - File tracking
3. ✅ **IKeyVaultService / KeyVaultService** - Credential retrieval
4. ✅ **SftpUploadRequest** - ServiceBus message schema
5. ✅ **SftpCredentials** - Credential model
6. ✅ **FileTrackingRecord** - Tracking database model
7. ✅ **SftpDownloadFunction** - Timer trigger implementation
8. ✅ **SftpUploadFunction** - ServiceBus trigger implementation
9. ✅ **SQL Schema** - FileTracking table

---

## 📅 Recommended Timeline

### Before Production Deployment

**Week 1: Refactoring (6-9 hours)**
- Days 1-2: Add core references, remove duplicates
- Days 3-4: Refactor configuration structure
- Day 5: Update functions and DI

**Week 2: Testing (8-12 hours)**
- Create unit tests with core models
- Integration tests with Docker SFTP server
- End-to-end testing with sample partners

**Week 3: Documentation & Deployment (4-6 hours)**
- Update all documentation
- Create migration guide
- Deploy to Azure Dev
- Partner onboarding guide

**Total: 18-27 hours (2.5-3.5 weeks part-time)**

---

## 🎯 Next Steps

### Immediate (This Week)
1. ✅ Review refactoring plan with team
2. ⏳ Create feature branch: `refactor/use-core-libraries`
3. ⏳ Phase 1: Add project references to edi-platform-core
4. ⏳ Phase 2: Remove duplicated code

### Short-Term (Next 2 Weeks)
5. ⏳ Phase 3-4: Refactor configuration and functions
6. ⏳ Phase 5-6: Update DI, schema, and tests
7. ⏳ Code review and merge to main

### Before Production
8. ⏳ Deploy to Azure Dev with new schema
9. ⏳ Test with sandbox partner
10. ⏳ Update all documentation
11. ⏳ Production deployment readiness review

---

## 📝 Lessons Learned

### What Went Well
✅ Comprehensive implementation of SFTP functionality  
✅ Proper error handling and retry logic  
✅ Good separation of concerns (services, models, functions)  
✅ Complete documentation  
✅ Successful build with no errors  

### What Could Be Improved
⚠️ Should have reviewed edi-platform-core first  
⚠️ Should have reused existing interfaces  
⚠️ Should have validated config schema early  
⚠️ Should have consulted team about shared libraries  

### Key Takeaway
> **Always review shared libraries before implementing new services to avoid code duplication and ensure architectural consistency.**

---

## 📚 Related Documentation

- [REFACTOR_PLAN.md](https://github.com/PointCHealth/edi-sftp-connector/blob/main/REFACTOR_PLAN.md) - Detailed refactoring steps
- [REPOSITORY_CREATION_SUMMARY.md](https://github.com/PointCHealth/edi-sftp-connector/blob/main/REPOSITORY_CREATION_SUMMARY.md) - Implementation details
- [README.md](https://github.com/PointCHealth/edi-sftp-connector/blob/main/README.md) - User documentation
- [edi-platform-core](https://github.com/PointCHealth/edi-platform-core) - Shared libraries

---

**Status:** 📋 Refactoring Plan Created - Awaiting Implementation  
**Priority:** HIGH  
**Owner:** EDI Platform Team  
**Last Updated:** October 6, 2025
