# CI/CD Workflows Implementation Guide

**Document Version:** 1.0  
**Last Updated:** October 6, 2025  
**Status:** Production Ready  
**Owner:** EDI Platform Team (DevOps)

---

## Table of Contents

1. [Workflow Architecture](#1-workflow-architecture)
2. [Infrastructure Workflows](#2-infrastructure-workflows)
3. [Function App Workflows](#3-function-app-workflows)
4. [ADF Workflows](#4-adf-workflows)
5. [Operational Workflows](#5-operational-workflows)
6. [Reusable Components](#6-reusable-components)
7. [Best Practices](#7-best-practices)

---

## 1. Workflow Architecture

### 1.1 Workflow Categories

```mermaid
graph TB
    A[GitHub Workflows] --> B[CI Workflows]
    A --> C[CD Workflows]
    A --> D[Operational Workflows]
    
    B --> E[Infrastructure CI]
    B --> F[Function App CI]
    B --> G[Configuration CI]
    
    C --> H[Infrastructure CD]
    C --> I[Function App CD]
    C --> J[ADF CD]
    
    D --> K[Drift Detection]
    D --> L[Cost Monitoring]
    D --> M[Security Audit]
    D --> N[Health Checks]
```

### 1.2 Workflow Naming Convention

| Pattern | Example | Purpose |
|---------|---------|---------|
| `*-ci.yml` | `infra-ci.yml` | Continuous Integration (PR validation) |
| `*-cd.yml` | `infra-cd.yml` | Continuous Deployment (environment deployment) |
| `*-monitoring.yml` | `cost-monitoring.yml` | Scheduled operational tasks |
| `*-audit.yml` | `security-audit.yml` | Compliance and security checks |

### 1.3 Common Workflow Structure

All workflows follow this structure:

```yaml
name: Workflow Name

on:
  # Triggers (push, pull_request, schedule, workflow_dispatch)

permissions:
  # Minimal permissions required

env:
  # Global environment variables

jobs:
  job-name:
    name: Human-Readable Job Name
    runs-on: ubuntu-latest  # or windows-latest
    environment: dev  # if deploying
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Setup Tools
        # Install required tools
      
      - name: Execute Tasks
        # Main workflow logic
      
      - name: Upload Artifacts
        # Save outputs if needed
      
      - name: Job Summary
        # Post to $GITHUB_STEP_SUMMARY
```

---

## 2. Infrastructure Workflows

### 2.1 Infrastructure CI (`infra-ci.yml`)

**Purpose:** Validate Bicep templates on pull requests

**Triggers:**
- `pull_request` on paths: `infra/**`, `env/**`
- `workflow_dispatch` (manual)

**Jobs:**
1. **Bicep Build** - Compile Bicep to ARM JSON
2. **Bicep Lint** - Check for warnings/errors
3. **Security Scan** - PSRule + Checkov
4. **What-If Analysis** - Preview infrastructure changes
5. **PR Comment** - Post what-if results to PR

**Key Features:**
- Security scanning with SARIF upload
- What-if analysis against dev environment
- Automated PR comments with deployment preview
- Artifact retention for 14 days

**Sample Workflow:**

```yaml
name: Infrastructure CI

on:
  pull_request:
    branches: [main]
    paths:
      - 'infra/**'
      - 'env/**'
      - '.github/workflows/infra-ci.yml'
  workflow_dispatch:

permissions:
  id-token: write
  contents: read
  pull-requests: write
  security-events: write

jobs:
  validate:
    name: Validate IaC
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Setup Azure CLI
        run: |
          curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
          az bicep install
      
      - name: Bicep Build
        run: |
          az bicep build --file infra/bicep/main.bicep
          echo "✅ Bicep build successful" >> $GITHUB_STEP_SUMMARY
      
      - name: Bicep Lint
        run: |
          OUTPUT=$(az bicep lint infra/bicep/main.bicep 2>&1)
          echo "$OUTPUT"
          if echo "$OUTPUT" | grep -qi "warning\|error"; then
            echo "::error::Bicep lint found issues"
            exit 1
          fi
      
      - name: Security Scan (Checkov)
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: infra/bicep
          framework: bicep
          output_format: sarif
          output_file_path: checkov-results.sarif
      
      - name: Upload Security Scan Results
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: checkov-results.sarif
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID_DEV }}
      
      - name: What-If Analysis
        id: whatif
        run: |
          az deployment group what-if \
            --resource-group ${{ vars.DEV_RESOURCE_GROUP }} \
            --template-file infra/bicep/main.bicep \
            --parameters env/dev.parameters.json \
            > whatif-output.txt 2>&1 || true
          
          cat whatif-output.txt
      
      - name: Comment PR
        uses: actions/github-script@v7
        if: github.event_name == 'pull_request'
        with:
          script: |
            const fs = require('fs');
            const output = fs.readFileSync('whatif-output.txt', 'utf8');
            
            const body = \`### 📋 Infrastructure What-If Results
            
            <details>
            <summary>Click to view changes</summary>
            
            \\\`\\\`\\\`
            \${output.substring(0, 60000)}
            \\\`\\\`\\\`
            
            </details>
            \`;
            
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: body
            });
```

### 2.2 Infrastructure CD (`infra-cd.yml`)

**Purpose:** Deploy infrastructure to environments

**Triggers:**
- `push` to `main` (auto-deploy dev)
- `workflow_dispatch` with environment input

**Jobs:**
1. **deploy-dev** - Auto-deploy to dev on main merge
2. **deploy-test** - Manual trigger after dev validation (1 approver)
3. **deploy-prod** - Manual trigger after test validation (2 approvers)

**Key Features:**
- Environment-specific approval gates
- What-if analysis before production deployment
- Post-deployment smoke tests
- Resource tagging with deployment metadata
- Teams notifications for prod deployments

**Environment Flow:**

```mermaid
sequenceDiagram
    participant Main as Main Branch
    participant Dev as Dev Environment
    participant Test as Test Environment
    participant Prod as Prod Environment
    
    Main->>Dev: Auto-deploy on merge
    Dev->>Dev: Smoke tests
    Dev-->>Test: Manual trigger (1 approval)
    Test->>Test: Integration tests
    Test-->>Prod: Manual trigger (2 approvals + 5min wait)
    Prod->>Prod: Production smoke tests
    Prod->>Prod: Teams notification
```

---

## 3. Function App Workflows

### 3.1 Function App CI (`function-ci.yml`)

**Purpose:** Build and test Azure Functions on pull requests

**Triggers:**
- `pull_request` on paths: `src/**`, `*.csproj`
- `workflow_dispatch`

**Jobs:**
1. **Build** - Restore, build, test .NET projects
2. **Security Scan** - CodeQL + dependency scanning
3. **Unit Tests** - Run xUnit tests with coverage
4. **Package** - Create zip deployment package

**Sample Workflow:**

```yaml
name: Function App CI

on:
  pull_request:
    branches: [main]
    paths:
      - 'src/**'
      - '**/*.csproj'
      - '.github/workflows/function-ci.yml'

permissions:
  contents: read
  security-events: write
  pull-requests: write

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '8.0.x'
      
      - name: Restore Dependencies
        run: dotnet restore src/
      
      - name: Build
        run: dotnet build src/ --configuration Release --no-restore
      
      - name: Run Tests
        run: dotnet test src/ --no-build --verbosity normal --collect:"XPlat Code Coverage"
      
      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          directory: src/TestResults/
      
      - name: Publish
        run: dotnet publish src/FunctionApp/FunctionApp.csproj --configuration Release --output ./output
      
      - name: Create Deployment Package
        run: |
          cd output
          zip -r ../function-app.zip .
      
      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: function-app-pr-${{ github.event.pull_request.number }}
          path: function-app.zip
          retention-days: 7
```

### 3.2 Function App CD (`function-cd.yml`)

**Purpose:** Deploy function apps to environments

**Triggers:**
- `push` to `main` (build artifacts)
- `workflow_dispatch` with environment input

**Deployment Strategy:**
- **Dev:** Zip deploy directly to function app
- **Test:** Deploy to staging slot, then swap
- **Prod:** Blue-green deployment with health checks

**Sample Workflow:**

```yaml
name: Function App CD

on:
  push:
    branches: [main]
    paths:
      - 'src/**'
  workflow_dispatch:
    inputs:
      environment:
        required: true
        type: choice
        options: [dev, test, prod]

permissions:
  id-token: write
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '8.0.x'
      
      - name: Build and Publish
        run: |
          dotnet publish src/FunctionApp/FunctionApp.csproj \
            --configuration Release \
            --output ./output
      
      - name: Create Zip
        run: |
          cd output
          zip -r ../function-app.zip .
      
      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: function-app-${{ github.run_number }}
          path: function-app.zip
  
  deploy-dev:
    needs: build
    runs-on: ubuntu-latest
    environment: dev
    if: github.event_name == 'push' || inputs.environment == 'dev'
    
    steps:
      - name: Download Artifact
        uses: actions/download-artifact@v4
        with:
          name: function-app-${{ github.run_number }}
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID_DEV }}
      
      - name: Deploy to Azure Functions
        uses: Azure/functions-action@v1
        with:
          app-name: func-edi-router-dev-eastus2
          package: function-app.zip
      
      - name: Health Check
        run: |
          sleep 30
          curl -f https://func-edi-router-dev-eastus2.azurewebsites.net/api/health || exit 1
```

---

## 4. ADF Workflows

### 4.1 ADF Validation (`adf-ci.yml`)

**Purpose:** Validate ADF resources on pull requests

**Triggers:**
- `pull_request` on paths: `adf/**`

**Jobs:**
1. **Validate** - Run ADF validation build
2. **Lint** - Check JSON schema compliance

### 4.2 ADF Export (`adf-export.yml`)

**Purpose:** Export ADF ARM templates after publish

**Triggers:**
- `push` to `main` branch in ADF collaboration branch

**Jobs:**
1. **Export ARM** - Generate ARM templates from ADF UI
2. **Upload Artifact** - Save templates for deployment

### 4.3 ADF Deployment (`adf-cd.yml`)

**Purpose:** Deploy ADF pipelines to environments

**Triggers:**
- `workflow_dispatch` with environment input

**Jobs:**
1. **Deploy** - Apply ARM templates to target ADF
2. **Test Pipeline** - Run test trigger
3. **Enable Triggers** - Activate scheduled triggers

---

## 5. Operational Workflows

### 5.1 Drift Detection (`drift-detection.yml`)

**Purpose:** Nightly infrastructure drift detection

**Triggers:**
- `schedule: '0 2 * * *'` (2 AM UTC daily)
- `workflow_dispatch`

**Jobs:**
- Run what-if analysis against all environments
- Create GitHub issue if drift detected
- Tag issue with environment label

### 5.2 Cost Monitoring (`cost-monitoring.yml`)

**Purpose:** Daily cost tracking and budget alerts

**Triggers:**
- `schedule: '0 8 * * *'` (8 AM UTC daily)
- `workflow_dispatch`

**Jobs:**
1. **Fetch Costs** - Query Azure Cost Management API
2. **Analyze** - Calculate budget percentages
3. **Alert** - Create issue if over budget
4. **Report** - Post Teams summary

### 5.3 Security Audit (`security-audit.yml`)

**Purpose:** Weekly security scanning and compliance validation

**Triggers:**
- `schedule: '0 3 * * 1'` (Monday 3 AM UTC)
- `pull_request` (on-demand)

**Jobs:**
1. **IaC Security** - Checkov + PSRule
2. **Code Security** - CodeQL
3. **Dependencies** - Vulnerability scanning
4. **Compliance** - HIPAA requirement validation

### 5.4 Health Checks (`function-health-check.yml`)

**Purpose:** Proactive function app health monitoring

**Triggers:**
- `schedule: '*/15 * * * *'` (every 15 minutes)
- Callable from other workflows

**Jobs:**
- Test health endpoints for all function apps
- Create issue if production failures detected
- Post metrics to Application Insights

---

## 6. Reusable Components

### 6.1 Composite Actions

Create composite actions for common tasks:

**File:** `.github/actions/azure-login/action.yml`

```yaml
name: 'Azure Login'
description: 'Login to Azure using OIDC'

inputs:
  environment:
    description: 'Environment (dev/test/prod)'
    required: true

runs:
  using: 'composite'
  steps:
    - name: Azure Login
      uses: azure/login@v1
      with:
        client-id: ${{ env.AZURE_CLIENT_ID }}
        tenant-id: ${{ env.AZURE_TENANT_ID }}
        subscription-id: ${{ env.AZURE_SUBSCRIPTION_ID }}
```

### 6.2 Reusable Workflows

Create reusable workflows for shared logic:

**File:** `.github/workflows/reusable-deploy.yml`

```yaml
name: Reusable Deployment

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      artifact-name:
        required: true
        type: string

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    
    steps:
      - name: Download Artifact
        uses: actions/download-artifact@v4
        with:
          name: ${{ inputs.artifact-name }}
      
      - name: Deploy
        run: echo "Deploying to ${{ inputs.environment }}"
```

**Usage in caller workflow:**

```yaml
jobs:
  deploy-dev:
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: dev
      artifact-name: my-app
```

---

## 7. Best Practices

### 7.1 Workflow Design

- ✅ **Single Responsibility** - One workflow per purpose (CI vs CD)
- ✅ **Fail Fast** - Run quick checks first (lint before build)
- ✅ **Parallel Jobs** - Use matrix strategy for parallelization
- ✅ **Idempotent** - Workflows should be re-runnable
- ✅ **Minimal Permissions** - Grant only required permissions

### 7.2 Performance Optimization

- **Caching:** Cache dependencies (NuGet, Bicep modules)
- **Artifacts:** Only upload necessary files
- **Conditionals:** Skip jobs when files unchanged
- **Concurrency:** Prevent duplicate runs

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true  # Cancel previous runs
```

### 7.3 Security

- **Secret Management:** Use GitHub Secrets, never commit
- **OIDC Authentication:** Prefer OIDC over service principal secrets
- **Least Privilege:** Minimal permissions in `permissions:` block
- **Dependency Pinning:** Pin action versions to specific SHA

```yaml
- uses: actions/checkout@8e5e7e5ab8b370d6c329ec480221332ada57f0ab  # v4.1.1
```

### 7.4 Debugging

Enable debug logging:

```powershell
# Add repository secrets
gh secret set ACTIONS_RUNNER_DEBUG --body "true" --repo $repo
gh secret set ACTIONS_STEP_DEBUG --body "true" --repo $repo
```

Use workflow commands:

```yaml
- name: Debug
  run: |
    echo "::debug::This is a debug message"
    echo "::warning::This is a warning"
    echo "::error::This is an error"
```

### 7.5 Documentation

- **Workflow Comments:** Add comments to complex logic
- **Job Summaries:** Use `$GITHUB_STEP_SUMMARY` for reports
- **PR Comments:** Post results to pull requests
- **README:** Document workflow triggers and purpose

---

## Next Steps

1. **Implement Workflows** - Copy workflow templates to repositories
2. **Test Workflows** - Trigger each workflow manually
3. **Monitor Executions** - Review Actions tab for results
4. **Iterate** - Refine based on team feedback

**Related Documentation:**
- [02-github-actions-setup.md](./02-github-actions-setup.md) - Initial setup
- [04-deployment-procedures.md](./04-deployment-procedures.md) - Deployment execution
- [07-troubleshooting-guide.md](./07-troubleshooting-guide.md) - Common issues

---

**Document Maintenance:**
- Update after adding new workflows
- Review quarterly for action version updates
- Document lessons learned from incidents
