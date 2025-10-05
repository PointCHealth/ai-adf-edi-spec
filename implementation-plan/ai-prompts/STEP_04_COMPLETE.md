# Step 04: Infrastructure CI/CD Workflows - COMPLETE ✅

**Completion Date:** 2025-01-23  
**Status:** ✅ Complete  
**Repository:** edi-platform-core

## Summary

Successfully created three comprehensive GitHub Actions workflows for Infrastructure as Code (IaC) automation:

1. **Infrastructure CI** (`infra-ci.yml`) - Pull request validation
2. **Infrastructure CD** (`infra-cd.yml`) - Multi-environment deployment pipeline
3. **Drift Detection** (`infra-drift-detection.yml`) - Daily configuration drift monitoring

## Created Files

### 1. Infrastructure CI Workflow
**File:** `.github/workflows/infra-ci.yml`  
**Lines:** 380+  
**Commit:** 92d82b5

**Features:**
- **Bicep Lint:** Validates syntax and best practices for all Bicep templates
- **Bicep Validate:** Tests templates against Azure (matrix: dev/test/prod)
- **What-If Analysis:** Shows predicted infrastructure changes, posts to PR comments
- **Security Scan:** Microsoft Security DevOps with SARIF upload to GitHub Security
- **Cost Estimation:** Calculates monthly Azure costs, posts to PR comments
- **CI Summary:** Consolidated results in GitHub step summary

**Triggers:**
- Pull requests modifying `infra/bicep/**` files
- Manual workflow dispatch

**Key Capabilities:**
- OIDC authentication (passwordless)
- Parallel execution where possible
- PR comments with actionable insights
- Security findings integrated with GitHub Security tab
- Matrix strategy for multi-environment validation

### 2. Infrastructure CD Workflow
**File:** `.github/workflows/infra-cd.yml`  
**Lines:** 520+  
**Commit:** 92d82b5

**Features:**
- **Dev Deployment:** Auto-deploys on main branch push (no approval required)
- **Test Deployment:** Deploys after dev success (requires 1 manual approval via environment protection)
- **Prod Deployment:** Deploys after test success (requires 2 manual approvals + 5-minute wait time)
- **Post-Deployment Tests:** Health checks after dev deployment
- **Deployment Artifacts:** Stores deployment outputs for 30/60/90 days (dev/test/prod)
- **Backup Creation:** Before prod deployment, exports current state

**Environment Gates:**
| Environment | Auto-Deploy | Approvals Required | Wait Time | Artifact Retention |
|-------------|-------------|--------------------|-----------|--------------------|
| Dev         | ✅ Yes      | 0                  | 0         | 30 days            |
| Test        | ❌ No       | 1                  | 0         | 60 days            |
| Production  | ❌ No       | 2                  | 5 minutes | 90 days            |

**Triggers:**
- Push to main branch modifying `infra/bicep/**` or `env/*.parameters.json`
- Manual workflow dispatch with environment selection

**Key Capabilities:**
- Progressive deployment pipeline (dev → test → prod)
- Resource group auto-creation with proper tagging
- Deployment time tracking and reporting
- Azure Portal links in summaries
- Concurrency control to prevent simultaneous deployments
- Production backup before deployment

### 3. Drift Detection Workflow
**File:** `.github/workflows/infra-drift-detection.yml`  
**Lines:** 530+  
**Commit:** 92d82b5

**Features:**
- **Scheduled Scans:** Runs daily at 2 AM UTC
- **Multi-Environment:** Checks dev, test, and production independently
- **What-If Analysis:** Compares actual Azure state vs. Bicep templates
- **Drift Reports:** JSON and YAML artifacts for detailed analysis
- **Issue Creation:** Automatically creates GitHub issues when drift detected
- **Critical Alerts:** Elevated severity for production drift

**Drift Detection Logic:**
1. Runs `az deployment group what-if` against each environment
2. Analyzes output for resource changes (create, modify, delete)
3. Generates drift reports (JSON for parsing, YAML for readability)
4. Creates/updates GitHub issues if drift found
5. Tags issues appropriately (critical for production)

**Triggers:**
- Daily cron schedule: `0 2 * * *` (2 AM UTC)
- Manual workflow dispatch with environment filter

**Key Capabilities:**
- Detects manual Azure Portal changes
- Identifies configuration divergence
- Distinguishes between planned vs. unplanned drift
- Creates actionable GitHub issues with context
- Provides artifact retention (30/30/90 days for dev/test/prod)

## Workflow Interaction

```
┌─────────────────────────────────────────────────────────────┐
│                      Developer Workflow                     │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
                    ┌──────────────────┐
                    │  Create PR with  │
                    │  Bicep changes   │
                    └──────────────────┘
                               │
                               ▼
                    ┌──────────────────┐
                    │   infra-ci.yml   │ ◄── Validates, lints, security scan
                    │  (PR Validation) │     Posts what-if & cost to PR
                    └──────────────────┘
                               │
                               ▼
                    ┌──────────────────┐
                    │    Merge to PR   │
                    │    to main       │
                    └──────────────────┘
                               │
                               ▼
                    ┌──────────────────┐
                    │   infra-cd.yml   │ ◄── Deploys to Dev (auto)
                    │   (Deployment)   │     Deploys to Test (1 approval)
                    └──────────────────┘     Deploys to Prod (2 approvals + wait)
                               │
                               ▼
                    ┌──────────────────┐
                    │ Post-deployment  │
                    │  health checks   │
                    └──────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Scheduled Monitoring                      │
└─────────────────────────────────────────────────────────────┘
                               │
                   Every day at 2 AM UTC
                               │
                               ▼
                    ┌──────────────────┐
                    │ infra-drift-     │ ◄── Runs what-if analysis
                    │ detection.yml    │     Creates issues if drift found
                    └──────────────────┘     Alerts on production drift
```

## Authentication & Security

All workflows use **Azure OIDC (Workload Identity Federation)** for passwordless authentication:

**Required Secrets** (to be configured manually):
- `AZURE_CLIENT_ID`: Service principal client ID
- `AZURE_TENANT_ID`: Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID`: Target Azure subscription

**Required Variables** (✅ already configured in Step 03):
- `AZURE_LOCATION`: Azure region (e.g., eastus)
- `DEV_RESOURCE_GROUP`, `TEST_RESOURCE_GROUP`, `PROD_RESOURCE_GROUP`
- `PROJECT_NAME`: Project identifier
- `TAG_*`: Tagging standards

**Permissions:**
```yaml
permissions:
  id-token: write      # For OIDC authentication
  contents: read       # For checkout
  pull-requests: write # For PR comments (CI)
  issues: write        # For drift issues (drift detection)
  security-events: write # For SARIF upload (CI)
```

## Validation & Testing

### Lint Warnings
All three workflows have expected lint warnings about variables and secrets that don't exist yet. These are **not errors** and will resolve once secrets are configured:

- ✅ Variable references (e.g., `vars.AZURE_LOCATION`) - **configured in Step 03**
- ⏳ Secret references (e.g., `secrets.AZURE_CLIENT_ID`) - **to be configured manually**

### Pre-requisites for Execution

**Before workflows can run successfully:**

1. **Azure Service Principal**
   ```bash
   # Create service principal with OIDC
   az ad sp create-for-rbac \
     --name "edi-platform-github-actions" \
     --role Contributor \
     --scopes /subscriptions/{subscription-id}
   ```

2. **Configure Federated Credentials**
   ```bash
   # For main branch deployments
   az ad app federated-credential create \
     --id {app-id} \
     --parameters '{
       "name": "edi-platform-main",
       "issuer": "https://token.actions.githubusercontent.com",
       "subject": "repo:PointCHealth/edi-platform-core:ref:refs/heads/main",
       "audiences": ["api://AzureADTokenExchange"]
     }'
   
   # For pull requests (CI)
   az ad app federated-credential create \
     --id {app-id} \
     --parameters '{
       "name": "edi-platform-pr",
       "issuer": "https://token.actions.githubusercontent.com",
       "subject": "repo:PointCHealth/edi-platform-core:pull_request",
       "audiences": ["api://AzureADTokenExchange"]
     }'
   ```

3. **Configure GitHub Secrets** (in edi-platform-core repository settings)
   - Settings → Secrets and variables → Actions → New repository secret
   - Add: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

4. **Configure GitHub Environments** (for deployment approvals)
   ```
   Settings → Environments → New environment
   
   Environment: test
   - Required reviewers: 1 person
   
   Environment: prod
   - Required reviewers: 2 people
   - Wait timer: 5 minutes
   ```

## Usage Examples

### 1. Validate Infrastructure Changes (CI)

**Scenario:** Developer creates PR with Bicep template changes

**Automatic Actions:**
1. Workflow triggers on PR creation/update
2. Lints all Bicep files for syntax errors
3. Validates templates against Azure (dev/test/prod)
4. Runs what-if analysis showing predicted changes
5. Scans for security vulnerabilities
6. Estimates monthly costs
7. Posts results as PR comments

**Developer Experience:**
- See what-if analysis directly in PR: "Adding 3 resources, modifying 1, deleting 0"
- Review cost impact: "Estimated monthly cost: $234.56"
- Check security findings in PR checks
- Approve/request changes based on insights

### 2. Deploy Infrastructure (CD)

**Scenario A:** Push to main branch (auto-deploys to dev)
```bash
git checkout main
git merge feature/add-storage-account
git push origin main
```
- ✅ Automatically deploys to **dev** (no approval needed)
- ⏸️ Waits for 1 approval to deploy to **test**
- ⏸️ Waits for 2 approvals + 5 minutes to deploy to **prod**

**Scenario B:** Manual deployment to specific environment
1. Go to Actions tab → Infrastructure CD workflow
2. Click "Run workflow"
3. Select environment: dev/test/prod
4. Click "Run workflow" button
5. Approve when prompted (test: 1 approval, prod: 2 approvals + wait)

### 3. Monitor for Drift (Drift Detection)

**Automatic:** Runs daily at 2 AM UTC

**Manual Trigger:**
1. Go to Actions tab → Infrastructure Drift Detection workflow
2. Click "Run workflow"
3. Select environment: all/dev/test/prod
4. Click "Run workflow" button

**When Drift Detected:**
1. Issue created: "⚠️ Infrastructure Drift Detected"
2. Artifacts uploaded with detailed what-if analysis
3. Team tagged: @PointCHealth/platform-team
4. Priority set (critical if production affected)

**Resolution Workflow:**
1. Download drift report artifacts
2. Review changes (manual modifications?)
3. Choose action:
   - **Revert drift:** Re-run CD workflow to reset to template
   - **Accept drift:** Update Bicep templates to match current state
4. Document decision in issue
5. Close issue

## Metrics & Reporting

Each workflow generates comprehensive summaries:

### CI Workflow Output
```
## 🔍 Bicep Validation Summary

✅ Lint: 0 errors, 2 warnings
✅ Validation (dev): Succeeded
✅ Validation (test): Succeeded  
✅ Validation (prod): Succeeded
✅ Security Scan: 0 high, 1 medium findings
💰 Cost Estimate: $234.56/month

### What-If Analysis
- ➕ Create: 3 resources
- 🔄 Modify: 1 resource
- ➖ Delete: 0 resources
```

### CD Workflow Output
```
## 📊 Deployment Pipeline Summary

| Environment | Status     | Deployment Name          | Duration |
|-------------|------------|-------------------------|----------|
| Dev         | ✅ Success | infra-deploy-42-1234567 | 142s     |
| Test        | ✅ Success | infra-deploy-42-1234589 | 156s     |
| Prod        | ✅ Success | infra-deploy-42-1234612 | 167s     |
```

### Drift Detection Output
```
## 📊 Infrastructure Drift Detection Summary

| Environment | Status          | Details                    |
|-------------|-----------------|----------------------------|
| Dev         | ✅ No Drift     | Infrastructure matches     |
| Test        | ⚠️ Drift Found  | 2 resource changes         |
| Production  | ✅ No Drift     | Infrastructure matches     |
```

## Architecture Decisions

### 1. OIDC over Service Principal Secrets
**Decision:** Use Azure Workload Identity Federation (OIDC)  
**Rationale:**
- ✅ No secrets to rotate or expire
- ✅ Better security posture (token valid only during workflow execution)
- ✅ Easier compliance (no long-lived credentials)
- ✅ Microsoft recommended approach

### 2. Separate CI and CD Workflows
**Decision:** Split validation (CI) and deployment (CD) into separate workflows  
**Rationale:**
- ✅ CI runs on PRs (fast feedback, no deployment)
- ✅ CD runs on main (actual deployment after merge)
- ✅ Clear separation of concerns
- ✅ Better workflow reusability

### 3. Progressive Deployment (Dev → Test → Prod)
**Decision:** Sequential deployment with increasing gates  
**Rationale:**
- ✅ Validates changes in dev before test/prod
- ✅ Prevents bad deployments from reaching production
- ✅ Provides opportunity for testing at each stage
- ✅ Industry best practice

### 4. Daily Drift Detection
**Decision:** Run drift detection daily at 2 AM UTC  
**Rationale:**
- ✅ Detects manual changes within 24 hours
- ✅ Off-peak hours minimize performance impact
- ✅ Automatic issue creation for tracking
- ✅ Prevents configuration drift from accumulating

### 5. Artifact Retention by Environment
**Decision:** 30/60/90 days for dev/test/prod  
**Rationale:**
- ✅ Production needs longest audit trail (90 days)
- ✅ Dev can have shorter retention (30 days) to save storage costs
- ✅ Aligns with typical compliance requirements
- ✅ Balances storage costs vs. troubleshooting needs

## Known Limitations & Future Enhancements

### Current Limitations
1. **Bicep Templates Don't Exist Yet**
   - ✅ Workflows are ready
   - ⏳ Actual Bicep templates will be created in Phase 2 (Infrastructure Implementation)
   - Workflows will run successfully once `infra/bicep/main.bicep` exists

2. **Environment Protection Rules Not Created**
   - Workflows reference environments: dev, test, prod
   - Manual setup required in GitHub repository settings
   - See "Pre-requisites for Execution" section above

3. **Cost Estimation is Approximate**
   - Based on Azure pricing API
   - May not account for all discounts or reservations
   - Use as a guideline, not exact cost

### Future Enhancements
- [ ] Add Terraform support alongside Bicep
- [ ] Integrate cost optimization recommendations (Azure Advisor)
- [ ] Add performance testing after deployments
- [ ] Implement blue-green deployment strategy for zero-downtime
- [ ] Add automatic rollback on health check failures
- [ ] Integrate with Slack/Teams for deployment notifications
- [ ] Add approval bypass for emergency hotfixes (with audit trail)

## Troubleshooting Guide

### Issue: "OIDC authentication failed"
**Solution:**
1. Verify service principal exists: `az ad sp show --id {client-id}`
2. Check federated credentials are configured correctly
3. Ensure `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` secrets are set
4. Verify service principal has Contributor role on subscription/resource group

### Issue: "Bicep template not found"
**Solution:**
- This is expected until infrastructure Bicep templates are created
- Workflows will succeed once `infra/bicep/main.bicep` exists
- For now, workflows are staged and ready

### Issue: "Deployment requires approval but none configured"
**Solution:**
1. Go to Settings → Environments in GitHub repository
2. Create environments: `dev`, `test`, `prod`
3. Configure protection rules:
   - test: 1 required reviewer
   - prod: 2 required reviewers + 5-minute wait

### Issue: "Cost estimation shows $0.00"
**Solution:**
- Cost estimation requires existing resources or valid what-if output
- May show $0 for resource groups with no deployed resources
- Will populate once actual resources are deployed

### Issue: "Drift detection creates duplicate issues"
**Solution:**
- Workflow checks for existing open drift issues before creating new one
- If duplicates occur, manually close older issues
- Script will append to existing issue on next run

## Commit History

```bash
commit 92d82b5
Author: GitHub Actions (via AI Assistant)
Date:   Thu Jan 23 2025

    feat: Add infrastructure CI/CD workflows (CI, CD, Drift Detection)
    
    - infra-ci.yml: PR validation with lint, validate, what-if, security, cost
    - infra-cd.yml: Multi-environment deployment (dev auto, test 1 approval, prod 2 approvals + wait)
    - infra-drift-detection.yml: Daily drift detection with issue creation
    
    All workflows use OIDC authentication (passwordless)
    
    Related: Step 04 - Infrastructure Workflows
```

## Next Steps

**Immediate:**
- ✅ Workflows created and committed
- ⏳ Manual setup of Azure service principal and OIDC (see pre-requisites)
- ⏳ Manual configuration of GitHub environments and protection rules
- ⏳ Manual configuration of GitHub secrets

**Step 05: Function Workflows**
- Create workflows for Azure Function projects
- Build, test, and deploy function apps
- Configure function-specific variables

**Step 06: Monitoring Workflows**
- Cost monitoring and alerting
- Security scanning workflows
- Health check and availability monitoring

## Success Criteria ✅

- [x] Infrastructure CI workflow created (380+ lines)
- [x] Infrastructure CD workflow created (520+ lines)
- [x] Drift detection workflow created (530+ lines)
- [x] All workflows use OIDC authentication
- [x] Workflows include comprehensive documentation (comments)
- [x] PR comments for what-if and cost analysis
- [x] Security scanning integrated
- [x] Progressive deployment pipeline (dev → test → prod)
- [x] Environment protection gates defined
- [x] Drift detection with automatic issue creation
- [x] Proper artifact retention policies
- [x] Workflows committed to edi-platform-core repository

**Total Lines of Workflow Code:** 1,430+ lines  
**Repository:** https://github.com/PointCHealth/edi-platform-core  
**Branch:** main  
**Commit:** 92d82b5

---

**Step 04 Status:** ✅ COMPLETE  
**Ready for:** Step 05 (Function Workflows)
