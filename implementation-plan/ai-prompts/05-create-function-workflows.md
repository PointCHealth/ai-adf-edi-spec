# AI Prompt: Create Azure Function CI/CD Workflows

## Objective
Create GitHub Actions workflows for building, testing, and deploying Azure Functions across environments.

## Prerequisites
- Azure Functions code exists (or will be generated)
- Azure infrastructure deployed (Function Apps exist)
- GitHub secrets configured for Azure authentication
- GitHub environments created with protection rules

## Prompt

```
I need you to create comprehensive GitHub Actions workflows for Azure Functions CI/CD pipeline.

Context:
- Platform: Azure Functions .NET 8 Isolated
- Functions: InboundRouter, OutboundOrchestrator, X12Parser, MapperEngine, ControlNumberGenerator, FileArchiver, NotificationService
- Build: .NET SDK 8.0
- Testing: xUnit with code coverage
- Deployment: Zero-downtime using deployment slots
- Environments: dev (auto), test (approval), prod (strict approval)

Please create these workflow files:

---

## 1. Azure Functions CI Workflow (.github/workflows/function-ci.yml)

Triggers:
- Pull requests modifying files in functions/**
- Pull requests modifying files in shared/**
- Manual workflow_dispatch

Jobs:

1. **build**:
   - Checkout code
   - Setup .NET SDK 8.0
   - Restore NuGet dependencies with caching
   - Build solution in Release configuration
   - Build all function projects

2. **unit-test**:
   - Depends on: build
   - Run xUnit tests
   - Generate code coverage report (using Coverlet)
   - Fail if coverage < 70%
   - Upload coverage report as artifact
   - Post coverage summary to PR comment

3. **static-analysis**:
   - Run .NET analyzers
   - Check code style compliance
   - Security scanning (Snyk or similar)
   - Dependency vulnerability check

4. **integration-test** (optional, comment this):
   - Run integration tests against test environment
   - Use test containers if possible
   - Validate EDI parsing logic
   - Test Service Bus integration

5. **package**:
   - Depends on: build, unit-test
   - Create deployment package for each function
   - Upload artifacts for CD workflow
   - Tag with version number

Requirements:
- Use matrix strategy for multiple function apps
- Cache NuGet packages and build outputs
- Run tests in parallel where possible
- Clear test result reporting
- Fail fast on critical errors

---

## 2. Azure Functions CD Workflow (.github/workflows/function-cd.yml)

Triggers:
- Push to main branch with changes in functions/** or shared/**
- Manual workflow_dispatch with environment and function selection

Jobs:

1. **build-and-package**:
   - Build function apps
   - Create ZIP deployment packages
   - Upload artifacts

2. **deploy-to-dev**:
   - Depends on: build-and-package
   - Download artifacts
   - Authenticate to Azure via OIDC
   - Deploy to dev Function Apps using 'az functionapp deployment'
   - Verify deployment health
   - Run smoke tests

3. **deploy-to-test**:
   - Depends on: deploy-to-dev success
   - Requires: 1 approval (GitHub environment protection)
   - Deploy to staging slot first
   - Run health checks on staging slot
   - Swap staging → production slot (zero downtime)
   - Verify production health
   - Rollback if health check fails

4. **deploy-to-prod**:
   - Depends on: deploy-to-test success
   - Requires: 2 approvals + 5 min wait
   - Create backup/snapshot
   - Deploy to staging slot
   - Run comprehensive smoke tests on staging
   - Manual approval for slot swap
   - Swap staging → production
   - Monitor for 5 minutes post-deployment
   - Send Teams notification

Deployment strategy for each function:
```yaml
strategy:
  matrix:
    function:
      - name: InboundRouter
        app-name-dev: func-edi-inbound-dev-eastus2
        app-name-test: func-edi-inbound-test-eastus2
        app-name-prod: func-edi-inbound-prod-eastus2
      - name: OutboundOrchestrator
        app-name-dev: func-edi-outbound-dev-eastus2
        # ... etc
```

Requirements:
- Use deployment slots for test and prod
- Health checks after each deployment
- Automated rollback on failure
- Tag releases with semantic versioning
- Store deployment history
- Log deployment metrics (duration, size, etc.)

---

## 3. Function Health Check Workflow (.github/workflows/function-health-check.yml)

Triggers:
- Scheduled: Every hour (cron: '0 * * * *')
- Manual workflow_dispatch
- Called by CD workflow after deployments

Jobs:

1. **health-check**:
   - For each function and environment:
     - Call health endpoint (/_/health or admin endpoint)
     - Verify 200 OK response
     - Check Application Insights for errors
     - Validate Service Bus connectivity
     - Check storage account access
   - If unhealthy:
     - Create GitHub issue
     - Send alert to Teams
     - Optionally trigger rollback

Requirements:
- Run for all environments
- Clear health status reporting
- Automated alerting on failure
- Track uptime metrics

---

For all workflows include:

Authentication:
```yaml
- name: Azure Login
  uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

Build steps:
```yaml
- name: Setup .NET
  uses: actions/setup-dotnet@v3
  with:
    dotnet-version: '8.0.x'
    
- name: Restore dependencies
  run: dotnet restore
  
- name: Build
  run: dotnet build --configuration Release --no-restore
  
- name: Test
  run: dotnet test --configuration Release --no-build --verbosity normal --collect:"XPlat Code Coverage"
```

Deployment steps:
```yaml
- name: Deploy to Azure Function
  uses: Azure/functions-action@v1
  with:
    app-name: ${{ matrix.function.app-name }}
    package: ${{ github.workspace }}/deploy/${{ matrix.function.name }}.zip
    slot-name: staging  # For test and prod
```

Best practices:
- Use specific action versions
- Cache dependencies (.nuget/packages)
- Parallel execution where possible
- Clear naming and documentation
- Comprehensive error messages
- Deployment notifications
- Version tagging
- Artifact retention policies

Also provide:
1. Instructions for local testing before pushing
2. How to manually trigger deployments
3. Rollback procedures
4. Common troubleshooting steps
5. Performance optimization tips
```

## Expected Outcome

After running this prompt, you should have:
- ✅ `.github/workflows/function-ci.yml` created
- ✅ `.github/workflows/function-cd.yml` created
- ✅ `.github/workflows/function-health-check.yml` created
- ✅ Build, test, and deployment logic implemented
- ✅ Matrix strategy for multiple functions
- ✅ Deployment slot support for zero-downtime

## Validation Steps

1. Commit workflows:
   ```powershell
   git add .github/workflows/function-*.yml
   git commit -m "feat: Add Azure Functions CI/CD workflows"
   git push origin main
   ```

2. Test CI with a function change:
   ```powershell
   git checkout -b test/function-ci
   # Make a small change to a function
   echo "// test" >> functions/InboundRouter.Function/InboundRouter.cs
   git add functions/
   git commit -m "test: Trigger function CI"
   git push origin test/function-ci
   # Create PR and verify CI runs
   ```

3. Verify build and test:
   - Check Actions tab
   - Verify all functions build successfully
   - Check unit test results
   - Review code coverage report

4. Test deployment (after merge):
   - Merge PR to trigger CD
   - Watch dev deployment
   - Approve test deployment
   - Verify in Azure Portal

## Troubleshooting

**Build Fails: Missing Dependencies**
- Check .csproj references
- Verify NuGet package versions
- Clear NuGet cache: `dotnet nuget locals all --clear`

**Test Failures**
- Review test logs in Actions tab
- Run locally: `dotnet test --logger "console;verbosity=detailed"`
- Check Application Settings in Function App

**Deployment Fails: ZIP Deploy Error**
- Verify Function App exists in Azure
- Check RBAC permissions (need Contributor or Website Contributor)
- Ensure Function App is running (not stopped)

**Slot Swap Fails**
- Verify staging slot exists
- Check slot has warmed up (wait 2-3 minutes)
- Verify Application Settings are slot-specific

## Next Steps

After successful completion:
- Proceed to [06-create-monitoring-workflows.md](06-create-monitoring-workflows.md)
- Create function code [09-create-function-projects.md](09-create-function-projects.md)
- Set up integration tests [14-create-integration-tests.md](14-create-integration-tests.md)
