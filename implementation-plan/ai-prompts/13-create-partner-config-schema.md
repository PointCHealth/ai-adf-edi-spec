# AI Prompt: Create Partner Configuration Schema

## Objective

Create JSON schemas and validation logic for partner configuration in the edi-partner-configs repository.

## Prerequisites

- edi-partner-configs repository created
- Understanding of partner onboarding requirements
- JSON Schema knowledge
- Partner metadata requirements documented

## Prompt

```text
I need you to create comprehensive JSON schemas and configuration templates for trading partner onboarding in the EDI Healthcare Platform.

Context:
- Repository: edi-partner-configs
- Purpose: Store partner metadata, routing rules, mapping configurations
- Format: JSON with strict schema validation
- Security: Credentials encrypted and referenced via Key Vault
- Compliance: HIPAA-compliant partner data handling
- Timeline: 18-week AI-accelerated implementation

Please create the following:

---

## 1. Partner Configuration Schema

File: `schemas/partner-schema.json`

Define JSON Schema Draft 2020-12 for partner configuration with these sections:

### Partner Metadata
- `partnerId` (string, required, unique, alphanumeric)
- `partnerName` (string, required)
- `partnerType` (enum: payer, provider, clearinghouse, pharmacy)
- `active` (boolean, required, default: false)
- `environment` (enum: dev, test, prod)
- `onboardingDate` (string, date format)
- `contacts` (array of contact objects)
  - `name`, `email`, `phone`, `role`

### EDI Settings
- `isaQualifier` (string, 2 chars, required)
- `isaId` (string, 15 chars, required)
- `gsApplicationCode` (string, 2-3 chars)
- `controlNumberStrategy` (enum: sequential, random, partner-provided)
- `version` (string, default: "005010")

### Transaction Support
- `supportedTransactions` (array of objects)
  - `transactionSet` (enum: 270, 271, 834, 837, 277, 835, 999, TA1)
  - `direction` (enum: inbound, outbound, both)
  - `enabled` (boolean)
  - `mappingRulesetId` (string, references mapping file)

### Connection Settings
- `connections` (array of connection objects)
  - `connectionId` (string, required)
  - `type` (enum: sftp, api, as2, database)
  - `direction` (enum: inbound, outbound)
  - `endpoint` (string, URL or hostname)
  - `credentialsKeyVaultSecret` (string, references Key Vault)
  - `schedule` (cron expression for polling, optional)
  - `retryPolicy` (object with maxAttempts, backoff)

### Routing Rules
- `routingRules` (array of rules)
  - `ruleId` (string, required)
  - `priority` (integer, 1-100)
  - `condition` (object with filtering logic)
  - `destination` (queue or topic name)

### SLA Settings
- `slaRequirements` (object)
  - `acknowledgmentTime` (integer, minutes)
  - `processingTime` (integer, minutes)
  - `availability` (number, percentage)

### Compliance
- `hipaaBAA` (boolean, required)
- `dataRetentionDays` (integer, default: 2555, 7 years)
- `auditLevel` (enum: standard, enhanced)

---

## 2. Mapping Ruleset Schema

File: `schemas/mapping-schema.json`

Define JSON Schema for mapping rulesets:

### Ruleset Metadata
- `rulesetId` (string, required, unique)
- `rulesetName` (string, required)
- `transactionSet` (string, required)
- `version` (string, SemVer)
- `partnerId` (string, references partner)

### Field Mappings
- `fieldMappings` (array of mapping rules)
  - `sourceField` (string, X12 path or canonical field)
  - `targetField` (string, partner field or canonical field)
  - `transformationType` (enum: direct, lookup, calculated, conditional)
  - `transformation` (object with transformation logic)
    - `function` (string, function name)
    - `parameters` (object with key-value pairs)
  - `required` (boolean)
  - `defaultValue` (string, optional)

### Validation Rules
- `validationRules` (array of validation checks)
  - `field` (string)
  - `rule` (enum: required, format, range, custom)
  - `parameters` (object)
  - `errorMessage` (string)

---

## 3. Routing Rules Schema

File: `schemas/routing-schema.json`

Define JSON Schema for routing rules:

- `routingRules` (array)
  - `ruleId` (string, required)
  - `priority` (integer, 1-100, required)
  - `condition` (object)
    - `transactionType` (string)
    - `senderId` (string)
    - `receiverId` (string)
    - `customFilters` (object with key-value pairs)
  - `actions` (array of routing actions)
    - `type` (enum: publish, enqueue, http, function)
    - `destination` (string)
    - `headers` (object, optional)

---

## 4. Partner Configuration Template

File: `partners/template/partner.json`

Create comprehensive template with comments:

```json
{
  "$schema": "../../schemas/partner-schema.json",
  "partnerId": "PARTNER001",
  "partnerName": "Sample Healthcare Partner",
  "partnerType": "payer",
  "active": false,
  "environment": "dev",
  "onboardingDate": "2025-10-05",
  "contacts": [
    {
      "name": "John Doe",
      "email": "john.doe@partner.com",
      "phone": "+1-555-0100",
      "role": "Technical Lead"
    }
  ],
  "ediSettings": {
    "isaQualifier": "ZZ",
    "isaId": "PARTNER001    ",
    "gsApplicationCode": "HN",
    "controlNumberStrategy": "sequential",
    "version": "005010"
  },
  "supportedTransactions": [
    {
      "transactionSet": "270",
      "direction": "outbound",
      "enabled": true,
      "mappingRulesetId": "PARTNER001-270-v1"
    },
    {
      "transactionSet": "271",
      "direction": "inbound",
      "enabled": true,
      "mappingRulesetId": "PARTNER001-271-v1"
    }
  ],
  "connections": [
    {
      "connectionId": "sftp-outbound",
      "type": "sftp",
      "direction": "outbound",
      "endpoint": "sftp.partner.com",
      "credentialsKeyVaultSecret": "partner001-sftp-creds",
      "retryPolicy": {
        "maxAttempts": 3,
        "backoffSeconds": 60
      }
    }
  ],
  "routingRules": [
    {
      "ruleId": "route-270",
      "priority": 10,
      "condition": {
        "transactionType": "270",
        "receiverId": "PARTNER001"
      },
      "destination": "eligibility-mapper-queue"
    }
  ],
  "slaRequirements": {
    "acknowledgmentTime": 15,
    "processingTime": 60,
    "availability": 99.5
  },
  "compliance": {
    "hipaaBAA": true,
    "dataRetentionDays": 2555,
    "auditLevel": "enhanced"
  }
}
```

---

## 5. Configuration Validation Service

File: `validation/ConfigValidator.cs` (C# class for validation)

Create C# class that:
- Loads JSON schemas
- Validates partner configuration files
- Validates mapping rulesets
- Validates routing rules
- Returns detailed validation errors
- Can be used in CI/CD pipeline and at runtime

Dependencies:
- Newtonsoft.Json.Schema or System.Text.Json + JsonSchema.Net

---

## 6. GitHub Actions Workflow for Validation

File: `.github/workflows/validate-configs.yml`

Create workflow that:
- Triggers on PR to main
- Validates all JSON files against schemas
- Checks for duplicate partner IDs
- Verifies referenced Key Vault secrets exist (optional)
- Runs linting on JSON files
- Comments on PR with validation results

---

## 7. Documentation

File: `README.md`

Create comprehensive README explaining:
- Repository purpose
- Directory structure
- How to onboard a new partner (step-by-step)
- Schema documentation
- Validation process
- How to reference configurations from functions
- Security best practices

Also provide:
1. PowerShell script to generate new partner from template
2. PowerShell script to validate all configurations locally
3. Sample mapping ruleset for 270/271 transactions
4. Migration guide for existing partners
```

## Expected Outcome

After running this prompt, you should have:

- ✅ JSON schemas for partner, mapping, and routing configurations
- ✅ Partner configuration template
- ✅ Configuration validation service
- ✅ GitHub Actions validation workflow
- ✅ Comprehensive documentation
- ✅ Helper scripts for partner onboarding

## Validation Steps

1. Validate schema files:

   ```powershell
   cd edi-partner-configs
   
   # Install JSON schema validator (if not installed)
   npm install -g ajv-cli
   
   # Validate schema syntax
   ajv compile -s schemas/partner-schema.json
   ajv compile -s schemas/mapping-schema.json
   ```

2. Validate template against schema:

   ```powershell
   ajv validate -s schemas/partner-schema.json -d partners/template/partner.json
   ```

3. Test validation workflow:

   ```powershell
   # Create test branch
   git checkout -b test/config-validation
   
   # Make invalid change to template
   # (e.g., remove required field)
   
   # Push and create PR
   git add partners/template/partner.json
   git commit -m "test: Validate config validation"
   git push origin test/config-validation
   
   # Check PR for validation errors
   ```

4. Run C# validator locally:

   ```powershell
   cd validation
   dotnet run -- ../partners/template/partner.json
   ```

## Troubleshooting

**Schema validation fails:**

- Check JSON Schema Draft version (use Draft 2020-12)
- Verify schema $id and $schema properties
- Test with online validator: https://www.jsonschemavalidator.net/

**Referenced secrets not found:**

- Ensure Key Vault name correct in configuration
- Verify service principal has Key Vault Secrets User role
- Check secret names match exactly (case-sensitive)

**Duplicate partner IDs:**

- Implement uniqueness check in validation workflow
- Use partner ID as directory name for clarity
- Maintain partner registry/index file

## Next Steps

After successful completion:

- Onboard first trading partner [15-onboard-trading-partner.md](15-onboard-trading-partner.md)
- Create mapping rulesets for common transaction types
- Integrate configuration loading in functions [09-create-function-projects.md](09-create-function-projects.md)
- Set up Key Vault for partner credentials
- Document partner onboarding process in runbooks
