# Step 05: Azure Function CI/CD Workflows - COMPLETE ✅

**Completion Date:** October 5, 2025  
**Status:** ✅ Complete  
**Repository:** edi-platform-core  
**Commit:** 3ac9f64

## Summary

Successfully created three comprehensive GitHub Actions workflows for Azure Functions CI/CD automation:

1. **Function CI** (`function-ci.yml`) - Build, test, and package validation
2. **Function CD** (`function-cd.yml`) - Multi-environment deployment pipeline
3. **Health Check** (`function-health-check.yml`) - Hourly monitoring and alerting

## Created Files

### 1. Azure Functions CI Workflow
**File:** `.github/workflows/function-ci.yml`  
**Lines:** 420+  
**Commit:** 3ac9f64

**Jobs:**
- **build**: Restore dependencies, build solution, cache NuGet packages
- **unit-test**: Run xUnit tests, generate coverage reports, enforce 70% threshold, post coverage to PR
- **static-analysis**: .NET analyzers, code formatting, Microsoft Security DevOps scanning
- **package**: Create deployment packages for all 7 functions (matrix strategy)
- **ci-summary**: Consolidated results with overall pass/fail status

**Triggers:**
- Pull requests modifying `functions/**`, `shared/**`, `tests/**`, `**.csproj`, `**.sln`
- Manual workflow dispatch

**Key Features:**
- NuGet package caching for faster builds
- Code coverage reporting with PR comments
- Security scanning with SARIF upload
- Parallel packaging using matrix strategy
- Graceful handling of non-existent functions (for gradual implementation)

### 2. Azure Functions CD Workflow
**File:** `.github/workflows/function-cd.yml`  
**Lines:** 620+  
**Commit:** 3ac9f64

**Jobs:**
- **build-and-package**: Build and create ZIP packages for all 7 functions
- **deploy-to-dev**: Auto-deploy to dev (7 functions in parallel)
- **deploy-to-test**: Deploy to test with staging slot, health checks, zero-downtime swap (requires 1 approval)
- **deploy-to-prod**: Production deployment with backup, staging, comprehensive testing, monitoring (requires 2 approvals + 5 min wait)
- **cd-summary**: Deployment pipeline status report

**Functions Supported (Matrix Strategy):**
1. InboundRouter
2. OutboundOrchestrator
3. X12Parser
4. MapperEngine
5. ControlNumberGenerator
6. FileArchiver
7. NotificationService

**Deployment Strategy:**
| Environment | Strategy | Approvals | Wait Time | Slot Swap | Health Checks |
|-------------|----------|-----------|-----------|-----------|---------------|
| Dev         | Direct   | 0         | 0         | No        | Basic smoke test |
| Test        | Staged   | 1         | 0         | Yes       | Extended validation |
| Production  | Staged   | 2         | 5 minutes | Yes       | Comprehensive + 5 min monitoring |

**Triggers:**
- Push to main branch modifying `functions/**` or `shared/**`
- Manual workflow dispatch with environment and function filters

**Key Features:**
- Zero-downtime deployments using staging slots (test/prod)
- Automatic Function App existence checks (skip if infrastructure not deployed)
- Production backups before deployment
- Extended warm-up periods (60s test, 120s prod)
- 5-minute post-deployment monitoring for production
- Version tagging with run number and timestamp
- 30-day artifact retention with production backups (90 days)

### 3. Function Health Check Workflow
**File:** `.github/workflows/function-health-check.yml`  
**Lines:** 427+  
**Commit:** 3ac9f64

**Jobs:**
- **health-check-dev**: Monitor all 7 dev functions
- **health-check-test**: Monitor all 7 test functions
- **health-check-prod**: Monitor all 7 production functions (elevated alerting)
- **create-health-issue**: Automatically create/update GitHub issues for production failures
- **health-summary**: Consolidated health status report

**Health Checks:**
- Function App existence verification
- App state monitoring (Running vs Stopped)
- Application Insights configuration check
- Health endpoint HTTP testing
- Failure detection and alerting

**Triggers:**
- Scheduled: Every hour (`0 * * * *`)
- Manual workflow dispatch with environment filter
- Callable workflow (can be triggered by CD workflow)

**Key Features:**
- Hourly automated health monitoring
- Critical alerts for production failures
- Automatic GitHub issue creation/updates
- Graceful handling of non-deployed infrastructure
- Matrix strategy for parallel health checks
- Production-specific elevated logging (::error:: vs ::warning::)

## Workflow Interaction

```
┌─────────────────────────────────────────────────────────────┐
│                    Function Development Flow                 │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
                    ┌──────────────────┐
                    │  Create PR with  │
                    │  function code   │
                    └──────────────────┘
                               │
                               ▼
                    ┌──────────────────┐
                    │  function-ci.yml │ ◄── Build, test, coverage, security
                    │ (PR Validation)  │     Package all functions
                    └──────────────────┘     Post coverage to PR
                               │
                               ▼
                    ┌──────────────────┐
                    │   Merge to main  │
                    └──────────────────┘
                               │
                               ▼
                    ┌──────────────────┐
                    │  function-cd.yml │ ◄── Dev (auto)
                    │   (Deployment)   │     Test (1 approval, slot swap)
                    └──────────────────┘     Prod (2 approvals, backup, monitor)
                               │
                               ▼
                    ┌──────────────────┐
                    │   Deployed and   │
                    │     Running      │
                    └──────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                  Continuous Health Monitoring                │
└─────────────────────────────────────────────────────────────┘
                               │
                      Every hour (cron)
                               │
                               ▼
                    ┌──────────────────┐
                    │ function-health- │ ◄── Check all 21 function apps
                    │   check.yml      │     (7 functions × 3 environments)
                    └──────────────────┘     Create issues if unhealthy
```

## Technical Details

### Matrix Strategy

All workflows use GitHub Actions matrix strategy for parallel execution across 7 functions:

```yaml
strategy:
  matrix:
    function:
      - name: InboundRouter
        app-name-dev: func-edi-inbound-dev-eastus2
        # ... test and prod variants
      - name: OutboundOrchestrator
        # ...
      # Total: 7 functions
```

**Benefits:**
- ✅ Parallel execution (7 functions deploy simultaneously)
- ✅ Individual job tracking per function
- ✅ Fail-fast or fail-safe configurable
- ✅ Clear visibility into which functions succeed/fail

### Zero-Downtime Deployment

Test and Production use Azure Function deployment slots:

1. **Deploy to Staging Slot**: New code goes to `staging` slot
2. **Warm Up**: Wait 60-120 seconds, call health endpoints
3. **Health Checks**: Verify staging slot is healthy
4. **Slot Swap**: Atomic swap of staging ↔ production
5. **Verify**: Confirm production slot is healthy after swap
6. **Monitor**: Watch for 5 minutes (production only)

**Rollback**: If swap fails, staging slot retains old production code for easy rollback

### Code Coverage Enforcement

CI workflow enforces minimum 70% code coverage:

```yaml
- Check coverage threshold: 70%
- Fail build if coverage < 70%
- Post coverage report to PR comments
- Upload detailed HTML coverage report as artifact
```

Coverage report example in PR:
```
## 📊 Code Coverage Report

Line coverage: 75.3%

Coverage: 75.3% | Threshold: 70% | Status: ✅ Pass

✅ Code coverage meets the required threshold.
```

### Graceful Degradation

All workflows handle non-existent infrastructure gracefully:

```bash
if az functionapp show --name $APP_NAME ... 2>/dev/null; then
  echo "exists=true"
  # Proceed with deployment
else
  echo "exists=false"
  # Skip deployment with informational notice
fi
```

**Benefit**: Workflows can be committed before Azure infrastructure exists. They'll skip deployment and report informational messages until Function Apps are created.

## Validation & Testing

### Expected Lint Warnings

Similar to infrastructure workflows, these have expected warnings about variables that will be configured:

- ✅ `vars.AZURE_LOCATION` - configured in Step 03
- ✅ `vars.DEV_RESOURCE_GROUP`, `vars.TEST_RESOURCE_GROUP`, `vars.PROD_RESOURCE_GROUP` - configured in Step 03
- ⏳ `secrets.AZURE_CLIENT_ID`, `secrets.AZURE_TENANT_ID`, `secrets.AZURE_SUBSCRIPTION_ID` - to be configured manually

### Pre-requisites for Execution

**Before workflows can run successfully:**

1. **Function Code**: Implement actual Azure Function projects in `functions/` directory
   - Will be created in Phase 4 (Step 09: Create Function Projects)
   - Workflows currently create placeholder packages

2. **Azure Infrastructure**: Deploy Function Apps to Azure
   - Will be deployed in Phase 3 (Step 08: Create Bicep Templates)
   - Workflows skip deployment if apps don't exist yet

3. **GitHub Secrets** (same as infrastructure workflows):
   - `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

4. **GitHub Environments** (same as infrastructure workflows):
   - dev (no protection)
   - test (1 required reviewer)
   - prod (2 required reviewers + 5 minute wait)

## Usage Examples

### 1. Build and Test (CI)

**Scenario:** Developer creates PR with new X12Parser functionality

**Automatic Actions:**
1. Checkout code and restore dependencies
2. Build entire solution
3. Run all unit tests with coverage collection
4. Generate coverage report, fail if < 70%
5. Run .NET analyzers and code formatters
6. Security scan with Microsoft Security DevOps
7. Package all 7 functions (X12Parser has new code, others are current)
8. Post coverage results as PR comment
9. Upload test results and coverage artifacts

**Developer Experience:**
- See test results in PR checks
- Review code coverage directly in PR comment
- Check security findings in Security tab
- Download detailed coverage HTML report if needed

### 2. Deploy Functions (CD)

**Scenario A:** Merge to main (auto-deploys to dev)
```bash
git checkout main
git merge feature/x12-parser-enhancement
git push origin main
```
- ✅ Builds and packages all 7 functions
- ✅ Deploys all 7 to dev (parallel execution)
- ⏸️ Waits for approval to deploy to test
- ⏸️ Waits for approvals to deploy to prod

**Scenario B:** Manual deployment to specific environment
1. Go to Actions → Azure Functions CD
2. Click "Run workflow"
3. Select environment (dev/test/prod/all)
4. Optionally filter by function name
5. Click "Run workflow"
6. Approve when prompted

### 3. Monitor Health (Health Check)

**Automatic:** Runs every hour

**Manual Trigger:**
1. Go to Actions → Function Health Check
2. Click "Run workflow"
3. Select environment (all/dev/test/prod)
4. Click "Run workflow"

**When Production Failure Detected:**
1. ::error:: logged to workflow
2. GitHub issue created: "🚨 CRITICAL: Production Function App Health Check Failed"
3. Platform team tagged (@PointCHealth/platform-team)
4. Issue includes workflow run link and troubleshooting steps

**Resolution:**
1. Review workflow run to identify affected functions
2. Check Azure Portal and Application Insights
3. Review recent deployments
4. Rollback if necessary (swap slots back)
5. Fix issue and redeploy
6. Close GitHub issue

## Metrics & Reporting

### CI Workflow Output
```
## 📊 Azure Functions CI Summary

| Job             | Status     |
|-----------------|------------|
| Build           | ✅ Success |
| Unit Tests      | ✅ Success |
| Static Analysis | ✅ Success |
| Package         | ✅ Success |

✅ All checks passed!
This PR is ready for review and merge.
```

### CD Workflow Output
```
## 📊 Azure Functions CD Summary

| Environment | Status     | Version                |
|-------------|------------|------------------------|
| Dev         | ✅ Success | v42-20251005-143022    |
| Test        | ✅ Success | v42-20251005-143022    |
| Prod        | ✅ Success | v42-20251005-143022    |

Functions Deployed: 7 (InboundRouter, OutboundOrchestrator, ...)
```

### Health Check Output
```
## 📊 Function Health Check Summary

| Environment | Status      |
|-------------|-------------|
| Dev         | ✅ Healthy  |
| Test        | ✅ Healthy  |
| Production  | ✅ Healthy  |

Check Time: 2025-10-05T14:00:00Z
Functions Monitored: 7 per environment
```

## Architecture Decisions

### 1. .NET 8.0 LTS
**Decision:** Use .NET 8.0 (not .NET 9)  
**Rationale:**
- ✅ Long-term support (LTS) until November 2026
- ✅ Production-ready and stable
- ✅ Fully supported by Azure Functions v4
- ✅ Better for enterprise healthcare workloads

### 2. Isolated Worker Process
**Decision:** Use .NET Isolated worker process model  
**Rationale:**
- ✅ Better isolation from Azure Functions runtime
- ✅ Support for any .NET version
- ✅ Dependency injection improvements
- ✅ Easier testing and local development

### 3. 70% Code Coverage Threshold
**Decision:** Enforce minimum 70% code coverage  
**Rationale:**
- ✅ Industry standard for enterprise applications
- ✅ Healthcare compliance requires adequate testing
- ✅ Catches most critical path errors
- ✅ Balances quality vs development speed

### 4. Deployment Slots for Test and Prod Only
**Decision:** No slots for dev, use slots for test and prod  
**Rationale:**
- ✅ Dev is for rapid iteration (direct deployment faster)
- ✅ Test and prod need zero-downtime (slots required)
- ✅ Cost savings (slots have resource costs)
- ✅ Faster dev feedback loop

### 5. Matrix Strategy for All Functions
**Decision:** Deploy all 7 functions in parallel using matrix  
**Rationale:**
- ✅ Faster total deployment time (parallel vs sequential)
- ✅ Clear per-function status visibility
- ✅ Functions are independent (can deploy separately)
- ✅ Easy to add/remove functions from matrix

### 6. Hourly Health Checks
**Decision:** Check health every hour (not more frequently)  
**Rationale:**
- ✅ Adequate for detecting issues promptly
- ✅ Doesn't consume excessive GitHub Actions minutes
- ✅ Reduces noise (less frequent alerts)
- ✅ Can manually trigger if needed immediately

## Known Limitations & Future Enhancements

### Current Limitations

1. **Function Code Doesn't Exist Yet**
   - ✅ Workflows are ready
   - ⏳ Actual function code will be created in Phase 4 (Step 09)
   - Workflows create placeholder packages until then

2. **Infrastructure Not Deployed**
   - ✅ Workflows check for Function App existence
   - ⏳ Azure infrastructure will be deployed in Phase 3 (Step 08)
   - Deployments skip gracefully if apps don't exist

3. **Integration Tests Commented Out**
   - Integration test job is present but commented out
   - Will be enabled once test infrastructure is ready
   - Requires Docker Compose for test containers

### Future Enhancements

- [ ] Add smoke test endpoints to each function
- [ ] Integrate with Azure Load Testing for stress tests
- [ ] Add canary deployment option (deploy to subset of users)
- [ ] Implement automatic rollback on error rate threshold
- [ ] Add performance regression detection
- [ ] Integrate with PagerDuty/Opsgenie for critical alerts
- [ ] Add deployment notifications to Teams/Slack
- [ ] Implement blue-green deployment as alternative to slots
- [ ] Add chaos engineering tests (simulate failures)

## Troubleshooting Guide

### Issue: "Code coverage is below threshold"
**Solution:**
1. Download coverage report artifact from workflow run
2. Open HTML report to see uncovered lines
3. Add tests for uncovered code paths
4. Rerun workflow or push new commit

### Issue: "Function App not found during deployment"
**Solution:**
- This is expected until Azure infrastructure is deployed
- Workflow will skip deployment with informational notice
- Deploy infrastructure using Step 08 (Bicep templates)
- Workflow will automatically succeed once apps exist

### Issue: "Slot swap failed in test/prod"
**Solution:**
1. Check that staging slot exists: `az functionapp deployment slot list`
2. Verify staging slot is warmed up (wait longer if needed)
3. Check Application Insights for errors in staging slot
4. Manually swap in Azure Portal if workflow swap fails

### Issue: "Health check creates duplicate issues"
**Solution:**
- Workflow checks for existing open issues before creating new one
- Manually close old issues if duplicates occur
- Workflow will append comments to existing issues

### Issue: "Unit tests pass locally but fail in CI"
**Solution:**
1. Ensure test projects target same .NET version as CI (8.0.x)
2. Check for environment-specific dependencies (paths, connection strings)
3. Run `dotnet clean` locally and rebuild
4. Review workflow logs for specific test failures

## Commit History

```bash
commit 3ac9f64
Author: GitHub Actions (via AI Assistant)
Date:   Sat Oct 5 2025

    feat: Add Azure Functions CI/CD workflows (CI, CD, Health Check)
    
    - function-ci.yml: Build, test, coverage (70% threshold), security, package
    - function-cd.yml: Multi-environment deployment with slot swaps
    - function-health-check.yml: Hourly monitoring with automatic alerting
    
    All workflows use OIDC authentication and matrix strategy for 7 functions
    Graceful handling of non-existent infrastructure
    
    Related: Step 05 - Function Workflows
```

## Next Steps

**Immediate:**
- ✅ Workflows created and committed
- ⏳ Same manual setup as infrastructure workflows (OIDC, secrets, environments)
- ⏳ Function code implementation (Step 09)
- ⏳ Azure infrastructure deployment (Step 08)

**Step 06: Monitoring Workflows**
- Cost monitoring and alerting
- Security scanning workflows
- Availability and SLA monitoring

**Step 07: Dependabot Configuration**
- Automated dependency updates
- Security vulnerability scanning
- NuGet package updates

**Phase 3: Infrastructure Implementation**
- Step 08: Create Bicep templates for all Azure resources
- Deploy infrastructure to dev/test/prod

**Phase 4: Application Development**
- Step 09: Implement 7 Azure Function projects
- Step 12: Create shared libraries
- Step 13: Partner configuration schema

## Success Criteria ✅

- [x] Function CI workflow created (420+ lines)
- [x] Function CD workflow created (620+ lines)
- [x] Health check workflow created (427+ lines)
- [x] Matrix strategy for 7 functions implemented
- [x] Zero-downtime deployment with slots (test/prod)
- [x] Code coverage enforcement (70% threshold)
- [x] Security scanning integrated
- [x] Hourly health monitoring configured
- [x] Automatic issue creation for production failures
- [x] Graceful handling of non-existent infrastructure
- [x] OIDC authentication configured
- [x] Progressive deployment pipeline (dev → test → prod)
- [x] Comprehensive error handling and logging
- [x] Workflows committed to edi-platform-core repository

**Total Lines of Workflow Code:** 1,467+ lines  
**Repository:** https://github.com/PointCHealth/edi-platform-core  
**Branch:** main  
**Commit:** 3ac9f64

---

**Step 05 Status:** ✅ COMPLETE  
**Ready for:** Step 06 (Monitoring Workflows)
