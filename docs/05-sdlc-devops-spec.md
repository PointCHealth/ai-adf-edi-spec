# Healthcare EDI Ingestion – SDLC & CI/CD Practices

## 1. Purpose

Define standardized software delivery lifecycle (SDLC), branching, quality gates, and deployment automation processes for the EDI ingestion platform (IaC, Data Factory assets, Functions, configuration artifacts).

## 2. Source Control Structure

| Area | Repo / Path | Notes |
|------|-------------|-------|
| Infrastructure (Bicep) | `/infra/bicep` | Modules + main template |
| ADF Pipelines (exported) | `/adf` | JSON artifacts versioned |
| Function Code | `/src/functions/validation` | Custom validators |
| Config (partners) | `/config/partners` | JSON/Delta partner registry |
| Docs | `/docs` | Living architecture & runbooks |

## 3. Branching Model

| Branch | Purpose | Policies |
|--------|---------|----------|
| `main` | Production-ready state | Protected, PR only, blocked on checks |
| `develop` (optional) | Integration of features | Nightly test deploy |
| `feature/*` | Feature or fix branches | Short-lived, rebase/merge develop |
| `hotfix/*` | Urgent production fixes | Branch from main, fast-track |

## 4. Pull Request Requirements

- Minimum 2 reviewers (infra + data engineering) for IaC & pipeline logic.
- Required automated checks:
  - Bicep compile & linter
  - Security scan (PSRule / Checkov)
  - Unit tests (Functions)
  - `what-if` (dev) result posted as comment
  - Secret scan (pre-commit + CI)
- PR template sections: Summary, Risk, Rollback plan, Testing evidence.

## 5. Versioning & Releases

| Artifact | Version Scheme | Mechanism |
|----------|----------------|-----------|
| IaC templates | Semantic (MAJOR.MINOR.PATCH) | Git tag + release notes |
| ADF pipelines | Incremental commit hash reference | Export job serializes JSON |
| Function code | Semantic | CI builds package artifact |
| Partner config | Date-based incremental (YYYYMMDD.N) | Reviewed like code |

## 6. GitHub Actions Workflows

### 6.1 Infrastructure CI Workflow (`.github/workflows/infra-ci.yml`)

**Triggers:** `pull_request`, `workflow_dispatch`

**Jobs:**

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Azure CLI
        run: |
          curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
          az bicep install
      
      - name: Bicep Build
        run: |
          az bicep build --file infra/bicep/main.bicep
          az bicep lint infra/bicep/main.bicep
      
      - name: PSRule Security Scan
        uses: microsoft/ps-rule@v2
        with:
          modules: PSRule.Rules.Azure
          inputPath: infra/bicep/
      
      - name: Checkov IaC Scan
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: infra/bicep
          framework: bicep
          output_format: sarif
          soft_fail: false
      
      - name: Azure Login (OIDC)
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: What-If Deployment
        id: whatif
        run: |
          az deployment group what-if \
            --resource-group rg-edi-dev-eastus2 \
            --template-file infra/bicep/main.bicep \
            --parameters env/dev.parameters.json \
            --result-format FullResourcePayloads \
            > whatif-output.txt
      
      - name: Post What-If to PR
        uses: actions/github-script@v7
        if: github.event_name == 'pull_request'
        with:
          script: |
            const fs = require('fs');
            const output = fs.readFileSync('whatif-output.txt', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `### 🔍 Infrastructure What-If Results\n\n<details><summary>Click to expand</summary>\n\n\`\`\`\n${output}\n\`\`\`\n</details>`
            });
      
      - name: Upload Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: bicep-compiled
          path: |
            infra/bicep/*.json
            env/*.parameters.json
          retention-days: 30
```

### 6.2 Function App CI Workflow (`.github/workflows/function-ci.yml`)

**Triggers:** `pull_request` (paths: `src/functions/**`), `workflow_dispatch`

**Strategy:** Matrix build for multiple function apps

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        function: [router, outbound-orchestrator, validation]
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup .NET / Python
        uses: actions/setup-dotnet@v3  # or actions/setup-python@v4
        with:
          dotnet-version: '8.x'  # or python-version: '3.11'
      
      - name: Restore Dependencies
        working-directory: src/functions/${{ matrix.function }}
        run: dotnet restore  # or pip install -r requirements.txt
      
      - name: Run Unit Tests
        working-directory: src/functions/${{ matrix.function }}
        run: |
          dotnet test --collect:"XPlat Code Coverage" --logger trx
      
      - name: Code Coverage Check
        uses: codecov/codecov-action@v3
        with:
          files: coverage.xml
          fail_ci_if_error: true
          flags: ${{ matrix.function }}
      
      - name: Static Analysis
        run: |
          dotnet format --verify-no-changes
          # or: bandit -r . -f json -o bandit-report.json
      
      - name: Build Package
        working-directory: src/functions/${{ matrix.function }}
        run: |
          dotnet publish -c Release -o publish
          cd publish && zip -r ../function-${{ matrix.function }}.zip .
      
      - name: Upload Function Package
        uses: actions/upload-artifact@v4
        with:
          name: function-${{ matrix.function }}
          path: src/functions/${{ matrix.function }}/function-${{ matrix.function }}.zip
          retention-days: 90
```

### 6.3 Data Factory Export Workflow (`.github/workflows/adf-export.yml`)

**Triggers:** `workflow_dispatch`, `schedule: '0 3 * * 1'` (weekly)

```yaml
jobs:
  export:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Export ADF Pipelines
        run: |
          az datafactory pipeline list \
            --factory-name adf-edi-dev-eastus2 \
            --resource-group rg-edi-dev-eastus2 \
            --query "[].name" -o tsv | \
          while read pipeline; do
            az datafactory pipeline show \
              --factory-name adf-edi-dev-eastus2 \
              --resource-group rg-edi-dev-eastus2 \
              --name "$pipeline" > "adf/pipelines/${pipeline}.json"
          done
      
      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v5
        with:
          commit-message: 'chore: sync ADF pipelines from dev environment'
          branch: adf-sync/${{ github.run_number }}
          title: 'Sync ADF Pipelines from Dev'
          body: |
            Automated export of Data Factory pipelines.
            
            Review changes and merge if expected.
          labels: adf-sync, automated
```

## 7. CD Pipelines

### Infrastructure Deployment Workflow (`.github/workflows/infra-cd.yml`)

```yaml
name: Infrastructure CD

on:
  push:
    branches: [main]
    paths: ['infra/**', 'env/**']
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [dev, test, prod]

jobs:
  deploy-dev:
    if: github.event_name == 'push' || inputs.environment == 'dev'
    runs-on: ubuntu-latest
    environment: dev
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/azure-login
        with:
          environment: dev
      - name: Deploy Infrastructure
        uses: azure/arm-deploy@v1
        with:
          scope: resourcegroup
          resourceGroupName: rg-edi-dev-eastus2
          template: infra/bicep/main.bicep
          parameters: env/dev.parameters.json
          deploymentName: deploy-${{ github.run_number }}
      - name: Run Smoke Tests
        run: pwsh scripts/smoke-tests.ps1 -Environment dev

  deploy-test:
    needs: deploy-dev
    if: success() && (github.event_name == 'push' || inputs.environment == 'test')
    runs-on: ubuntu-latest
    environment: test
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/bicep-whatif
        with:
          environment: test
      - uses: ./.github/actions/azure-login
        with:
          environment: test
      - name: Deploy Infrastructure
        uses: azure/arm-deploy@v1
        with:
          scope: resourcegroup
          resourceGroupName: rg-edi-test-eastus2
          template: infra/bicep/main.bicep
          parameters: env/test.parameters.json
          deploymentName: deploy-${{ github.run_number }}
      - name: Integration Tests
        run: pwsh scripts/integration-tests.ps1 -Environment test

  deploy-prod:
    needs: deploy-test
    if: success() && (github.event_name == 'workflow_dispatch' && inputs.environment == 'prod')
    runs-on: ubuntu-latest
    environment: prod
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - name: Validate Change Ticket
        run: |
          # Integration with change management system
          # Fail if no approved change ticket
      - uses: ./.github/actions/bicep-whatif
        with:
          environment: prod
      - uses: ./.github/actions/azure-login
        with:
          environment: prod
      - name: Deploy Infrastructure
        uses: azure/arm-deploy@v1
        with:
          scope: resourcegroup
          resourceGroupName: rg-edi-prod-eastus2
          template: infra/bicep/main.bicep
          parameters: env/prod.parameters.json
          deploymentName: deploy-${{ github.run_number }}
      - name: Post-Deploy Validation
        run: pwsh scripts/post-deploy-validation.ps1 -Environment prod
      - name: Create Release Annotation
        run: |
          az monitor log-analytics workspace query \
            --workspace law-edi-prod-eastus2 \
            --analytics-query "AzureActivity | where OperationName == 'Deployment' | project TimeGenerated"
      - name: Notify Stakeholders
        uses: azure/webapps-deploy@v2
        with:
          # Teams webhook notification
```

**Rollback Procedure:**
1. Identify last successful deployment tag
2. Trigger `workflow_dispatch` with rollback parameters
3. Redeploy previous artifact version

## 8. Testing Strategy

| Layer | Test Types | Tools |
|-------|-----------|-------|
| Unit (Functions) | Logic branches, validators | xUnit/pytest/jest |
| Integration | Event → pipeline → raw path verification | Test harness script + Azure SDK |
| Performance | Burst upload simulation | Locust / custom script |
| Security | Policy & RBAC enforcement tests | Azure CLI / PSRule |
| Chaos (optional) | Simulate transient failures | Scripted fault injection |

## 9. Quality Gates

| Gate | Threshold |
|------|----------|
| Unit test coverage | >=80% |
| Lint errors | 0 blocking |
| Critical security findings | 0 before merge |
| What-if unexpected changes | Must be adjudicated |
| Policy compliance | 100% required |

## 10. Configuration Management

- Partner config changes follow same PR + review path.
- Feature flags (Key Vault/App Config) updated via IaC when possible; runtime emergency toggles logged.
- Maintain changelog for partner onboarding.

## 11. Observability in SDLC

| Aspect | Implementation |
|--------|---------------|
| Pipeline metrics | GitHub Actions built-in + export to Log Analytics (optional) |
| Release annotations | Post-deploy script writes annotation to Log Analytics dashboard |
| Deployment hash | Stored as tag on root resource group and in metadata file |

## 12. Security Integration in CI/CD

- Dependency scanning (Dependabot / Renovate) scheduled weekly.
- Secret scanning pre-commit (detect-secrets) & CI.
- PR security checklist: endpoints, new roles, data exposure changes.

## 13. Release Management

| Activity | Description |
|----------|------------|
| Release Notes | Auto-generated from merged PR titles + manual summary |
| Change Ticket | Auto-linked to deployment pipeline run |
| Freeze Window | Optional (e.g., first business day of month) – prod deploys restricted |

## 14. Documentation Workflow

- Docs stored in `/docs`; updates required for architectural-impacting changes (definition of done includes doc update).
- ADR (Architecture Decision Record) format for significant decisions under `/docs/adr/ADR-<sequence>-<slug>.md`.

## 15. Onboarding & Offboarding

| Process | Steps |
|---------|-------|
| Developer Onboarding | Add to AAD group; clone repo; run bootstrap script; review security training |
| Access Revocation | Remove from AAD group; audit pending approvals |

## 16. Automation Scripts

- `scripts/validate_partner_config.py` – schema & reference checks
- `scripts/synthetic_ingest.ps1` – test file generator & upload
- `scripts/whatif_report.ps1` – summarize daily drift

## 17. Risk Controls in SDLC

| Risk | Control |
|------|--------|
| Unreviewed infra change | PR policy + mandatory what-if output |
| Over-permissive identity | Automated RBAC audit script in CI |
| Drift after hotfix | Post-hotfix reconciliation job compares templates |
| Silent pipeline failure | Alert on CI job failure to engineering channel |

## 18. KPI & Continuous Improvement

| KPI | Target | Action if Missed |
|-----|-------|-----------------|
| Lead time to prod | < 3 days | Value stream mapping |
| Change failure rate | < 5% | Post-mortem & action items |
| MTTR (ingestion pipeline) | < 60 min | Runbook refinement |
| Deployment frequency | Weekly (steady state) | Automate blockers |

## 19. Open Items

- Confirm if develop branch is desired or trunk-based
- Select test harness framework for ingestion integration
- Define ADR template

---
