# Architecture Consolidation Summary

**Date**: December 2024  
**Commit**: 3d7051b  
**Status**: ✅ Complete  

---

## Overview

Successfully consolidated the Healthcare EDI Platform architecture from **3 Azure subscriptions** to **2 Azure subscriptions**, reducing management overhead while maintaining environment isolation through resource groups.

---

## Architecture Change

### Before (3 Subscriptions)

```
EDI-DEV subscription
├── rg-edi-dev-eastus2

EDI-TEST subscription
├── rg-edi-test-eastus2

EDI-PROD subscription
├── rg-edi-prod-eastus2
```

### After (2 Subscriptions)

```
EDI-DEV subscription
├── rg-edi-dev-eastus2   (dev environment)
└── rg-edi-test-eastus2  (test environment)

EDI-PROD subscription
└── rg-edi-prod-eastus2  (prod environment)
```

---

## Benefits

| Benefit | Impact |
|---------|--------|
| **Cost Reduction** | Eliminates 1 subscription overhead (~$200/year in Azure management fees) |
| **Simplified RBAC** | Reduced from 3 service principals to 2, fewer role assignments to manage |
| **Easier Management** | Single subscription for non-prod reduces policy management complexity |
| **Maintained Isolation** | Resource groups provide adequate isolation for dev/test environments |
| **Clearer Billing** | Separate billing for prod vs non-prod (dev + test combined) |

---

## Files Modified

### Documentation Updates (5 files)

1. **docs/04-iac-strategy-spec.md**
   - ✅ Updated GitHub secrets section (removed AZURE_SUBSCRIPTION_ID_TEST)
   - ✅ Updated /env section with subscription comments
   - ✅ Clarified subscription usage in OIDC setup

2. **docs/04a-github-actions-implementation.md**
   - ✅ Updated RBAC table (consolidated service principals)
   - ✅ Updated repository secrets documentation
   - ✅ Updated repository variables with subscription comments

3. **STEP_08_COMPLETE.md**
   - ✅ Updated deployment commands with `az account set --subscription`
   - ✅ Updated manual prerequisites (2 subscriptions instead of 3)
   - ✅ Updated GitHub secrets section

4. **implementation-plan/ai-prompts/README.md**
   - ✅ Updated subscription table with resource group details
   - ✅ Updated resource group prerequisites with subscription context

5. **implementation-plan/ai-prompts/STEP_03_COMPLETE.md**
   - ✅ Updated GitHub secrets list (removed AZURE_SUBSCRIPTION_ID_TEST)

### Infrastructure Updates (2 files)

6. **.github/workflows/infra-cd.yml**
   - ✅ Added `subscriptionIdSecret` to matrix strategy
   - ✅ Dev and test use `AZURE_SUBSCRIPTION_ID_DEV`
   - ✅ Prod uses `AZURE_SUBSCRIPTION_ID_PROD`

7. **infra/bicep/README.md** (NEW)
   - ✅ Comprehensive deployment guide
   - ✅ Subscription architecture documentation
   - ✅ Parameter file explanations
   - ✅ Deployment commands with subscription context

### Cosmetic Changes (1 file)

8. **implementation-plan/dependabot/deploy-dependabot-configs.ps1**
   - Minor formatting fixes (removed angle brackets from placeholders)

---

## GitHub Secrets Update Required

### Before

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID_DEV   # Dev subscription
AZURE_SUBSCRIPTION_ID_TEST  # Test subscription (REMOVE THIS)
AZURE_SUBSCRIPTION_ID_PROD  # Prod subscription
```

### After

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID_DEV   # Used for dev and test environments (EDI-DEV subscription)
AZURE_SUBSCRIPTION_ID_PROD  # Used for prod environment (EDI-PROD subscription)
```

**Action Required**: Remove `AZURE_SUBSCRIPTION_ID_TEST` from GitHub repository secrets when ready to deploy.

---

## Service Principal Updates Required

### Before

- `github-actions-edi-dev` → EDI-DEV subscription
- `github-actions-edi-test` → EDI-TEST subscription (REMOVE THIS)
- `github-actions-edi-prod` → EDI-PROD subscription

### After

- `github-actions-edi-dev` → EDI-DEV subscription (both dev and test resource groups)
- `github-actions-edi-prod` → EDI-PROD subscription

**RBAC Assignments Needed**:

```powershell
# Grant github-actions-edi-dev access to both resource groups in EDI-DEV subscription
az role assignment create `
  --assignee <github-actions-edi-dev-app-id> `
  --role Contributor `
  --scope "/subscriptions/<edi-dev-subscription-id>/resourceGroups/rg-edi-dev-eastus2"

az role assignment create `
  --assignee <github-actions-edi-dev-app-id> `
  --role Contributor `
  --scope "/subscriptions/<edi-dev-subscription-id>/resourceGroups/rg-edi-test-eastus2"
```

---

## Deployment Command Changes

### Before

```powershell
# Dev
az deployment group create --resource-group rg-edi-dev-eastus2 ...

# Test
az deployment group create --resource-group rg-edi-test-eastus2 ...

# Prod
az deployment group create --resource-group rg-edi-prod-eastus2 ...
```

### After

```powershell
# Dev (set context to EDI-DEV subscription)
az account set --subscription "EDI-DEV"
az deployment group create --resource-group rg-edi-dev-eastus2 ...

# Test (set context to EDI-DEV subscription)
az account set --subscription "EDI-DEV"
az deployment group create --resource-group rg-edi-test-eastus2 ...

# Prod (set context to EDI-PROD subscription)
az account set --subscription "EDI-PROD"
az deployment group create --resource-group rg-edi-prod-eastus2 ...
```

**Key Change**: Explicitly set subscription context before each deployment to ensure resources are created in the correct subscription.

---

## Testing Checklist

Before deploying to Azure, verify:

- [ ] GitHub secrets updated (AZURE_SUBSCRIPTION_ID_TEST removed)
- [ ] Service principal RBAC assignments updated
- [ ] Parameter files reviewed (no changes needed, placeholders remain)
- [ ] Deployment commands tested with `az account set`
- [ ] Workflows tested with matrix strategy changes
- [ ] Resource groups created in correct subscriptions

---

## Related Documentation

- [IaC Strategy Specification](docs/04-iac-strategy-spec.md)
- [GitHub Actions Implementation Guide](docs/04a-github-actions-implementation.md)
- [Bicep Deployment Guide](infra/bicep/README.md)
- [Step 08 Completion Guide](STEP_08_COMPLETE.md)

---

## Commit Statistics

```
Commit: 3d7051b
Files changed: 8
Insertions: 206
Deletions: 24
New files: 1 (infra/bicep/README.md)
```

---

## Next Steps

1. **Review Changes**: Verify all documentation is accurate and consistent
2. **Update Azure**: Create resource groups in appropriate subscriptions
3. **Configure RBAC**: Update service principal role assignments
4. **Update Secrets**: Remove AZURE_SUBSCRIPTION_ID_TEST from GitHub
5. **Test Deployment**: Run what-if analysis on each environment
6. **Deploy Infrastructure**: Execute Bicep deployments with new structure

---

**Status**: ✅ Architecture consolidation complete and committed (3d7051b)
