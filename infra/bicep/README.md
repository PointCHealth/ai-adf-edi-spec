# Healthcare EDI Platform - Bicep Infrastructure

## Overview

This directory contains the Bicep infrastructure templates for the Healthcare EDI Platform. The infrastructure is deployed using a modular approach with a main template that orchestrates child modules.

## Subscription Architecture

The platform uses a **two-subscription architecture** to separate non-production from production workloads:

| Subscription | Environments | Resource Groups | Purpose |
|-------------|--------------|-----------------|---------|
| **EDI-DEV** | dev, test | rg-edi-dev-eastus2<br>rg-edi-test-eastus2 | Non-production workloads, uses separate resource groups for isolation |
| **EDI-PROD** | prod | rg-edi-prod-eastus2 | Production workloads |

### Why Two Subscriptions?

- **Cost Optimization**: Reduces subscription management overhead
- **Environment Isolation**: Resource groups provide adequate isolation for dev/test
- **Simplified RBAC**: Fewer service principals and role assignments to manage
- **Billing Separation**: Separate billing for prod vs non-prod

## Parameter Files

Each environment has its own parameter file that defines environment-specific configuration:

| File | Environment | Subscription | Resource Group | Notes |
|------|-------------|--------------|----------------|-------|
| `main.dev.parameters.json` | dev | EDI-DEV | rg-edi-dev-eastus2 | Minimal SKUs, 7-day retention |
| `main.test.parameters.json` | test | EDI-DEV | rg-edi-test-eastus2 | Mid-tier SKUs, 14-day retention |
| `main.prod.parameters.json` | prod | EDI-PROD | rg-edi-prod-eastus2 | Production SKUs, 30-day retention, zone redundancy |

### Key Vault References

All parameter files contain a `{subscription-id}` placeholder in the Key Vault secret reference. This must be replaced with the actual subscription ID before deployment:

- **Dev & Test**: Replace with EDI-DEV subscription ID
- **Prod**: Replace with EDI-PROD subscription ID

Example Key Vault reference:
```json
"sqlAdministratorLoginPassword": {
  "reference": {
    "keyVault": {
      "id": "/subscriptions/{subscription-id}/resourceGroups/rg-edi-dev-eastus2/providers/Microsoft.KeyVault/vaults/kv-edi-dev-eus2"
    },
    "secretName": "sql-admin-password"
  }
}
```

## Deployment

### Prerequisites

1. **Azure Subscriptions**:
   - EDI-DEV subscription (for dev and test environments)
   - EDI-PROD subscription (for prod environment)

2. **Service Principals**:
   - `github-actions-edi-dev` with Contributor access to both resource groups in EDI-DEV
   - `github-actions-edi-prod` with Contributor access to resource group in EDI-PROD

3. **Resource Groups** (must be created before deployment):
   ```powershell
   # Set subscription context for dev/test
   az account set --subscription "EDI-DEV"
   az group create --name rg-edi-dev-eastus2 --location eastus2
   az group create --name rg-edi-test-eastus2 --location eastus2
   
   # Set subscription context for prod
   az account set --subscription "EDI-PROD"
   az group create --name rg-edi-prod-eastus2 --location eastus2
   ```

### Manual Deployment

Deploy to dev environment:
```powershell
az account set --subscription "EDI-DEV"
az deployment group create `
  --resource-group rg-edi-dev-eastus2 `
  --template-file main.bicep `
  --parameters main.dev.parameters.json
```

Deploy to test environment:
```powershell
az account set --subscription "EDI-DEV"
az deployment group create `
  --resource-group rg-edi-test-eastus2 `
  --template-file main.bicep `
  --parameters main.test.parameters.json
```

Deploy to prod environment:
```powershell
az account set --subscription "EDI-PROD"
az deployment group create `
  --resource-group rg-edi-prod-eastus2 `
  --template-file main.bicep `
  --parameters main.prod.parameters.json
```

### What-If Analysis

Before deploying, run a what-if analysis to see proposed changes:

```powershell
az account set --subscription "EDI-DEV"
az deployment group what-if `
  --resource-group rg-edi-dev-eastus2 `
  --template-file main.bicep `
  --parameters main.dev.parameters.json
```

## Module Structure

The infrastructure is organized into the following modules:

| Module | Purpose | Resources |
|--------|---------|-----------|
| `modules/networking.bicep` | Network infrastructure | VNet, Subnets, NSGs, Route Tables, Bastion, App Gateway |
| `modules/storage.bicep` | Storage accounts | Storage accounts with containers and lifecycle policies |
| `modules/sql.bicep` | SQL databases | SQL Server, Elastic Pool, Databases |
| `modules/service-bus.bicep` | Messaging | Service Bus Namespace, Queues, Topics, Subscriptions |
| `modules/data-factory.bicep` | Orchestration | Data Factory, Linked Services, Integration Runtime |
| `modules/key-vault.bicep` | Secrets management | Key Vault with RBAC assignments |
| `modules/function-app.bicep` | Compute | Function Apps with App Service Plans |
| `modules/app-insights.bicep` | Monitoring | Application Insights |
| `modules/log-analytics.bicep` | Logging | Log Analytics Workspace |
| `modules/private-endpoints.bicep` | Network security | Private Endpoints for all services |
| `modules/rbac.bicep` | Access control | Managed Identities and RBAC assignments |
| `modules/diagnostic-settings.bicep` | Audit logging | Diagnostic settings for all resources |

## Environment Differences

### Dev Environment
- Minimal SKUs (Basic, Standard_LRS)
- Single instance deployments
- 7-day retention periods
- No zone redundancy
- No private endpoints
- Cost: ~$500/month

### Test Environment
- Mid-tier SKUs (Standard, Standard_GRS)
- Minimal redundancy
- 14-day retention periods
- Private endpoints enabled
- Cost: ~$1,500/month

### Prod Environment
- Production SKUs (Premium, Standard_RAGRS)
- Zone redundancy enabled
- 30-day retention periods
- Private endpoints enabled
- DDoS protection enabled
- Cost: ~$5,000/month

## Next Steps

1. Review and update parameter files with actual values
2. Replace `{subscription-id}` placeholders in Key Vault references
3. Create resource groups in appropriate subscriptions
4. Set up service principals with proper RBAC assignments
5. Configure GitHub secrets with subscription IDs
6. Deploy infrastructure using GitHub Actions workflows

## Related Documentation

- [IaC Strategy Specification](../../docs/04-iac-strategy-spec.md)
- [GitHub Actions Implementation](../../docs/04a-github-actions-implementation.md)
- [Deployment Guide](../../implementation-plan/ai-prompts/STEP_08_COMPLETE.md)
