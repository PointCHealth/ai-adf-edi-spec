# GitHub Actions Setup Guide

**Document Version:** 1.0  
**Last Updated:** October 6, 2025  
**Status:** Production Ready  
**Owner:** EDI Platform Team (DevOps)

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Azure Authentication Setup](#2-azure-authentication-setup)
3. [Repository Configuration](#3-repository-configuration)
4. [GitHub Environments](#4-github-environments)
5. [Secrets and Variables](#5-secrets-and-variables)
6. [Branch Protection](#6-branch-protection)
7. [Verification](#7-verification)

---

## 1. Prerequisites

### 1.1 Required Access

- **Azure:** Subscription Owner or User Access Administrator role
- **GitHub:** Repository Admin access to all 5 repositories
- **Azure CLI:** Version 2.53.0 or later installed locally
- **GitHub CLI:** `gh` CLI installed and authenticated

### 1.2 Required Information

Gather the following before starting:

| Information | Example | Where to Find |
|-------------|---------|---------------|
| Azure Tenant ID | `12345678-1234-1234-1234-123456789012` | `az account show --query tenantId` |
| Dev Subscription ID | `abcd1234-...` | Azure Portal → Subscriptions |
| Prod Subscription ID | `efgh5678-...` | Azure Portal → Subscriptions |
| Repository Full Name | `PointCHealth/edi-platform-core` | GitHub repository URL |

### 1.3 Tools Installation

```powershell
# Install Azure CLI (if not installed)
winget install Microsoft.AzureCLI

# Install GitHub CLI
winget install GitHub.cli

# Install Bicep
az bicep install

# Verify installations
az --version
gh --version
az bicep version
```

---

## 2. Azure Authentication Setup

### 2.1 Overview

We use **OpenID Connect (OIDC)** for passwordless authentication between GitHub Actions and Azure. This provides:

- ✅ No secrets stored in GitHub
- ✅ Short-lived tokens (valid only during workflow execution)
- ✅ Automatic token rotation
- ✅ Federated identity trust

### 2.2 Create Azure AD App Registrations

#### Option A: Separate Apps per Environment (Recommended)

Create one app per environment for fine-grained access control:

```powershell
# Login to Azure
az login

# Variables
$tenantId = az account show --query tenantId -o tsv
$devSubscriptionId = "your-dev-subscription-id"
$prodSubscriptionId = "your-prod-subscription-id"
$repo = "PointCHealth/edi-platform-core"  # Update for each repository

# Create Dev Environment App
$appNameDev = "github-actions-edi-dev"
$appIdDev = az ad app create --display-name $appNameDev --query appId -o tsv
az ad sp create --id $appIdDev

Write-Host "Dev App Created: $appIdDev" -ForegroundColor Green

# Create Prod Environment App
$appNameProd = "github-actions-edi-prod"
$appIdProd = az ad app create --display-name $appNameProd --query appId -o tsv
az ad sp create --id $appIdProd

Write-Host "Prod App Created: $appIdProd" -ForegroundColor Green

# Save these values for later
Write-Host "`nSave these values:" -ForegroundColor Yellow
Write-Host "AZURE_TENANT_ID: $tenantId"
Write-Host "AZURE_CLIENT_ID_DEV: $appIdDev"
Write-Host "AZURE_CLIENT_ID_PROD: $appIdProd"
Write-Host "AZURE_SUBSCRIPTION_ID_DEV: $devSubscriptionId"
Write-Host "AZURE_SUBSCRIPTION_ID_PROD: $prodSubscriptionId"
```

#### Option B: Single App for All Environments (Simpler)

Use one app with federated credentials for each environment:

```powershell
$appName = "github-actions-edi-platform"
$appId = az ad app create --display-name $appName --query appId -o tsv
az ad sp create --id $appId
Write-Host "App Created: $appId" -ForegroundColor Green
```

### 2.3 Create Federated Credentials

#### For Dev Environment

```powershell
$appId = "your-app-id-from-above"
$repo = "PointCHealth/edi-platform-core"

# Create federated credential for dev environment
az ad app federated-credential create `
  --id $appId `
  --parameters @"
{
  \"name\": \"github-dev-environment\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:$repo:environment:dev\",
  \"description\": \"GitHub Actions OIDC for dev environment\",
  \"audiences\": [
    \"api://AzureADTokenExchange\"
  ]
}
"@

Write-Host "✅ Federated credential created for dev environment" -ForegroundColor Green
```

#### For Test Environment

```powershell
az ad app federated-credential create `
  --id $appId `
  --parameters @"
{
  \"name\": \"github-test-environment\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:$repo:environment:test\",
  \"description\": \"GitHub Actions OIDC for test environment\",
  \"audiences\": [
    \"api://AzureADTokenExchange\"
  ]
}
"@

Write-Host "✅ Federated credential created for test environment" -ForegroundColor Green
```

#### For Prod Environment

```powershell
az ad app federated-credential create `
  --id $appId `
  --parameters @"
{
  \"name\": \"github-prod-environment\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:$repo:environment:prod\",
  \"description\": \"GitHub Actions OIDC for prod environment\",
  \"audiences\": [
    \"api://AzureADTokenExchange\"
  ]
}
"@

Write-Host "✅ Federated credential created for prod environment" -ForegroundColor Green
```

#### For Pull Request Validation (No Environment)

```powershell
az ad app federated-credential create `
  --id $appId `
  --parameters @"
{
  \"name\": \"github-pull-request\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:$repo:pull_request\",
  \"description\": \"GitHub Actions OIDC for pull request validation\",
  \"audiences\": [
    \"api://AzureADTokenExchange\"
  ]
}
"@

Write-Host "✅ Federated credential created for pull requests" -ForegroundColor Green
```

#### For Main Branch Deployments

```powershell
az ad app federated-credential create `
  --id $appId `
  --parameters @"
{
  \"name\": \"github-main-branch\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:$repo:ref:refs/heads/main\",
  \"description\": \"GitHub Actions OIDC for main branch\",
  \"audiences\": [
    \"api://AzureADTokenExchange\"
  ]
}
"@

Write-Host "✅ Federated credential created for main branch" -ForegroundColor Green
```

### 2.4 Assign Azure RBAC Permissions

#### Dev Environment Permissions

```powershell
$appId = "your-app-id"
$devSubscriptionId = "your-dev-subscription-id"
$devResourceGroup = "rg-edi-dev-eastus2"

# Contributor role to dev resource group
az role assignment create `
  --assignee $appId `
  --role "Contributor" `
  --scope "/subscriptions/$devSubscriptionId/resourceGroups/$devResourceGroup"

Write-Host "✅ Granted Contributor to dev resource group" -ForegroundColor Green

# Test resource group (in same subscription)
$testResourceGroup = "rg-edi-test-eastus2"
az role assignment create `
  --assignee $appId `
  --role "Contributor" `
  --scope "/subscriptions/$devSubscriptionId/resourceGroups/$testResourceGroup"

Write-Host "✅ Granted Contributor to test resource group" -ForegroundColor Green
```

#### Prod Environment Permissions

```powershell
$appIdProd = "your-prod-app-id"
$prodSubscriptionId = "your-prod-subscription-id"
$prodResourceGroup = "rg-edi-prod-eastus2"

# Contributor role to prod resource group
az role assignment create `
  --assignee $appIdProd `
  --role "Contributor" `
  --scope "/subscriptions/$prodSubscriptionId/resourceGroups/$prodResourceGroup"

Write-Host "✅ Granted Contributor to prod resource group" -ForegroundColor Green

# Reader role at subscription level for cost queries
az role assignment create `
  --assignee $appIdProd `
  --role "Reader" `
  --scope "/subscriptions/$prodSubscriptionId"

Write-Host "✅ Granted Reader to prod subscription" -ForegroundColor Green
```

#### Key Vault Permissions (Optional)

If workflows need to manage Key Vault secrets:

```powershell
$keyVaultName = "kv-edi-dev-eastus2"
$appId = "your-app-id"

az role assignment create `
  --assignee $appId `
  --role "Key Vault Secrets Officer" `
  --scope "/subscriptions/$devSubscriptionId/resourceGroups/$devResourceGroup/providers/Microsoft.KeyVault/vaults/$keyVaultName"

Write-Host "✅ Granted Key Vault Secrets Officer" -ForegroundColor Green
```

---

## 3. Repository Configuration

### 3.1 Create GitHub Secrets

Navigate to **Repository Settings → Secrets and variables → Actions → New repository secret**

```powershell
# Use GitHub CLI to add secrets
$repo = "PointCHealth/edi-platform-core"
$tenantId = "your-tenant-id"
$clientId = "your-client-id"
$devSubId = "your-dev-subscription-id"
$prodSubId = "your-prod-subscription-id"

# Add repository secrets
gh secret set AZURE_TENANT_ID --body "$tenantId" --repo $repo
gh secret set AZURE_CLIENT_ID --body "$clientId" --repo $repo
gh secret set AZURE_SUBSCRIPTION_ID_DEV --body "$devSubId" --repo $repo
gh secret set AZURE_SUBSCRIPTION_ID_PROD --body "$prodSubId" --repo $repo

Write-Host "✅ Repository secrets configured" -ForegroundColor Green
```

**Secrets to Configure:**

| Secret Name | Value | Used By |
|-------------|-------|---------|
| `AZURE_TENANT_ID` | Your Azure AD tenant ID | All workflows |
| `AZURE_CLIENT_ID` | App registration client ID | All workflows (if single app) |
| `AZURE_SUBSCRIPTION_ID_DEV` | Dev subscription ID | Dev/Test deployments |
| `AZURE_SUBSCRIPTION_ID_PROD` | Prod subscription ID | Prod deployments |

### 3.2 Create GitHub Variables

Navigate to **Repository Settings → Secrets and variables → Actions → Variables**

```powershell
# Add repository variables
gh variable set DEV_RESOURCE_GROUP --body "rg-edi-dev-eastus2" --repo $repo
gh variable set TEST_RESOURCE_GROUP --body "rg-edi-test-eastus2" --repo $repo
gh variable set PROD_RESOURCE_GROUP --body "rg-edi-prod-eastus2" --repo $repo
gh variable set AZURE_LOCATION --body "eastus2" --repo $repo

Write-Host "✅ Repository variables configured" -ForegroundColor Green
```

**Variables to Configure:**

| Variable Name | Value | Purpose |
|---------------|-------|---------|
| `DEV_RESOURCE_GROUP` | `rg-edi-dev-eastus2` | Dev deployment target |
| `TEST_RESOURCE_GROUP` | `rg-edi-test-eastus2` | Test deployment target |
| `PROD_RESOURCE_GROUP` | `rg-edi-prod-eastus2` | Prod deployment target |
| `AZURE_LOCATION` | `eastus2` | Default Azure region |

### 3.3 Repeat for All Repositories

Repeat sections 3.1 and 3.2 for all 5 repositories:

1. `PointCHealth/edi-platform-core`
2. `PointCHealth/edi-mappers`
3. `PointCHealth/edi-connectors`
4. `PointCHealth/edi-partner-configs`
5. `PointCHealth/edi-data-platform`

**Tip:** Create a PowerShell script to automate this:

```powershell
$repos = @(
    "PointCHealth/edi-platform-core",
    "PointCHealth/edi-mappers",
    "PointCHealth/edi-connectors",
    "PointCHealth/edi-partner-configs",
    "PointCHealth/edi-data-platform"
)

foreach ($repo in $repos) {
    Write-Host "Configuring $repo..." -ForegroundColor Cyan
    
    # Secrets
    gh secret set AZURE_TENANT_ID --body "$tenantId" --repo $repo
    gh secret set AZURE_CLIENT_ID --body "$clientId" --repo $repo
    gh secret set AZURE_SUBSCRIPTION_ID_DEV --body "$devSubId" --repo $repo
    gh secret set AZURE_SUBSCRIPTION_ID_PROD --body "$prodSubId" --repo $repo
    
    # Variables
    gh variable set DEV_RESOURCE_GROUP --body "rg-edi-dev-eastus2" --repo $repo
    gh variable set TEST_RESOURCE_GROUP --body "rg-edi-test-eastus2" --repo $repo
    gh variable set PROD_RESOURCE_GROUP --body "rg-edi-prod-eastus2" --repo $repo
    gh variable set AZURE_LOCATION --body "eastus2" --repo $repo
    
    Write-Host "✅ $repo configured" -ForegroundColor Green
}
```

---

## 4. GitHub Environments

### 4.1 Create Environments

Navigate to **Repository Settings → Environments → New environment**

Create three environments: `dev`, `test`, `prod`

### 4.2 Configure Dev Environment

**Settings → Environments → dev**

**Deployment protection rules:** None (auto-deploy)

**Environment secrets:** (optional, if using environment-specific apps)
- `AZURE_CLIENT_ID` (if different from repository secret)

**Environment variables:**
```powershell
gh api --method PUT /repos/$repo/environments/dev/variables/ENVIRONMENT --field name="ENVIRONMENT" --field value="dev"
gh api --method PUT /repos/$repo/environments/dev/variables/RESOURCE_GROUP --field name="RESOURCE_GROUP" --field value="rg-edi-dev-eastus2"
```

### 4.3 Configure Test Environment

**Settings → Environments → test**

**Deployment protection rules:**
- ✅ Required reviewers: Select 1 reviewer from `@data-engineering-team`
- ✅ Wait timer: 0 minutes
- ⬜ Prevent administrators from bypassing

**Deployment branches:** `main` only

**Environment variables:**
```powershell
gh api --method PUT /repos/$repo/environments/test/variables/ENVIRONMENT --field name="ENVIRONMENT" --field value="test"
gh api --method PUT /repos/$repo/environments/test/variables/RESOURCE_GROUP --field name="RESOURCE_GROUP" --field value="rg-edi-test-eastus2"
```

### 4.4 Configure Prod Environment

**Settings → Environments → prod**

**Deployment protection rules:**
- ✅ Required reviewers: Select 2 reviewers (platform lead + security team member)
- ✅ Wait timer: 5 minutes (cooling-off period)
- ✅ Prevent administrators from bypassing

**Deployment branches:** `main` and `hotfix/*`

**Environment secrets:**
- `TEAMS_WEBHOOK_URL` - Microsoft Teams webhook for notifications

**Environment variables:**
```powershell
gh api --method PUT /repos/$repo/environments/prod/variables/ENVIRONMENT --field name="ENVIRONMENT" --field value="prod"
gh api --method PUT /repos/$repo/environments/prod/variables/RESOURCE_GROUP --field name="RESOURCE_GROUP" --field value="rg-edi-prod-eastus2"
gh api --method PUT /repos/$repo/environments/prod/variables/ENABLE_CHANGE_VALIDATION --field name="ENABLE_CHANGE_VALIDATION" --field value="true"
```

---

## 5. Secrets and Variables

### 5.1 Secret Management Best Practices

- ✅ **Never commit secrets to Git**
- ✅ **Use environment-scoped secrets** for environment-specific values
- ✅ **Rotate secrets quarterly** (review calendar reminder)
- ✅ **Use Azure Key Vault** for application secrets (not CI/CD secrets)
- ✅ **Enable secret scanning** (Settings → Code security → Secret scanning)

### 5.2 Secrets Inventory

| Secret | Scope | Value Source | Rotation Schedule |
|--------|-------|--------------|-------------------|
| `AZURE_TENANT_ID` | Repository | Azure AD | Never (stable) |
| `AZURE_CLIENT_ID` | Repository | App registration | Never (stable) |
| `AZURE_SUBSCRIPTION_ID_DEV` | Repository | Azure subscription | Never (stable) |
| `AZURE_SUBSCRIPTION_ID_PROD` | Repository | Azure subscription | Never (stable) |
| `TEAMS_WEBHOOK_URL` | Environment (prod) | Teams channel | Annually |

**Note:** OIDC tokens are short-lived and auto-rotated, so no credential rotation needed.

### 5.3 Variables Inventory

| Variable | Scope | Value | Purpose |
|----------|-------|-------|---------|
| `DEV_RESOURCE_GROUP` | Repository | `rg-edi-dev-eastus2` | Dev deployment target |
| `TEST_RESOURCE_GROUP` | Repository | `rg-edi-test-eastus2` | Test deployment target |
| `PROD_RESOURCE_GROUP` | Repository | `rg-edi-prod-eastus2` | Prod deployment target |
| `AZURE_LOCATION` | Repository | `eastus2` | Default region |
| `ENVIRONMENT` | Environment | `dev`/`test`/`prod` | Environment name |
| `RESOURCE_GROUP` | Environment | Resource group name | Environment-specific RG |

---

## 6. Branch Protection

### 6.1 Configure Main Branch Protection

Navigate to **Settings → Branches → Add rule**

**Branch name pattern:** `main`

**Settings to enable:**

```
✅ Require a pull request before merging
  ✅ Require approvals: 2
  ✅ Dismiss stale pull request approvals when new commits are pushed
  ✅ Require review from Code Owners

✅ Require status checks to pass before merging
  ✅ Require branches to be up to date before merging
  Required status checks:
    - validate / bicep-build (or build / dotnet-build for app repos)
    - validate / security-scan
    - validate / whatif-dev (for IaC repos)

✅ Require conversation resolution before merging

✅ Require signed commits

✅ Require linear history

✅ Do not allow bypassing the above settings

✅ Restrict who can push to matching branches
  Allowed actors: Admins only

⬜ Allow force pushes

⬜ Allow deletions
```

### 6.2 CODEOWNERS File

Create `.github/CODEOWNERS` in each repository:

```plaintext
# Infrastructure & IaC
/infra/                 @vincemic @platform-team
/env/                   @vincemic @platform-team
/.github/workflows/     @vincemic @platform-team

# Application Code
/src/                   @vincemic @data-engineering-team

# Configuration
/config/                @vincemic @partner-management-team

# Security & Compliance
/docs/*security*        @vincemic @security-team
/docs/*compliance*      @vincemic @compliance-team

# Catch-all
*                       @vincemic
```

### 6.3 Hotfix Branch Protection

**Branch name pattern:** `hotfix/*`

**Settings:** Same as main, but:
- Require approvals: **1** (expedited for production incidents)
- Allow force pushes: ✅ (for rebase)
- Include administrators: ✅ (can be overridden in emergency)

---

## 7. Verification

### 7.1 Test Azure OIDC Authentication

Create a test workflow to verify authentication:

**File:** `.github/workflows/test-azure-auth.yml`

```yaml
name: Test Azure Authentication

on:
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  test-auth:
    runs-on: ubuntu-latest
    environment: dev
    
    steps:
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID_DEV }}
      
      - name: Verify Login
        run: |
          echo "Testing Azure CLI access..."
          az account show
          az group list --query "[].name" -o table
      
      - name: Test Resource Group Access
        run: |
          az group show --name ${{ vars.DEV_RESOURCE_GROUP }}
```

**Run the workflow:**
1. Go to Actions → Test Azure Authentication → Run workflow
2. Verify it completes successfully
3. Check that Azure CLI commands execute without errors

### 7.2 Verification Checklist

Complete this checklist for each repository:

- [ ] Azure AD app registration created
- [ ] Federated credentials created for all environments (dev, test, prod, PR)
- [ ] RBAC permissions assigned to dev and prod resource groups
- [ ] Repository secrets configured (`AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, etc.)
- [ ] Repository variables configured (`DEV_RESOURCE_GROUP`, etc.)
- [ ] GitHub environments created (dev, test, prod)
- [ ] Environment protection rules configured (approvers, wait timers)
- [ ] Environment-specific secrets/variables configured
- [ ] Branch protection enabled on `main` branch
- [ ] CODEOWNERS file created and committed
- [ ] Test authentication workflow runs successfully
- [ ] Team members added to required reviewer lists

### 7.3 Common Issues

| Issue | Symptoms | Resolution |
|-------|----------|------------|
| **OIDC Login Fails** | "Error: Unable to get federated token" | Verify `id-token: write` permission in workflow; check federated credential subject matches repo exactly |
| **Permission Denied** | "AuthorizationFailed" when deploying | Verify RBAC role assignment; check scope is correct resource group |
| **Environment Not Found** | Workflow skips deployment step | Create environment in GitHub Settings → Environments |
| **Approval Not Requested** | Deployment starts without approval | Verify environment protection rules are saved; check deployment uses `environment:` key |

### 7.4 Support

If you encounter issues:
1. Check [Troubleshooting Guide](./07-troubleshooting-guide.md)
2. Review GitHub Actions logs for detailed error messages
3. Contact @platform-team on Teams
4. Create GitHub issue with `devops` label

---

## Next Steps

✅ **Configuration complete!**

Now proceed to:
1. [03-cicd-workflows.md](./03-cicd-workflows.md) - Implement CI/CD workflows
2. [04-deployment-procedures.md](./04-deployment-procedures.md) - Test deployments
3. Configure monitoring and alerting

---

**Document Maintenance:**
- Review after any Azure AD tenant changes
- Update when adding new repositories
- Validate quarterly for security best practices
