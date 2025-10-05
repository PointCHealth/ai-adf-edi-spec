# Azure Environment Configuration

This directory contains Azure deployment parameter files for the EDI Platform.

## Azure Subscription Mapping

| Environment | Subscription Name | Subscription ID | Parameter File |
|-------------|-------------------|-----------------|----------------|
| Development | EDI-DEV | `0f02cf19-be55-4aab-983b-951e84910121` | `dev.parameters.json` |
| Test | EDI-TEST | TBD | `test.parameters.json` |
| Production | EDI-PROD | `85aa9a59-7b1c-49d2-84ba-0640040bc097` | `prod.parameters.json` |

**Tenant ID**: `76888a14-162d-4764-8e6f-c5a34addbd87`

## Parameter Files

Each parameter file follows the Azure Resource Manager parameter schema and contains environment-specific values for:

- Resource naming conventions
- SKU/tier selections
- Regional deployment settings
- Feature flags and configuration

## Usage

These files are referenced in Bicep/ARM deployments:

```bash
# Deploy to development
az deployment sub create \
  --location eastus2 \
  --template-file infra/bicep/main.bicep \
  --parameters env/dev.parameters.json \
  --subscription 0f02cf19-be55-4aab-983b-951e84910121

# Deploy to production
az deployment sub create \
  --location eastus \
  --template-file infra/bicep/main.bicep \
  --parameters env/prod.parameters.json \
  --subscription 85aa9a59-7b1c-49d2-84ba-0640040bc097
```

## GitHub Actions Secrets

Configure these organization-level secrets for CI/CD:

```bash
gh secret set AZURE_TENANT_ID --org PointCHealth --body "76888a14-162d-4764-8e6f-c5a34addbd87"
gh secret set AZURE_SUBSCRIPTION_ID_DEV --org PointCHealth --body "0f02cf19-be55-4aab-983b-951e84910121"
gh secret set AZURE_SUBSCRIPTION_ID_PROD --org PointCHealth --body "85aa9a59-7b1c-49d2-84ba-0640040bc097"
```

## Security Notes

- All subscriptions use CSP (Cloud Solution Provider) licensing
- OIDC authentication is required for GitHub Actions deployments
- Service principals should be scoped to specific resource groups when possible
- Test environment subscription details to be added when provisioned
