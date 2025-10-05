# AI Prompt: Create Partner Configuration & Onboarding

## Objective
Create comprehensive trading partner configuration schema, validation logic, and automated onboarding workflow.

## Prerequisites
- Infrastructure deployed
- Configuration storage ready
- Partner agreement signed
- Technical specifications received from partner

## Prompt

```
I need you to create a comprehensive trading partner configuration system for the Healthcare EDI Platform.

Context:
- Project: Healthcare EDI platform processing 837 (Claims), 835 (Remittance), 270/271 (Eligibility)
- Partners: Health plans, clearinghouses, providers
- Configuration: Partner-specific routing, mapping, validation rules
- Storage: JSON files in blob storage, referenced by functions
- Target: <5 day partner onboarding time

Review specifications:
[Reference: implementation-plan/12-partner-onboarding-playbook.md]
[Reference: implementation-plan/19-partner-configuration-schema.md]

Please create:

---

## 1. Partner Configuration JSON Schema

Create file: `config/schemas/partner-config.schema.json`

Requirements:
- JSON Schema Draft 2020-12
- Comprehensive validation rules
- Support for multiple transaction types
- Support for inbound and outbound flows

Schema structure:
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://edi-platform.company.com/schemas/partner-config.v1.json",
  "title": "EDI Trading Partner Configuration",
  "description": "Configuration schema for EDI trading partner setup",
  "type": "object",
  "required": ["partnerId", "partnerName", "status", "connection", "transactionTypes"],
  "properties": {
    "partnerId": {
      "type": "string",
      "pattern": "^[A-Z0-9]{6,10}$",
      "description": "Unique partner identifier"
    },
    "partnerName": { ... },
    "status": { "enum": ["active", "inactive", "testing", "suspended"] },
    "connection": {
      "type": "object",
      "required": ["protocol", "credentials"],
      "properties": {
        "protocol": { "enum": ["SFTP", "AS2", "HTTPS", "Azure-Blob"] },
        "sftp": { ... },
        "as2": { ... },
        "https": { ... }
      }
    },
    "edi": {
      "type": "object",
      "properties": {
        "isaQualifier": { "type": "string", "pattern": "^[0-9]{2}$" },
        "isaId": { "type": "string", "maxLength": 15 },
        "gsApplicationCode": { "type": "string", "maxLength": 15 },
        "controlNumberManagement": { ... },
        "segmentTerminator": { "default": "~" },
        "elementSeparator": { "default": "*" },
        "subelementSeparator": { "default": ":" }
      }
    },
    "transactionTypes": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["transactionType", "direction", "enabled"],
        "properties": {
          "transactionType": { "enum": ["837P", "837I", "837D", "835", "270", "271", "276", "277", "278"] },
          "direction": { "enum": ["inbound", "outbound", "both"] },
          "enabled": { "type": "boolean" },
          "validation": {
            "type": "object",
            "properties": {
              "schemaValidation": { "type": "boolean", "default": true },
              "businessRules": { "type": "array", "items": { "type": "string" } },
              "customValidators": { "type": "array" }
            }
          },
          "mapping": {
            "type": "object",
            "properties": {
              "mappingFile": { "type": "string", "pattern": "^[a-zA-Z0-9_-]+\\.json$" },
              "transformations": { "type": "array" }
            }
          },
          "routing": {
            "type": "object",
            "properties": {
              "inboundQueue": { "type": "string" },
              "outboundDestination": { "type": "string" },
              "errorQueue": { "type": "string" }
            }
          }
        }
      }
    },
    "sla": {
      "type": "object",
      "properties": {
        "processingTime": { "type": "integer", "description": "Max processing time in minutes" },
        "deliveryTime": { "type": "integer", "description": "Max delivery time in minutes" },
        "availability": { "type": "number", "minimum": 0, "maximum": 100 }
      }
    },
    "notifications": {
      "type": "object",
      "properties": {
        "email": { "type": "array", "items": { "type": "string", "format": "email" } },
        "webhook": { "type": "string", "format": "uri" },
        "events": { "type": "array", "items": { "enum": ["file-received", "file-processed", "error", "sla-breach"] } }
      }
    },
    "security": {
      "type": "object",
      "properties": {
        "ipWhitelist": { "type": "array", "items": { "type": "string", "format": "ipv4" } },
        "certificateThumbprint": { "type": "string" },
        "encryptionRequired": { "type": "boolean" }
      }
    },
    "metadata": {
      "type": "object",
      "properties": {
        "createdAt": { "type": "string", "format": "date-time" },
        "createdBy": { "type": "string" },
        "lastModifiedAt": { "type": "string", "format": "date-time" },
        "lastModifiedBy": { "type": "string" },
        "notes": { "type": "string" }
      }
    }
  }
}
```

---

## 2. Partner Configuration Validator (C#)

Create file: `shared/EDI.Configuration/PartnerConfigValidator.cs`

Requirements:
- Validate JSON against schema
- Perform business rule validation
- Check for conflicts with existing partners (duplicate ISA IDs)
- Validate referenced files exist (mapping files, etc.)
- Comprehensive error messages

```csharp
public class PartnerConfigValidator
{
    public ValidationResult Validate(PartnerConfig config)
    {
        // 1. JSON Schema validation
        // 2. Business rules validation
        // 3. Reference validation
        // 4. Conflict detection
    }
}
```

---

## 3. Sample Partner Configurations

Create these sample configuration files:

### config/partners/BCBS001.json - Blue Cross Blue Shield (Full featured)
```json
{
  "partnerId": "BCBS001",
  "partnerName": "Blue Cross Blue Shield - Region 1",
  "status": "active",
  "connection": {
    "protocol": "SFTP",
    "sftp": {
      "host": "sftp.bcbs.example.com",
      "port": 22,
      "username": "edi_partner",
      "credentialReference": "keyvault://kv-edi-prod-eastus2/secrets/bcbs001-sftp-key",
      "inboundPath": "/outbound",  # Their outbound = our inbound
      "outboundPath": "/inbound",
      "archivePath": "/archive"
    }
  },
  "edi": {
    "isaQualifier": "30",
    "isaId": "BCBS001EDI    ",
    "gsApplicationCode": "BCBS001",
    "controlNumberManagement": {
      "generateISA": true,
      "generateGS": true,
      "isaRange": { "start": 1, "end": 999999999 },
      "gsRange": { "start": 1, "end": 999999999 }
    }
  },
  "transactionTypes": [
    {
      "transactionType": "837P",
      "direction": "outbound",
      "enabled": true,
      "validation": {
        "schemaValidation": true,
        "businessRules": ["valid-npi", "valid-dates", "required-dx-codes"]
      },
      "mapping": {
        "mappingFile": "bcbs001-837p-mapping.json"
      },
      "routing": {
        "outboundDestination": "sftp://bcbs001",
        "errorQueue": "partner-errors"
      }
    },
    {
      "transactionType": "835",
      "direction": "inbound",
      "enabled": true,
      "validation": {
        "schemaValidation": true
      },
      "routing": {
        "inboundQueue": "inbound-835-queue"
      }
    }
  ],
  "sla": {
    "processingTime": 30,
    "deliveryTime": 60,
    "availability": 99.5
  },
  "notifications": {
    "email": ["edi-team@bcbs.example.com", "alerts@bcbs.example.com"],
    "events": ["file-received", "error", "sla-breach"]
  }
}
```

### config/partners/TEST001.json - Test Partner (Minimal)
```json
{
  "partnerId": "TEST001",
  "partnerName": "Test Partner - Internal Testing",
  "status": "testing",
  "connection": {
    "protocol": "Azure-Blob",
    "azureBlob": {
      "storageAccount": "stedideveasus2",
      "inboundContainer": "test-inbound",
      "outboundContainer": "test-outbound"
    }
  },
  "edi": {
    "isaQualifier": "ZZ",
    "isaId": "TEST001        ",
    "gsApplicationCode": "TEST001"
  },
  "transactionTypes": [
    {
      "transactionType": "837P",
      "direction": "both",
      "enabled": true,
      "validation": {
        "schemaValidation": false  # Relaxed for testing
      }
    }
  ]
}
```

---

## 4. Partner Onboarding Script (PowerShell)

Create file: `scripts/onboard-partner.ps1`

Requirements:
- Interactive prompts for partner details
- Generate configuration JSON
- Validate configuration
- Upload to blob storage
- Create Key Vault secrets
- Test connectivity
- Generate onboarding report

```powershell
<#
.SYNOPSIS
    Onboard a new EDI trading partner
.DESCRIPTION
    Interactive script to collect partner information, generate configuration,
    validate, and deploy to the EDI platform
.PARAMETER PartnerId
    Unique partner identifier (6-10 alphanumeric characters)
.PARAMETER Environment
    Target environment (dev, test, prod)
.EXAMPLE
    .\onboard-partner.ps1 -PartnerId HLTH001 -Environment dev
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[A-Z0-9]{6,10}$')]
    [string]$PartnerId,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet('dev', 'test', 'prod')]
    [string]$Environment
)

# 1. Collect partner information interactively
# 2. Generate configuration JSON
# 3. Validate against schema
# 4. Upload configuration to blob storage
# 5. Create Key Vault secrets for credentials
# 6. Test connectivity
# 7. Generate onboarding document
# 8. Create Azure DevOps work item or GitHub issue for tracking
```

---

## 5. Partner Configuration Manager (C#)

Create file: `shared/EDI.Configuration/PartnerConfigManager.cs`

Requirements:
- Load configuration from blob storage
- Cache configurations in memory
- Reload on change (blob trigger or timer)
- Thread-safe access
- Support for configuration versioning

```csharp
public interface IPartnerConfigManager
{
    Task<PartnerConfig> GetPartnerConfigAsync(string partnerId);
    Task<IEnumerable<PartnerConfig>> GetAllActivePartnersAsync();
    Task<PartnerConfig> GetPartnerByIsaIdAsync(string isaId);
    Task ReloadConfigurationsAsync();
}

public class PartnerConfigManager : IPartnerConfigManager
{
    private readonly BlobContainerClient _configContainer;
    private readonly IMemoryCache _cache;
    private readonly ILogger<PartnerConfigManager> _logger;
    
    // Implementation with caching and error handling
}
```

---

## 6. Partner Onboarding Checklist

Create file: `docs/partner-onboarding-checklist.md`

Checklist items:
- [ ] Partner agreement signed
- [ ] Technical specifications received
- [ ] Connection details provided (SFTP/AS2/etc.)
- [ ] Test files received
- [ ] ISA/GS identifiers assigned
- [ ] Configuration created and validated
- [ ] Credentials stored in Key Vault
- [ ] Connectivity tested
- [ ] Dev environment testing completed
- [ ] Test environment UAT completed
- [ ] Production deployment approved
- [ ] Monitoring alerts configured
- [ ] Partner notified of go-live
- [ ] Post-deployment validation (first 10 files)

---

## 7. Partner Configuration Unit Tests

Create file: `tests/EDI.Configuration.Tests/PartnerConfigValidatorTests.cs`

Test cases:
- Valid configuration passes validation
- Missing required fields fails validation
- Invalid ISA qualifier format fails
- Duplicate ISA ID detected
- Invalid email format fails
- Invalid IP address format fails
- JSON schema validation errors
- Business rule violations
- Reference validation (missing mapping file)

---

Also provide:
1. Configuration migration script (for schema version upgrades)
2. Partner configuration comparison tool (diff between versions)
3. Bulk partner import from CSV
4. Partner configuration export for backup
5. Partner health check script
```

## Expected Outcome

After running this prompt, you should have:
- ✅ Comprehensive JSON schema for partner configuration
- ✅ C# validation logic
- ✅ Sample partner configurations
- ✅ PowerShell onboarding automation script
- ✅ Configuration manager with caching
- ✅ Onboarding checklist and documentation
- ✅ Unit tests for validation logic

## Manual Steps (Human Required)

1. **Gather partner information:**
   - Contact: partner technical team
   - Obtain: connection details, ISA/GS IDs, test files
   - Coordinate: testing schedule

2. **Create partner configuration:**
   ```powershell
   # Run onboarding script
   .\scripts\onboard-partner.ps1 -PartnerId HLTH001 -Environment dev
   
   # Follow prompts to enter partner details
   ```

3. **Store credentials securely:**
   ```powershell
   # Add SFTP credentials to Key Vault
   az keyvault secret set `
     --vault-name kv-edi-dev-eastus2 `
     --name "hlth001-sftp-password" `
     --value "secure-password"
   ```

4. **Test connectivity:**
   ```powershell
   # Test SFTP connection
   .\scripts\test-partner-connection.ps1 -PartnerId HLTH001 -Environment dev
   ```

5. **Validate with test files:**
   - Upload partner test file to inbound folder
   - Monitor processing in Application Insights
   - Verify output file matches expected format
   - Confirm partner receives file successfully

## Validation Steps

1. Validate sample configurations:
   ```powershell
   # Validate JSON against schema
   Get-ChildItem config/partners/*.json | ForEach-Object {
       Write-Host "Validating $($_.Name)..."
       # Use JSON schema validator
   }
   ```

2. Test configuration manager:
   ```powershell
   dotnet test tests/EDI.Configuration.Tests/ --filter "Category=PartnerConfig"
   ```

3. Deploy configurations:
   ```powershell
   # Upload to blob storage
   az storage blob upload-batch `
     --account-name stedideveasus2 `
     --destination partner-configs `
     --source config/partners/ `
     --pattern "*.json"
   ```

## Troubleshooting

**Schema Validation Fails**
- Check JSON syntax: use online JSON validator
- Verify required fields are present
- Check data types match schema

**Duplicate ISA ID Error**
- Query existing configurations
- Coordinate with partner for unique ID
- Update configuration

**Connection Test Fails**
- Verify credentials in Key Vault
- Check firewall/IP whitelist
- Test from Azure Function App (not local)
- Verify SFTP/AS2 endpoint is accessible

## Next Steps

After successful partner configuration:
- Proceed to integration testing [14-create-integration-tests.md](14-create-integration-tests.md)
- Create mapping rules [20-mapping-rules-specification.md](../20-mapping-rules-specification.md)
- Set up monitoring [16-create-monitoring-dashboards.md](16-create-monitoring-dashboards.md)
- Schedule production deployment with partner
