# Deployment Procedures

**Document Version:** 1.0  
**Last Updated:** October 6, 2025  
**Status:** Production Ready  
**Owner:** EDI Platform Team (Operations)

---

## Table of Contents

1. [Pre-Deployment Checklist](#1-pre-deployment-checklist)
2. [Infrastructure Deployment](#2-infrastructure-deployment)
3. [Function App Deployment](#3-function-app-deployment)
4. [ADF Pipeline Deployment](#4-adf-pipeline-deployment)
5. [Configuration Deployment](#5-configuration-deployment)
6. [Post-Deployment Validation](#6-post-deployment-validation)
7. [Production Deployment](#7-production-deployment)

---

## 1. Pre-Deployment Checklist

### 1.1 General Prerequisites

Before any deployment, verify:

- [ ] Pull request reviewed and approved (2 approvers)
- [ ] All CI checks passed (build, test, security scan)
- [ ] What-if analysis reviewed (for infrastructure changes)
- [ ] Change ticket created and approved (production only)
- [ ] Stakeholders notified (production only, 48 hours advance)
- [ ] Rollback plan documented
- [ ] Deployment window scheduled (production only)

### 1.2 Environment-Specific Prerequisites

#### Dev Environment
- [ ] No prerequisites (auto-deploy)

#### Test Environment
- [ ] Successful deployment to dev environment
- [ ] Smoke tests passed in dev
- [ ] 1 approver from data engineering team available

#### Production Environment
- [ ] Successful deployment to test environment
- [ ] Integration tests passed in test
- [ ] Performance testing completed (for major releases)
- [ ] 2 approvers available (platform lead + security team)
- [ ] On-call engineer notified and available
- [ ] Backup of current configuration saved
- [ ] Change control ticket approved
- [ ] Deployment communication sent to stakeholders

---

## 2. Infrastructure Deployment

### 2.1 Infrastructure Deployment (Bicep)

#### Step 1: Verify PR Approval

```powershell
# Check PR status
gh pr view <PR_NUMBER> --repo PointCHealth/edi-data-platform
```

Verify:
- ✅ 2 approvals received
- ✅ CI checks passed
- ✅ What-if results reviewed

#### Step 2: Merge to Main

```powershell
# Merge PR (triggers auto-deploy to dev)
gh pr merge <PR_NUMBER> --squash --repo PointCHealth/edi-data-platform
```

**Expected Result:** GitHub Actions workflow `infra-cd.yml` triggered automatically

#### Step 3: Monitor Dev Deployment

```powershell
# Watch workflow execution
gh run watch --repo PointCHealth/edi-data-platform
```

**Expected Duration:** 5-10 minutes

**Monitor for:**
- ✅ Bicep deployment successful
- ✅ Resource tagging applied
- ✅ Smoke tests passed

#### Step 4: Validate Dev Deployment

```powershell
# Check deployment status in Azure
az deployment group show \
  --resource-group rg-edi-dev-eastus2 \
  --name deploy-<RUN_NUMBER>-<SHA> \
  --query properties.provisioningState
```

**Expected Output:** `"Succeeded"`

#### Step 5: Deploy to Test (Manual)

Navigate to **Actions → Infrastructure CD → Run workflow**

**Inputs:**
- Environment: `test`
- Skip tests: `false`

Click **Run workflow**

**Approval Required:** 1 reviewer from data engineering team

**Expected Duration:** 10-15 minutes

#### Step 6: Validate Test Deployment

```powershell
# Run integration tests
gh workflow run integration-tests.yml \
  --repo PointCHealth/edi-data-platform \
  --ref main \
  --field environment=test
```

**Expected Result:** All integration tests pass

#### Step 7: Deploy to Production (Manual)

Navigate to **Actions → Infrastructure CD → Run workflow**

**Inputs:**
- Environment: `prod`
- Skip tests: `false`

Click **Run workflow**

**Approval Required:**
- 2 reviewers (platform lead + security team)
- 5-minute wait timer

**Expected Duration:** 20-30 minutes

#### Step 8: Post-Deployment Validation

See [Section 6: Post-Deployment Validation](#6-post-deployment-validation)

---

## 3. Function App Deployment

### 3.1 Function App Deployment (.NET)

#### Step 1: Merge PR to Main

```powershell
# Merge PR (triggers build)
gh pr merge <PR_NUMBER> --squash --repo PointCHealth/edi-platform-core
```

**Expected Result:** `function-cd.yml` workflow triggered

#### Step 2: Monitor Build

```powershell
# Watch build workflow
gh run watch --repo PointCHealth/edi-platform-core
```

**Expected Duration:** 3-5 minutes

**Artifacts Created:**
- `function-app-<RUN_NUMBER>.zip`

#### Step 3: Auto-Deploy to Dev

**Automatic:** Dev deployment triggered on successful build

**Monitor Deployment:**

```powershell
# Check function app deployment
az functionapp deployment list-publishing-credentials \
  --name func-edi-router-dev-eastus2 \
  --resource-group rg-edi-dev-eastus2
```

#### Step 4: Validate Dev Deployment

```powershell
# Test health endpoint
curl https://func-edi-router-dev-eastus2.azurewebsites.net/api/health

# Check Application Insights for errors
az monitor app-insights metrics show \
  --app func-edi-router-dev-eastus2 \
  --metric exceptions/count \
  --start-time $(date -u -d '10 minutes ago' '+%Y-%m-%dT%H:%M:%SZ')
```

**Expected Result:** Health endpoint returns `200 OK`, no exceptions

#### Step 5: Deploy to Test (Manual)

Navigate to **Actions → Function App CD → Run workflow**

**Inputs:**
- Environment: `test`

Click **Run workflow**

**Approval Required:** 1 reviewer

**Deployment Strategy:** Staging slot swap (zero downtime)

**Expected Duration:** 5-7 minutes

#### Step 6: Run Integration Tests

```powershell
# Trigger integration test workflow
gh workflow run integration-tests.yml \
  --repo PointCHealth/edi-platform-core \
  --ref main \
  --field environment=test \
  --field function-app=router
```

**Expected Result:** All tests pass

#### Step 7: Deploy to Production (Manual)

Navigate to **Actions → Function App CD → Run workflow**

**Inputs:**
- Environment: `prod`

Click **Run workflow**

**Approval Required:** 2 reviewers + 5-minute wait

**Deployment Strategy:** Blue-green with health checks

**Expected Duration:** 10-15 minutes

#### Step 8: Monitor Production Deployment

```powershell
# Watch deployment logs
az functionapp log tail \
  --name func-edi-router-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2

# Monitor error rate
az monitor metrics list \
  --resource func-edi-router-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2 \
  --resource-type Microsoft.Web/sites \
  --metric requests/failed \
  --interval PT1M
```

**Watch for 10 minutes:** Error rate should remain below baseline

---

## 4. ADF Pipeline Deployment

### 4.1 ADF Development Workflow

#### Step 1: Develop in ADF UI

1. Open Azure Data Factory Studio
2. Connect to **collaboration branch** (`main`)
3. Create/modify pipelines, datasets, linked services
4. Click **Save All** (saves to Git branch)

#### Step 2: Create Pull Request

1. In ADF UI, click **Create Pull Request**
2. Or manually create PR in GitHub from `adf_publish` branch

#### Step 3: Validate PR

**Automatic:** `adf-ci.yml` workflow validates ADF resources

```powershell
# Check validation status
gh pr checks <PR_NUMBER> --repo PointCHealth/edi-data-platform
```

#### Step 4: Merge PR

```powershell
# Merge PR (triggers ARM export)
gh pr merge <PR_NUMBER> --squash --repo PointCHealth/edi-data-platform
```

**Expected Result:** `adf-export.yml` workflow generates ARM templates

#### Step 5: Deploy to Dev (Manual)

Navigate to **Actions → ADF Deployment → Run workflow**

**Inputs:**
- Environment: `dev`

Click **Run workflow**

**Expected Duration:** 3-5 minutes

#### Step 6: Test Pipeline in Dev

```powershell
# Manually trigger pipeline with test file
az datafactory pipeline create-run \
  --factory-name adf-edi-dev-eastus2 \
  --resource-group rg-edi-dev-eastus2 \
  --name PL_Inbound_SFTP_to_Storage \
  --parameters @test-parameters.json

# Monitor pipeline run
az datafactory pipeline-run show \
  --factory-name adf-edi-dev-eastus2 \
  --resource-group rg-edi-dev-eastus2 \
  --run-id <RUN_ID>
```

**Expected Result:** Pipeline completes successfully

#### Step 7: Deploy to Test and Production

Follow same manual workflow trigger for test and prod environments

**Important:** Disable production triggers before deployment, re-enable after validation

```powershell
# Disable triggers before deployment
az datafactory trigger stop \
  --factory-name adf-edi-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2 \
  --name TR_Inbound_Schedule

# Re-enable after validation
az datafactory trigger start \
  --factory-name adf-edi-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2 \
  --name TR_Inbound_Schedule
```

---

## 5. Configuration Deployment

### 5.1 Partner Configuration Deployment

#### Step 1: Validate Configuration Files

```powershell
# Run JSON schema validation
pwsh scripts/validate-partner-configs.ps1
```

**Expected Result:** All configurations pass validation

#### Step 2: Merge PR

```powershell
# Merge PR (triggers config deployment)
gh pr merge <PR_NUMBER> --squash --repo PointCHealth/edi-partner-configs
```

#### Step 3: Upload to Blob Storage

**Automatic:** `config-cd.yml` workflow uploads configs to blob storage

**Versioning Strategy:** Configs uploaded with timestamp suffix

```
config-v2024-10-06-123456/
  ├── partner-001.json
  ├── partner-002.json
  └── routing-rules.json
```

#### Step 4: Update Function App Settings

```powershell
# Update app setting to point to new config version
az functionapp config appsettings set \
  --name func-edi-router-dev-eastus2 \
  --resource-group rg-edi-dev-eastus2 \
  --settings "ConfigVersion=v2024-10-06-123456"
```

**Expected Result:** Function apps reload configuration within 5 minutes

#### Step 5: Validate Configuration

```powershell
# Test configuration endpoint
curl https://func-edi-router-dev-eastus2.azurewebsites.net/api/config/validate
```

**Expected Result:** Configuration validation passes

---

## 6. Post-Deployment Validation

### 6.1 Infrastructure Validation

#### Check Resource Provisioning State

```powershell
# Check all resources in resource group
az resource list \
  --resource-group rg-edi-prod-eastus2 \
  --query "[].{Name:name, Type:type, State:provisioningState}" \
  --output table
```

**Expected Result:** All resources show `Succeeded`

#### Verify Networking

```powershell
# Test connectivity to storage account
az storage account show-connection-string \
  --name stediproedeastus2 \
  --resource-group rg-edi-prod-eastus2

# Test Service Bus connectivity
az servicebus namespace show \
  --name sb-edi-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2 \
  --query "provisioningState"
```

### 6.2 Function App Validation

#### Health Endpoint Tests

```powershell
# Test all function apps
$functionApps = @(
    "func-edi-router-prod-eastus2",
    "func-edi-validator-prod-eastus2",
    "func-edi-orchestrator-prod-eastus2"
)

foreach ($app in $functionApps) {
    $url = "https://$app.azurewebsites.net/api/health"
    Write-Host "Testing $app..." -ForegroundColor Cyan
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ $app healthy" -ForegroundColor Green
    } else {
        Write-Host "❌ $app failed" -ForegroundColor Red
    }
}
```

#### Application Insights Check

```powershell
# Check for exceptions in last 10 minutes
az monitor app-insights query \
  --app func-edi-router-prod-eastus2 \
  --analytics-query "exceptions | where timestamp > ago(10m) | summarize count()" \
  --resource-group rg-edi-prod-eastus2
```

**Expected Result:** 0 exceptions

### 6.3 ADF Pipeline Validation

#### Run Test Pipeline

```powershell
# Trigger test pipeline run
$runId = az datafactory pipeline create-run \
  --factory-name adf-edi-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2 \
  --name PL_Test_End_to_End \
  --query runId \
  --output tsv

# Wait and check status
Start-Sleep -Seconds 60
az datafactory pipeline-run show \
  --factory-name adf-edi-prod-eastus2 \
  --resource-group rg-edi-prod-eastus2 \
  --run-id $runId \
  --query status
```

**Expected Result:** `"Succeeded"`

### 6.4 End-to-End Smoke Test

```powershell
# Run comprehensive smoke test script
pwsh scripts/smoke-tests.ps1 -Environment prod -ResourceGroup rg-edi-prod-eastus2
```

**Tests Performed:**
- ✅ Storage account read/write
- ✅ Service Bus send/receive
- ✅ Key Vault secret retrieval
- ✅ Function app health endpoints
- ✅ ADF pipeline trigger
- ✅ Application Insights logging

---

## 7. Production Deployment

### 7.1 Production Deployment Checklist

#### Pre-Deployment (T-48 hours)

- [ ] Create change ticket with all details
- [ ] Send deployment notification to stakeholders
- [ ] Schedule deployment window (off-hours preferred)
- [ ] Verify on-call engineer availability
- [ ] Review rollback plan

#### Pre-Deployment (T-2 hours)

- [ ] Verify test environment deployment successful
- [ ] Review monitoring dashboards for current baseline
- [ ] Backup current configuration
- [ ] Verify approvers are available
- [ ] Send "deployment starting" notification

#### During Deployment (T-0)

- [ ] Execute deployment workflow
- [ ] Monitor Azure Portal for resource status
- [ ] Monitor GitHub Actions for workflow status
- [ ] Monitor Application Insights for errors
- [ ] Execute post-deployment validation

#### Post-Deployment (T+10 minutes)

- [ ] All smoke tests passed
- [ ] No errors in Application Insights
- [ ] Health endpoints returning 200 OK
- [ ] Synthetic transaction tests passed
- [ ] Send "deployment complete" notification

#### Post-Deployment (T+30 minutes)

- [ ] Monitor error rates (should match baseline)
- [ ] Monitor performance metrics (latency, throughput)
- [ ] Review cost metrics (no unexpected spikes)
- [ ] Close change ticket with deployment summary

### 7.2 Production Deployment Communication Template

**Email Subject:** [EDI Platform] Production Deployment - [Date] [Time]

**Body:**

```
Hi Team,

This email confirms a production deployment for the EDI Platform.

**Deployment Window:** October 6, 2025, 10:00 PM - 11:00 PM ET
**Expected Downtime:** None (zero-downtime deployment)
**Changes:**
- [Component 1]: [Brief description]
- [Component 2]: [Brief description]

**Testing Completed:**
- ✅ Dev environment: Passed
- ✅ Test environment: Passed
- ✅ Integration tests: Passed
- ✅ Security scans: Passed

**Rollback Plan:**
- Revert to previous deployment via GitHub Actions workflow
- Estimated rollback time: 15 minutes

**Contacts:**
- Primary: [Name] ([Email])
- On-Call: [Name] ([Phone])

**Monitoring:**
- Dashboard: [Link to Azure Monitor dashboard]
- Status Page: [Link to status page]

Thank you,
EDI Platform Team
```

### 7.3 Deployment Windows

**Preferred Windows:**
- **Standard Release:** Thursday 10 PM - 12 AM ET
- **Hotfix:** Any time (with incident ticket)
- **Major Release:** Saturday 2 AM - 8 AM ET

**Blackout Periods:**
- End of month (financial close)
- Major holidays
- Peak business hours (8 AM - 6 PM ET)

---

## Next Steps

**For New Deployments:**
1. Follow pre-deployment checklist
2. Execute deployment per component type
3. Run post-deployment validation
4. Monitor for 24 hours

**For Issues:**
1. See [06-rollback-procedures.md](./06-rollback-procedures.md)
2. Contact on-call engineer
3. Create incident ticket

**For Questions:**
- Review [07-troubleshooting-guide.md](./07-troubleshooting-guide.md)
- Contact @platform-team on Teams

---

**Document Maintenance:**
- Update after major process changes
- Review quarterly for accuracy
- Capture lessons learned from deployments
