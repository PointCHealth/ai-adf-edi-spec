# Azure Function App Inventory

**Project:** Healthcare EDI Platform  
**Last Updated:** October 5, 2025  
**Owner:** Platform Engineering Team

---

## Overview

This document maintains the canonical list of all Azure Function Apps across all environments, their Azure resource names, and deployment configurations. This inventory is used by CI/CD workflows, monitoring dashboards, and operational runbooks.

---

## Naming Convention

**Pattern:** `func-edi-{function-name}-{environment}-{location}`

Where:
- `{function-name}` = Abbreviated function purpose (kebab-case)
- `{environment}` = dev | test | prod
- `{location}` = eastus2 (primary region)

**Examples:**
- `func-edi-inbound-dev-eastus2`
- `func-edi-outbound-prod-eastus2`

---

## Repository: edi-platform-core

### Function 1: InboundRouter

**Purpose:** Routes incoming EDI files from storage to appropriate processing queues

| Environment | Azure Function App Name | App Service Plan | Source Directory |
|------------|-------------------------|------------------|------------------|
| Dev | `func-edi-inbound-dev-eastus2` | `plan-edi-dev-eastus2` | `/functions/InboundRouter.Function` |
| Test | `func-edi-inbound-test-eastus2` | `plan-edi-test-eastus2` | `/functions/InboundRouter.Function` |
| Prod | `func-edi-inbound-prod-eastus2` | `plan-edi-prod-eastus2` | `/functions/InboundRouter.Function` |

**Triggers:**
- Event Grid (blob created)
- HTTP POST /api/route (manual routing)

**Dependencies:**
- Azure Storage (blob read)
- Service Bus (message publish)
- Shared Library: HealthcareEDI.X12 (envelope parsing)

---

### Function 2: EnterpriseScheduler

**Purpose:** Schedule recurring EDI processing jobs (nightly enrollments, reconciliations)

| Environment | Azure Function App Name | App Service Plan | Source Directory |
|------------|-------------------------|------------------|------------------|
| Dev | `func-edi-scheduler-dev-eastus2` | `plan-edi-dev-eastus2` | `/functions/EnterpriseScheduler.Function` |
| Test | `func-edi-scheduler-test-eastus2` | `plan-edi-test-eastus2` | `/functions/EnterpriseScheduler.Function` |
| Prod | `func-edi-scheduler-prod-eastus2` | `plan-edi-prod-eastus2` | `/functions/EnterpriseScheduler.Function` |

**Triggers:**
- Timer (NCRONTAB expressions)
- HTTP POST /api/jobs/run (manual execution)

**Dependencies:**
- SQL Database (job history)
- Service Bus (job message publish)
- Shared Library: HealthcareEDI.Messaging

---

## Repository: edi-mappers

### Function 3: EligibilityMapper (270/271)

**Purpose:** Transform eligibility inquiries (270) and responses (271) between X12 and partner formats

| Environment | Azure Function App Name | App Service Plan | Source Directory |
|------------|-------------------------|------------------|------------------|
| Dev | `func-edi-eligibility-dev-eastus2` | `plan-edi-mappers-dev-eastus2` | `/functions/EligibilityMapper.Function` |
| Test | `func-edi-eligibility-test-eastus2` | `plan-edi-mappers-test-eastus2` | `/functions/EligibilityMapper.Function` |
| Prod | `func-edi-eligibility-prod-eastus2` | `plan-edi-mappers-prod-eastus2` | `/functions/EligibilityMapper.Function` |

**Triggers:**
- Service Bus queue: `eligibility-mapper-queue`
- HTTP POST /api/map/270 (manual)
- HTTP POST /api/map/271 (manual)

**Dependencies:**
- Shared Library: HealthcareEDI.X12
- Shared Library: HealthcareEDI.Configuration (mapping rules)
- Storage (partner config files)

---

### Function 4: ClaimsMapper (837/277)

**Purpose:** Transform claims (837) and claim status (277) transactions

| Environment | Azure Function App Name | App Service Plan | Source Directory |
|------------|-------------------------|------------------|------------------|
| Dev | `func-edi-claims-dev-eastus2` | `plan-edi-mappers-dev-eastus2` | `/functions/ClaimsMapper.Function` |
| Test | `func-edi-claims-test-eastus2` | `plan-edi-mappers-test-eastus2` | `/functions/ClaimsMapper.Function` |
| Prod | `func-edi-claims-prod-eastus2` | `plan-edi-mappers-prod-eastus2` | `/functions/ClaimsMapper.Function` |

**Triggers:**
- Service Bus queue: `claims-mapper-queue`

**Dependencies:**
- Shared Library: HealthcareEDI.X12
- Shared Library: HealthcareEDI.Configuration

---

### Function 5: EnrollmentMapper (834)

**Purpose:** Transform enrollment/benefit transactions with event sourcing

| Environment | Azure Function App Name | App Service Plan | Source Directory |
|------------|-------------------------|------------------|------------------|
| Dev | `func-edi-enrollment-dev-eastus2` | `plan-edi-mappers-dev-eastus2` | `/functions/EnrollmentMapper.Function` |
| Test | `func-edi-enrollment-test-eastus2` | `plan-edi-mappers-test-eastus2` | `/functions/EnrollmentMapper.Function` |
| Prod | `func-edi-enrollment-prod-eastus2` | `plan-edi-mappers-prod-eastus2` | `/functions/EnrollmentMapper.Function` |

**Triggers:**
- Service Bus queue: `enrollment-mapper-queue`

**Dependencies:**
- Shared Library: HealthcareEDI.X12
- SQL Database: EDI_EventStore (event sourcing)

---

### Function 6: RemittanceMapper (835)

**Purpose:** Transform remittance advice transactions

| Environment | Azure Function App Name | App Service Plan | Source Directory |
|------------|-------------------------|------------------|------------------|
| Dev | `func-edi-remittance-dev-eastus2` | `plan-edi-mappers-dev-eastus2` | `/functions/RemittanceMapper.Function` |
| Test | `func-edi-remittance-test-eastus2` | `plan-edi-mappers-test-eastus2` | `/functions/RemittanceMapper.Function` |
| Prod | `func-edi-remittance-prod-eastus2` | `plan-edi-mappers-prod-eastus2` | `/functions/RemittanceMapper.Function` |

**Triggers:**
- Service Bus queue: `remittance-mapper-queue`

**Dependencies:**
- Shared Library: HealthcareEDI.X12

---

## Repository: edi-connectors

### Function 7: SftpConnector

**Purpose:** Send/receive files via SFTP to/from trading partners

| Environment | Azure Function App Name | App Service Plan | Source Directory |
|------------|-------------------------|------------------|------------------|
| Dev | `func-edi-sftp-dev-eastus2` | `plan-edi-connectors-dev-eastus2` | `/functions/SftpConnector.Function` |
| Test | `func-edi-sftp-test-eastus2` | `plan-edi-connectors-test-eastus2` | `/functions/SftpConnector.Function` |
| Prod | `func-edi-sftp-prod-eastus2` | `plan-edi-connectors-prod-eastus2` | `/functions/SftpConnector.Function` |

**Triggers:**
- Service Bus queue: `sftp-upload-queue` (outbound)
- Timer: `0 */15 * * * *` (download polling every 15 minutes)

**Dependencies:**
- Storage (file upload/download)
- SSH.NET library (SFTP operations)
- Key Vault (partner SFTP credentials)

---

### Function 8: ApiConnector

**Purpose:** Send/receive data via REST APIs to/from trading partners

| Environment | Azure Function App Name | App Service Plan | Source Directory |
|------------|-------------------------|------------------|------------------|
| Dev | `func-edi-api-dev-eastus2` | `plan-edi-connectors-dev-eastus2` | `/functions/ApiConnector.Function` |
| Test | `func-edi-api-test-eastus2` | `plan-edi-connectors-test-eastus2` | `/functions/ApiConnector.Function` |
| Prod | `func-edi-api-prod-eastus2` | `plan-edi-connectors-prod-eastus2` | `/functions/ApiConnector.Function` |

**Triggers:**
- Service Bus queue: `api-send-queue` (outbound)
- HTTP POST /api/receive (inbound webhook)

**Dependencies:**
- HttpClient (partner API calls)
- Key Vault (partner API keys)

---

### Function 9: DatabaseConnector (Optional)

**Purpose:** Read/write data from partner databases if applicable

| Environment | Azure Function App Name | App Service Plan | Source Directory |
|------------|-------------------------|------------------|------------------|
| Dev | `func-edi-database-dev-eastus2` | `plan-edi-connectors-dev-eastus2` | `/functions/DatabaseConnector.Function` |
| Test | `func-edi-database-test-eastus2` | `plan-edi-connectors-test-eastus2` | `/functions/DatabaseConnector.Function` |
| Prod | `func-edi-database-prod-eastus2` | `plan-edi-connectors-prod-eastus2` | `/functions/DatabaseConnector.Function` |

**Triggers:**
- Service Bus queue: `database-sync-queue`

**Dependencies:**
- SQL/NoSQL database clients
- Key Vault (connection strings)

---

## Shared Utility Functions (Optional - Future Phase)

### Function 10: ControlNumberGenerator

**Purpose:** Generate and manage EDI control numbers (ISA, GS)

| Environment | Azure Function App Name | App Service Plan | Source Directory |
|------------|-------------------------|------------------|------------------|
| Dev | `func-edi-controlnum-dev-eastus2` | `plan-edi-dev-eastus2` | `/functions/ControlNumberGenerator.Function` |
| Test | `func-edi-controlnum-test-eastus2` | `plan-edi-test-eastus2` | `/functions/ControlNumberGenerator.Function` |
| Prod | `func-edi-controlnum-prod-eastus2` | `plan-edi-prod-eastus2` | `/functions/ControlNumberGenerator.Function` |

**Triggers:**
- HTTP POST /api/controlnumbers/next

**Dependencies:**
- SQL Database: EDI_ControlNumbers

---

### Function 11: FileArchiver

**Purpose:** Move processed files to archive storage with lifecycle management

| Environment | Azure Function App Name | App Service Plan | Source Directory |
|------------|-------------------------|------------------|------------------|
| Dev | `func-edi-archiver-dev-eastus2` | `plan-edi-dev-eastus2` | `/functions/FileArchiver.Function` |
| Test | `func-edi-archiver-test-eastus2` | `plan-edi-test-eastus2` | `/functions/FileArchiver.Function` |
| Prod | `func-edi-archiver-prod-eastus2` | `plan-edi-prod-eastus2` | `/functions/FileArchiver.Function` |

**Triggers:**
- Timer: `0 0 2 * * *` (nightly at 2 AM)

**Dependencies:**
- Storage (source and archive accounts)

---

### Function 12: NotificationService

**Purpose:** Send notifications via email/Teams for alerts and status updates

| Environment | Azure Function App Name | App Service Plan | Source Directory |
|------------|-------------------------|------------------|------------------|
| Dev | `func-edi-notify-dev-eastus2` | `plan-edi-dev-eastus2` | `/functions/NotificationService.Function` |
| Test | `func-edi-notify-test-eastus2` | `plan-edi-test-eastus2` | `/functions/NotificationService.Function` |
| Prod | `func-edi-notify-prod-eastus2` | `plan-edi-prod-eastus2` | `/functions/NotificationService.Function` |

**Triggers:**
- Service Bus queue: `notification-queue`

**Dependencies:**
- SendGrid or SMTP (email)
- Microsoft Graph API (Teams)

---

## App Service Plans

### Dev Environment

| App Service Plan Name | SKU | Functions Hosted |
|----------------------|-----|------------------|
| `plan-edi-dev-eastus2` | EP1 | InboundRouter, EnterpriseScheduler, ControlNumberGenerator, FileArchiver, NotificationService |
| `plan-edi-mappers-dev-eastus2` | EP1 | EligibilityMapper, ClaimsMapper, EnrollmentMapper, RemittanceMapper |
| `plan-edi-connectors-dev-eastus2` | EP1 | SftpConnector, ApiConnector, DatabaseConnector |

**Total Plans:** 3  
**Cost:** ~$150/month per plan = $450/month

### Test Environment

| App Service Plan Name | SKU | Functions Hosted |
|----------------------|-----|------------------|
| `plan-edi-test-eastus2` | EP1 | Core functions (InboundRouter, Scheduler, utilities) |
| `plan-edi-mappers-test-eastus2` | EP1 | All mapper functions |
| `plan-edi-connectors-test-eastus2` | EP1 | All connector functions |

**Total Plans:** 3  
**Cost:** ~$150/month per plan = $450/month

### Production Environment

| App Service Plan Name | SKU | Functions Hosted |
|----------------------|-----|------------------|
| `plan-edi-prod-eastus2` | EP2 (2 instances) | Core functions (InboundRouter, Scheduler, utilities) |
| `plan-edi-mappers-prod-eastus2` | EP2 (2 instances) | All mapper functions |
| `plan-edi-connectors-prod-eastus2` | EP2 (2 instances) | All connector functions |

**Total Plans:** 3  
**Cost:** ~$600/month per plan = $1,800/month

**Rationale for Multiple Plans:**
- Independent scaling per function group
- Isolate core routing from mapping workloads
- Better cost allocation and monitoring

---

## Deployment Slots

Only production function apps have deployment slots for zero-downtime deployments.

### Slot Configuration

| Function App (Prod) | Slots |
|-------------------|-------|
| All production functions | production (active), staging |

**Slot Settings (Sticky):**
- `APPINSIGHTS_INSTRUMENTATIONKEY`
- `ENVIRONMENT`
- Connection strings marked as slot-specific

**Deployment Process:**
1. Deploy to staging slot
2. Warm up staging slot (5 minutes)
3. Run smoke tests on staging
4. Manual approval
5. Swap staging → production
6. Monitor production for 15 minutes

---

## Matrix Configuration for GitHub Actions

For use in CI/CD workflows:

```yaml
strategy:
  matrix:
    include:
      # edi-platform-core functions
      - function_name: "InboundRouter"
        function_path: "functions/InboundRouter.Function"
        app_name_dev: "func-edi-inbound-dev-eastus2"
        app_name_test: "func-edi-inbound-test-eastus2"
        app_name_prod: "func-edi-inbound-prod-eastus2"
        
      - function_name: "EnterpriseScheduler"
        function_path: "functions/EnterpriseScheduler.Function"
        app_name_dev: "func-edi-scheduler-dev-eastus2"
        app_name_test: "func-edi-scheduler-test-eastus2"
        app_name_prod: "func-edi-scheduler-prod-eastus2"
      
      # edi-mappers functions
      - function_name: "EligibilityMapper"
        function_path: "functions/EligibilityMapper.Function"
        app_name_dev: "func-edi-eligibility-dev-eastus2"
        app_name_test: "func-edi-eligibility-test-eastus2"
        app_name_prod: "func-edi-eligibility-prod-eastus2"
        
      - function_name: "ClaimsMapper"
        function_path: "functions/ClaimsMapper.Function"
        app_name_dev: "func-edi-claims-dev-eastus2"
        app_name_test: "func-edi-claims-test-eastus2"
        app_name_prod: "func-edi-claims-prod-eastus2"
        
      - function_name: "EnrollmentMapper"
        function_path: "functions/EnrollmentMapper.Function"
        app_name_dev: "func-edi-enrollment-dev-eastus2"
        app_name_test: "func-edi-enrollment-test-eastus2"
        app_name_prod: "func-edi-enrollment-prod-eastus2"
        
      - function_name: "RemittanceMapper"
        function_path: "functions/RemittanceMapper.Function"
        app_name_dev: "func-edi-remittance-dev-eastus2"
        app_name_test: "func-edi-remittance-test-eastus2"
        app_name_prod: "func-edi-remittance-prod-eastus2"
        
      # edi-connectors functions
      - function_name: "SftpConnector"
        function_path: "functions/SftpConnector.Function"
        app_name_dev: "func-edi-sftp-dev-eastus2"
        app_name_test: "func-edi-sftp-test-eastus2"
        app_name_prod: "func-edi-sftp-prod-eastus2"
        
      - function_name: "ApiConnector"
        function_path: "functions/ApiConnector.Function"
        app_name_dev: "func-edi-api-dev-eastus2"
        app_name_test: "func-edi-api-test-eastus2"
        app_name_prod: "func-edi-api-prod-eastus2"
```

---

## Quick Reference Commands

### List all function apps in resource group

```powershell
# Dev
az functionapp list \
  --resource-group rg-edi-dev-eastus2 \
  --query "[].{Name:name, State:state, Plan:appServicePlanId}" \
  --output table

# Test
az functionapp list \
  --resource-group rg-edi-test-eastus2 \
  --query "[].{Name:name, State:state}" \
  --output table

# Prod
az functionapp list \
  --resource-group rg-edi-prod-eastus2 \
  --query "[].{Name:name, State:state}" \
  --output table
```

### Check function app health

```powershell
az functionapp show \
  --name func-edi-inbound-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2 \
  --query "{Name:name, State:state, DefaultHostName:defaultHostName}"
```

### Restart function app

```powershell
az functionapp restart \
  --name func-edi-inbound-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2
```

---

## Maintenance Notes

**Update This Document When:**
- Adding new function apps
- Changing naming conventions
- Modifying App Service Plan assignments
- Adjusting scaling configurations
- Adding new environments

**Review Schedule:**
- Monthly: Verify all function apps exist and are running
- Quarterly: Review App Service Plan allocation and costs
- Annually: Audit naming conventions and reorganize if needed

---

**Last Updated:** October 5, 2025  
**Maintained By:** Platform Engineering Team  
**Document Version:** 1.0
