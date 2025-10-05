# AI Prompt: Create Infrastructure CI/CD Workflows

## Objective
Create GitHub Actions workflows for Bicep infrastructure validation (CI) and deployment (CD) with OIDC authentication.

## Prerequisites
- Azure OIDC authentication configured
- GitHub secrets set: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
- GitHub environments created: dev, test, prod
- Bicep templates ready (or will be created separately)

## Prompt

```
I need you to create comprehensive GitHub Actions workflows for infrastructure CI/CD using Bicep and Azure OIDC authentication.

Context:
- Project: Healthcare EDI platform on Azure
- IaC Tool: Bicep (not Terraform or ARM)
- Authentication: Azure OIDC (Workload Identity Federation) - passwordless
- Environments: dev (auto-deploy), test (1 approval), prod (2 approvals + 5min wait)
- Region: East US 2
- Deployment scope: Resource Group level

Please create these workflow files:

---

## 1. Infrastructure CI Workflow (.github/workflows/infra-ci.yml)

Triggers:
- Pull requests modifying files in infra/bicep/**
- Manual workflow_dispatch for testing

Jobs:
1. **bicep-lint**: 
   - Runs Bicep linter on all templates
   - Uses 'az bicep build --file'
   - Fails on errors, warns on issues

2. **bicep-validate**:
   - Validates templates against Azure
   - Uses 'az deployment group validate'
   - Checks for all environments (dev, test, prod)

3. **what-if-analysis**:
   - Runs 'az deployment group what-if' for dev environment
   - Posts results as PR comment
   - Shows what will change on merge

4. **security-scan**:
   - Scans for security issues in Bicep
   - Checks for:
     - Public endpoints
     - Missing encryption
     - Weak authentication
     - Missing RBAC
   - Uses Microsoft Security DevOps or Checkov

5. **cost-estimation** (optional):
   - Estimates deployment cost
   - Uses Azure Pricing API or Infracost
   - Posts cost impact to PR

Requirements:
- Use Ubuntu latest runner
- Checkout code with full history
- Use Azure CLI for Bicep operations
- Post summary to PR as comment
- Fail PR if critical issues found
- Use OIDC authentication (no service principal secrets)

---

## 2. Infrastructure CD Workflow (.github/workflows/infra-cd.yml)

Triggers:
- Push to main branch with changes in infra/bicep/**
- Manual workflow_dispatch with environment selection

Jobs:
1. **deploy-dev**:
   - Authenticates via OIDC to Azure
   - Deploys to dev resource group
   - Uses parameter file: env/dev.parameters.json
   - Runs automatically on merge to main
   - Tags deployment with git commit SHA

2. **deploy-test**:
   - Depends on: deploy-dev success
   - Requires: 1 manual approval (environment protection)
   - Deploys to test resource group
   - Uses parameter file: env/test.parameters.json
   - Sends notification to Teams on start

3. **deploy-prod**:
   - Depends on: deploy-test success
   - Requires: 2 manual approvals + 5 min wait time
   - Deploys to prod resource group
   - Uses parameter file: env/prod.parameters.json
   - Creates deployment backup/snapshot before deploy
   - Sends critical alert to Teams on completion
   - Tags deployment with release version

4. **post-deployment-tests**:
   - Validates deployment was successful
   - Checks resource health
   - Verifies network connectivity
   - Confirms Key Vault access
   - Tests Function App endpoint

Requirements:
- Use matrix strategy for environments where applicable
- Store deployment outputs for use in function deployment
- Upload deployment artifacts
- Comprehensive error handling
- Rollback capability on failure (optional but nice to have)
- Use concurrency control to prevent parallel deployments

---

## 3. Drift Detection Workflow (.github/workflows/drift-detection.yml)

Triggers:
- Scheduled: Daily at 2 AM UTC (cron: '0 2 * * *')
- Manual workflow_dispatch

Jobs:
1. **detect-drift**:
   - Runs 'az deployment group what-if' in validate mode
   - Compares current Azure state vs Bicep templates
   - For each environment: dev, test, prod

2. **report-drift**:
   - If drift detected:
     - Creates GitHub issue with drift details
     - Sends alert to Teams channel
     - Tags issue with 'drift' and environment labels
   - If no drift:
     - Updates existing drift issues as resolved
     - Logs success to monitoring

Requirements:
- Authenticate via OIDC
- Run for all environments in parallel
- Clear reporting of what has drifted
- Link to Azure portal resource
- Suggest remediation steps

---

For all workflows:

Authentication pattern to use:
```yaml
- name: Azure Login via OIDC
  uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

Common environment variables to set:
```yaml
env:
  AZURE_LOCATION: ${{ vars.AZURE_LOCATION }}
  PROJECT_NAME: ${{ vars.PROJECT_NAME }}
  DEV_RESOURCE_GROUP: ${{ vars.DEV_RESOURCE_GROUP }}
  TEST_RESOURCE_GROUP: ${{ vars.TEST_RESOURCE_GROUP }}
  PROD_RESOURCE_GROUP: ${{ vars.PROD_RESOURCE_GROUP }}
```

Best practices to include:
- Use specific action versions (not @latest)
- Cache dependencies where possible
- Fail fast on errors
- Clear job names and step descriptions
- Use workflow artifacts for deployment records
- Include deployment time in output
- Log deployment URLs
- Use GitHub Environment protection rules
- Add concurrency control to prevent conflicts
- Include health checks after deployment

Also provide:
1. README section explaining how to use these workflows
2. Troubleshooting guide for common issues
3. How to manually trigger workflows
4. How to view deployment history
5. Example PR comment format for what-if results
```

## Expected Outcome

After running this prompt, you should have:
- ✅ `.github/workflows/infra-ci.yml` created
- ✅ `.github/workflows/infra-cd.yml` created
- ✅ `.github/workflows/drift-detection.yml` created
- ✅ Workflows use OIDC authentication
- ✅ Comprehensive validation and deployment logic
- ✅ Documentation provided

## Validation Steps

1. Commit and push workflows:
   ```powershell
   git add .github/workflows/
   git commit -m "feat: Add infrastructure CI/CD workflows"
   git push origin main
   ```

2. Test CI workflow:
   ```powershell
   # Create a test PR with Bicep changes
   git checkout -b test/infra-workflow
   echo "// test comment" >> infra/bicep/main.bicep
   git add infra/bicep/main.bicep
   git commit -m "test: Trigger infra CI"
   git push origin test/infra-workflow
   # Create PR in GitHub UI and watch workflows run
   ```

3. Verify workflow execution:
   - Go to: Actions tab in GitHub
   - Check workflow runs
   - Review job logs
   - Verify OIDC authentication works
   - Check what-if results posted to PR

4. Test CD workflow:
   - Merge test PR to main
   - Watch automatic dev deployment
   - Approve test deployment
   - Verify resources created in Azure

## Troubleshooting

**OIDC Authentication Fails**
- Verify federated credential subject matches exactly
- Check service principal has Contributor role on resource group
- Validate AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID secrets

**Bicep Validation Fails**
- Run locally: `az bicep build --file infra/bicep/main.bicep`
- Check parameter file exists and has correct schema
- Verify Azure provider registration

**What-If Takes Too Long**
- Expected for large templates (5-10 minutes)
- Consider splitting large templates into modules
- Use resource group scoped deployments instead of subscription

## Next Steps

After successful completion:
- Proceed to [05-create-function-workflows.md](05-create-function-workflows.md)
- Begin creating Bicep templates [08-create-bicep-templates.md](08-create-bicep-templates.md)
- Configure monitoring workflows [06-create-monitoring-workflows.md](06-create-monitoring-workflows.md)
