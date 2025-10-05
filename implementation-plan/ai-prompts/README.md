# GitHub Setup & Implementation Guide for EDI Platform

This guide outlines all tasks needed to get the EDI Platform implementation going in GitHub. Tasks are marked as either **[HUMAN REQUIRED]** or **[AI AUTOMATED]** with links to prompt files.

**Timeline:** 18-week AI-accelerated implementation (vs. 28 weeks traditional approach)

---

## Phase 1: Repository & Access Setup (Week 1)

### 1.1 Create GitHub Organization **[HUMAN REQUIRED]**

**Why Human:** Requires GitHub organization owner permissions and strategic decisions.

**Actions:**
1. Navigate to GitHub → New Organization (if needed)
2. Organization name: `PointCHealth`
3. Plan: GitHub Enterprise (for Copilot Enterprise)
4. Configure organization settings

**Prerequisites:**
- GitHub account with organization creation permissions
- Budget approval for GitHub Enterprise

---

### 1.2 Create Strategic Repositories & Initialize Structure **[AI AUTOMATED]**

**Prompt:** [01-create-strategic-repositories.md](01-create-strategic-repositories.md)

**What it does:**
- Creates five strategic repositories in GitHub
- Initializes directory structure in each repository
- Creates initial `.gitignore` files
- Sets up multi-root workspace configuration
- Establishes cross-repository references

**Repositories Created:**
1. `edi-platform-core` - Infrastructure, shared libraries, core functions
2. `edi-mappers` - All EDI transaction mappers
3. `edi-connectors` - Trading partner connectors
4. `edi-partner-configs` - Partner metadata and configurations
5. `edi-data-platform` - ADF pipelines and SQL databases

---

### 1.3 Configure Branch Protection Rules **[HUMAN REQUIRED]**

**Why Human:** Requires GitHub repository admin permissions.

**Actions:**
1. Navigate to: **Settings → Branches → Add rule**
2. Branch name pattern: `main`
3. Configure:
   - ✅ Require pull request before merging
   - ✅ Require approvals: 2
   - ✅ Dismiss stale PR approvals when new commits are pushed
   - ✅ Require review from Code Owners
   - ✅ Require status checks to pass: `bicep-build`, `security-scan`, `whatif-dev`
   - ✅ Require conversation resolution before merging
   - ✅ Require signed commits (recommended)
   - ✅ Do not allow bypassing the above settings
   - ✅ Restrict who can push to matching branches (add platform-team)

**Prerequisites:**
- Repository admin role
- Code Owners defined

---

### 1.4 Create CODEOWNERS Files **[AI AUTOMATED]**

**Prompt:** [02-create-codeowners.md](02-create-codeowners.md)

**What it does:**
- Creates `.github/CODEOWNERS` file in each repository
- Assigns ownership based on team structure (DevOps/Platform Engineering model)
- Maps directories to appropriate team members
- Ensures cross-functional review requirements

**Note:** Update team member GitHub handles after creation. With a unified DevOps/Platform Engineering team, all engineers share ownership responsibilities.

---

### 1.5 Enable Security Features **[HUMAN REQUIRED]**

**Why Human:** Requires repository admin permissions in GitHub UI.

**Actions:**
1. Navigate to: **Settings → Code security and analysis**
2. Enable:
   - ✅ Dependabot alerts
   - ✅ Dependabot security updates
   - ✅ Dependabot version updates (create `.github/dependabot.yml`)
   - ✅ Secret scanning
   - ✅ Push protection for secrets
   - ✅ Code scanning (CodeQL) - select languages: C#, JavaScript
3. Click "Enable" for each feature

**Prerequisites:**
- GitHub Advanced Security enabled (for private repos)
- Repository admin role

---

## Phase 2: Azure Authentication Setup (Week 1-2)

### 2.1 Create Azure AD App Registrations **[HUMAN REQUIRED]**

**Why Human:** Requires Azure AD admin permissions and manual Azure portal configuration.

**Actions for EACH environment (dev, test, prod):**

```powershell
# Run in Azure Cloud Shell or local terminal with Azure CLI

# 1. Create App Registration
$env = "dev"  # Change to "test" or "prod" for each environment
$app = az ad app create --display-name "github-actions-edi-$env" --query appId -o tsv
echo "App ID: $app"

# 2. Create Service Principal
az ad sp create --id $app

# 3. Get your GitHub org and repo names (for each of the five repositories)
$githubOrg = "PointCHealth"
$githubRepo = "edi-platform-core"  # Repeat for each repo: edi-mappers, edi-connectors, edi-partner-configs, edi-data-platform

# 4. Create Federated Credential
az ad app federated-credential create --id $app --parameters "{
  \"name\": \"github-$env\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:$githubOrg/$githubRepo:environment:$env\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}"

# 5. Assign Contributor role to Resource Group
$subscriptionId = az account show --query id -o tsv
$rgName = "rg-edi-$env-eastus2"

az role assignment create \
  --assignee $app \
  --role "Contributor" \
  --scope "/subscriptions/$subscriptionId/resourceGroups/$rgName"

# 6. Save these values for GitHub secrets:
echo "AZURE_CLIENT_ID_$($env.ToUpper()): $app"
echo "AZURE_TENANT_ID: 76888a14-162d-4764-8e6f-c5a34addbd87"
echo "AZURE_SUBSCRIPTION_ID_DEV: 0f02cf19-be55-4aab-983b-951e84910121"
echo "AZURE_SUBSCRIPTION_ID_PROD: 85aa9a59-7b1c-49d2-84ba-0640040bc097"
```

**Prerequisites:**
- Azure subscription owner or admin role
- Resource groups already created (`rg-edi-dev-eastus2`, `rg-edi-test-eastus2`, `rg-edi-prod-eastus2`)
- Azure CLI installed and authenticated

**Repeat for:** dev, test, and prod environments

---

### 2.2 Configure Azure Resource Groups **[HUMAN REQUIRED]**

**Why Human:** Requires Azure subscription permissions.

**Actions:**

```powershell
# Run in Azure Cloud Shell or local terminal

$location = "eastus2"
$tags = @{
  "Environment"="dev";
  "Project"="EDI-Platform";
  "ManagedBy"="Terraform";
  "CostCenter"="Healthcare-IT"
}

# Create resource groups for each environment
az group create --name "rg-edi-dev-eastus2" --location $location --tags $tags
az group create --name "rg-edi-test-eastus2" --location $location --tags $tags
az group create --name "rg-edi-prod-eastus2" --location $location --tags $tags
```

**Prerequisites:**
- Azure subscription contributor role
- Approved Azure naming conventions
- Budget and cost allocation approved

---

## Phase 3: GitHub Secrets & Variables (Week 2)

### 3.1 Add GitHub Repository Secrets **[HUMAN REQUIRED]**

**Why Human:** Requires repository admin permissions and secure credential management.

**Actions:**

**Option A: Via GitHub UI**
1. Navigate to: **Settings → Secrets and variables → Actions → New repository secret**
2. Add these secrets:

| Secret Name | Value | Source |
|------------|-------|--------|
| `AZURE_CLIENT_ID` | From step 2.1 output | App Registration |
| `AZURE_TENANT_ID` | `76888a14-162d-4764-8e6f-c5a34addbd87` | Azure AD |
| `AZURE_SUBSCRIPTION_ID_DEV` | `0f02cf19-be55-4aab-983b-951e84910121` | EDI-DEV Subscription |
| `AZURE_SUBSCRIPTION_ID_PROD` | `85aa9a59-7b1c-49d2-84ba-0640040bc097` | EDI-PROD Subscription |

**Option B: Via GitHub CLI**

```powershell
# Install GitHub CLI if needed: winget install GitHub.cli

gh auth login

# Add secrets (replace client-id with your actual value from step 2.1)
gh secret set AZURE_CLIENT_ID --body "your-client-id-from-step-2.1"
gh secret set AZURE_TENANT_ID --body "76888a14-162d-4764-8e6f-c5a34addbd87"
gh secret set AZURE_SUBSCRIPTION_ID_DEV --body "0f02cf19-be55-4aab-983b-951e84910121"
gh secret set AZURE_SUBSCRIPTION_ID_PROD --body "85aa9a59-7b1c-49d2-84ba-0640040bc097"
```

**Prerequisites:**
- Repository admin role
- GitHub CLI installed (for Option B)
- Values from step 2.1

---

### 3.2 Add GitHub Repository Variables **[AI AUTOMATED]**

**Prompt:** [03-configure-github-variables.md](03-configure-github-variables.md)

**What it does:**
- Creates script to add repository variables via GitHub CLI
- Configures environment-specific resource group names
- Sets Azure location and common configuration values

**Note:** Requires GitHub CLI authenticated and repository admin permissions to execute.

---

### 3.3 Create GitHub Environments **[HUMAN REQUIRED]**

**Why Human:** Requires repository admin permissions and approval workflow decisions.

**Actions:**

**For `dev` environment:**
1. Navigate to: **Settings → Environments → New environment**
2. Name: `dev`
3. Protection rules:
   - No required reviewers (auto-deploy on merge to main)
   - No wait timer
4. Environment secrets:
   - `TEAMS_WEBHOOK_URL` (optional, for notifications)

**For `test` environment:**
1. Navigate to: **Settings → Environments → New environment**
2. Name: `test`
3. Protection rules:
   - ✅ Required reviewers: 1 person from data-engineering-team
   - Wait timer: 0 minutes
4. Environment secrets:
   - `TEAMS_WEBHOOK_URL` (optional)

**For `prod` environment:**
1. Navigate to: **Settings → Environments → New environment**
2. Name: `prod`
3. Protection rules:
   - ✅ Required reviewers: 2 people (security + platform-lead)
   - Wait timer: 5 minutes (cooling-off period)
   - ✅ Restrict deployments to protected branches only (`main`)
4. Environment secrets:
   - `TEAMS_WEBHOOK_URL` (required for production alerts)

**Prerequisites:**
- Repository admin role
- Approval team members identified

---

## Phase 4: GitHub Actions Workflows (Week 2-3)

### 4.1 Create Infrastructure CI/CD Workflows **[AI AUTOMATED]**

**Prompt:** [04-create-infrastructure-workflows.md](04-create-infrastructure-workflows.md)

**What it does:**
- Creates `infra-ci.yml` - Validates Bicep on PRs with what-if analysis
- Creates `infra-cd.yml` - Deploys infrastructure to dev/test/prod
- Includes drift detection and security scanning
- Configures OIDC authentication with Azure

---

### 4.2 Create Azure Function CI/CD Workflows **[AI AUTOMATED]**

**Prompt:** [05-create-function-workflows.md](05-create-function-workflows.md)

**What it does:**
- Creates `function-ci.yml` - Builds and tests Azure Functions
- Creates `function-cd.yml` - Deploys Functions to environments
- Includes unit testing and code coverage
- Configures deployment slots for zero-downtime

---

### 4.3 Create Monitoring & Drift Detection Workflows **[AI AUTOMATED]**

**Prompt:** [06-create-monitoring-workflows.md](06-create-monitoring-workflows.md)

**What it does:**
- Creates `drift-detection.yml` - Nightly infrastructure drift detection
- Creates `cost-alert.yml` - Daily cost monitoring
- Creates `security-scan.yml` - Weekly security audits
- Configures automated alerting

---

### 4.4 Create Dependabot Configuration **[AI AUTOMATED]**

**Prompt:** [07-create-dependabot-config.md](07-create-dependabot-config.md)

**What it does:**
- Creates `.github/dependabot.yml`
- Configures automated dependency updates for NuGet, npm, GitHub Actions
- Sets update schedules and reviewers

---

## Phase 5: Initial Infrastructure Deployment (Week 3)

### 5.1 Create Bicep Infrastructure Templates **[AI AUTOMATED]**

**Prompt:** [08-create-bicep-templates.md](08-create-bicep-templates.md)

**What it does:**
- Creates modular Bicep templates for all Azure resources
- Includes: Storage, Function Apps, Service Bus, ADF, Key Vault, SQL
- Follows best practices from architecture spec
- Creates parameter files for each environment

---

### 5.2 Create Azure Function Projects **[AI AUTOMATED]**

**Prompt:** [09-create-function-projects.md](09-create-function-projects.md)

**What it does:**
- Creates .NET isolated Azure Function projects
- Implements: InboundRouter, OutboundOrchestrator, X12Parser, MapperEngine
- Includes dependency injection, logging, and configuration
- Creates unit test projects

---

### 5.3 Deploy Initial Infrastructure **[HUMAN REQUIRED]**

**Why Human:** Requires validation and approval of first deployment.

**Actions:**

```powershell
# From local terminal in edi-platform-core repository

# 1. Create feature branch
git checkout -b feature/initial-infrastructure

# 2. Commit infrastructure templates (created by AI in step 5.1)
git add infra/
git commit -m "feat: Add initial Bicep infrastructure templates"

# 3. Push and create PR
git push origin feature/initial-infrastructure

# 4. Open PR in GitHub UI and review:
#    - Check "Files changed" tab
#    - Review what-if analysis in PR checks
#    - Verify security scan passes
#    - Request reviews from platform team

# 5. After approval, merge PR
#    - This triggers automatic deployment to dev environment
#    - Monitor workflow in Actions tab

# 6. Promote to test after dev validation
#    - Approve test deployment in Environments page
#    - Monitor test deployment

# 7. Promote to prod after test validation
#    - Approve prod deployment (requires 2 approvals + 5 min wait)
#    - Monitor production deployment
```

**Prerequisites:**
- All previous steps completed
- Bicep templates validated locally: `az bicep build --file main.bicep`
- PR reviewers assigned

---

## Phase 6: Development Environment Setup (Week 3)

### 6.1 Enable GitHub Copilot **[HUMAN REQUIRED]**

**Why Human:** Requires GitHub organization owner and billing access.

**Actions:**
1. Navigate to: **Organization Settings → Copilot → Policies**
2. Enable Copilot for organization
3. Assign seats to development team
4. Configure: Allow suggestions matching public code (based on policy)
5. Update billing

**Prerequisites:**
- Organization owner role
- Budget approval for Copilot licenses
- Copilot Enterprise if using Copilot Workspace

---

### 6.2 Create AI Prompt Library **[AI AUTOMATED]**

**Prompt:** [10-create-ai-prompt-library.md](10-create-ai-prompt-library.md)

**What it does:**
- Creates comprehensive prompt library in `/ai-prompts`
- Includes prompts for: partner onboarding, mapper creation, testing, troubleshooting
- Organizes prompts by domain and complexity
- Creates prompt usage guide

---

### 6.3 Create Development Environment Setup Script **[AI AUTOMATED]**

**Prompt:** [11-create-dev-setup-script.md](11-create-dev-setup-script.md)

**What it does:**
- Creates automated dev environment setup script
- Installs required tools: .NET SDK, Azure CLI, Functions Core Tools
- Configures local.settings.json for each function app
- Sets up pre-commit hooks

---

### 6.4 Create Shared Libraries **[AI AUTOMATED]**

**Prompt:** [12-create-shared-libraries.md](12-create-shared-libraries.md)

**What it does:**
- Creates shared library projects: EDI.Core, EDI.X12, EDI.Configuration
- Implements common utilities: logging, configuration, validation
- Creates NuGet packaging configuration
- Includes unit tests

---

## Phase 7: Partner Configuration & Testing (Week 4)

### 7.1 Create Partner Configuration Schema **[AI AUTOMATED]**

**Prompt:** [13-create-partner-config-schema.md](13-create-partner-config-schema.md)

**What it does:**
- Creates JSON schema for partner configuration
- Implements validation logic
- Creates sample configurations for test partners
- Generates documentation

---

### 7.2 Create Integration Test Suite **[AI AUTOMATED]**

**Prompt:** [14-create-integration-tests.md](14-create-integration-tests.md)

**What it does:**
- Creates end-to-end integration tests
- Implements test harness for EDI transactions
- Creates mock data generators
- Configures test execution in pipelines

---

### 7.3 Create First Trading Partner Configuration **[HUMAN REQUIRED]**

**Why Human:** Requires real business data and partner coordination.

**Actions:**
1. Obtain partner-specific information:
   - ISA Qualifier & ID
   - GS Application Code
   - Connection credentials (SFTP/AS2)
   - Data mapping requirements
   - Test contact information

2. Use AI prompt to generate configuration:
   - **Prompt:** [15-onboard-trading-partner.md](15-onboard-trading-partner.md)
   - Provide partner details to AI
   - Review generated configuration
   - Test with partner test files

3. Deploy partner configuration:
   - Commit to feature branch
   - Create PR with partner name
   - Deploy to dev for testing
   - Coordinate testing with partner
   - Promote through test → prod

**Prerequisites:**
- Partner agreement signed
- Technical specifications received
- Test files from partner
- Security review completed

---

## Phase 8: Operations & Monitoring (Week 4-5)

### 8.1 Create Monitoring Dashboards **[AI AUTOMATED]**

**Prompt:** [16-create-monitoring-dashboards.md](16-create-monitoring-dashboards.md)

**What it does:**
- Creates Application Insights workbooks
- Implements KPI dashboards: transaction volume, errors, latency
- Creates alerting rules
- Generates runbook documentation

---

### 8.2 Configure Alert Rules **[HUMAN REQUIRED]**

**Why Human:** Requires operational decisions and on-call setup.

**Actions:**
1. Navigate to Azure Portal → Application Insights → Alerts
2. Create alert rules for:
   - Transaction failures > 5% in 5 minutes
   - Function execution duration > 30 seconds
   - Storage queue depth > 1000 messages
   - Service Bus dead-letter > 10 messages
   - Budget threshold > 80% of monthly limit

3. Configure action groups:
   - Email: platform-team@company.com
   - SMS: On-call phone (prod only)
   - Teams webhook: Platform channel
   - Azure mobile app push

**Prerequisites:**
- On-call rotation defined
- Escalation paths documented
- Teams webhook created

---

### 8.3 Create Operations Runbooks **[AI AUTOMATED]**

**Prompt:** [17-create-operations-runbooks.md](17-create-operations-runbooks.md)

**What it does:**
- Creates troubleshooting runbooks for common issues
- Documents incident response procedures
- Creates recovery scripts
- Generates on-call handbook

---

## Phase 9: Production Hardening (Week 5-6)

### 9.1 Security Audit & Penetration Testing **[HUMAN REQUIRED]**

**Why Human:** Requires security team expertise and compliance validation.

**Actions:**
1. Schedule security review with InfoSec team
2. Conduct HIPAA compliance audit checklist
3. Perform penetration testing (external vendor recommended)
4. Review audit logs and access patterns
5. Validate encryption at rest and in transit
6. Review Key Vault access policies
7. Validate network security groups and private endpoints
8. Document findings and remediation plan

**Prerequisites:**
- All infrastructure deployed to prod
- Security team engaged
- Compliance requirements documented

---

### 9.2 Performance Testing & Optimization **[AI AUTOMATED]**

**Prompt:** [18-create-performance-tests.md](18-create-performance-tests.md)

**What it does:**
- Creates load testing scripts using Azure Load Testing
- Simulates high-volume transaction scenarios
- Generates performance benchmarks
- Creates optimization recommendations

**Note:** Review results with platform team and adjust scaling policies.

---

### 9.3 Disaster Recovery Testing **[HUMAN REQUIRED]**

**Why Human:** Requires coordination and production impact assessment.

**Actions:**
1. Schedule DR test window (ideally off-hours)
2. Execute DR scenarios:
   - Simulate region failure → verify failover
   - Test backup restoration → validate data integrity
   - Simulate Service Bus failure → verify circuit breaker
   - Test Function App auto-scaling → validate performance
3. Document recovery times (RTO/RPO actual vs target)
4. Update DR plan based on findings
5. Conduct post-test review with stakeholders

**Prerequisites:**
- DR plan documented (see `30-disaster-recovery-plan.md`)
- Backup policies configured
- Failover procedures tested in test environment
- Stakeholder approval for test

---

## Success Criteria & Validation

### ✅ Week 1-2 Completion Checklist
- [ ] Five strategic repositories created with appropriate structures
- [ ] Branch protection rules configured
- [ ] Azure AD apps registered for all environments
- [ ] GitHub secrets and variables configured
- [ ] GitHub environments created with approval workflows
- [ ] Security features enabled (Dependabot, CodeQL, secret scanning)

### ✅ Week 3 Completion Checklist
- [ ] All GitHub Actions workflows deployed and tested
- [ ] Infrastructure deployed to dev environment
- [ ] First Azure Function deployed successfully
- [ ] CI/CD pipeline executing without errors
- [ ] Drift detection running nightly

### ✅ Week 4 Completion Checklist
- [ ] First trading partner configuration created
- [ ] Integration tests passing
- [ ] Monitoring dashboards deployed
- [ ] Alert rules configured and tested
- [ ] Operations runbooks documented

### ✅ Week 5-6 Completion Checklist
- [ ] Security audit completed with no critical findings
- [ ] Performance tests meet NFRs (>500 TPS, <5s latency)
- [ ] DR test successful (RTO <4hrs, RPO <15min)
- [ ] Production deployment approved
- [ ] Team trained on operations procedures

---

## Key Performance Indicators (Per Spec)

Track these throughout implementation:

| KPI | Target | Measurement |
|-----|--------|-------------|
| AI Code Acceptance Rate | >70% | GitHub Copilot analytics |
| Workflow Success Rate | >95% | GitHub Actions success % |
| Time-to-Partner-Onboard | <5 days | From request to production |
| Infrastructure Deployment Time | <30 min | GitHub Actions duration |
| Total Implementation Time | 18 weeks | vs 28 weeks traditional |

---

## Troubleshooting Common Issues

### GitHub Actions Authentication Failures
**Symptom:** `Error: OIDC token validation failed`
**Solution:** Verify federated credential subject matches: `repo:ORG/REPO:environment:ENV`

### Bicep Deployment Failures
**Symptom:** `Resource validation failed`
**Solution:** Run `az bicep build` locally, check parameter files match environment

### Function Deployment Timeouts
**Symptom:** `Deployment timed out after 30 minutes`
**Solution:** Check Function App scaling settings, verify network connectivity to SCM endpoint

### Drift Detection False Positives
**Symptom:** Daily drift alerts for tags
**Solution:** Update `.bicep` templates to match manual tag changes, or add to drift ignore list

---

## Getting Help

- **Architecture Questions:** Review `/docs/*.md` specification files
- **Implementation Details:** Review `/implementation-plan/*.md` guides
- **AI Prompt Issues:** Check prompt file comments for prerequisites
- **Azure Issues:** Contact platform-team or Azure support
- **GitHub Issues:** Contact DevOps team or GitHub support

---

## Quick Reference: Human vs AI Tasks

| Phase | Human Tasks | AI Tasks |
|-------|-------------|----------|
| **Repository Setup** | Create repo, configure branch protection, enable security features | Create structure, CODEOWNERS file |
| **Azure Auth** | Create AD apps, assign RBAC, create resource groups | Generate scripts, documentation |
| **GitHub Config** | Add secrets, create environments with approvals | Add variables, create config scripts |
| **Workflows** | Review and approve workflow designs | Create all workflow YAML files |
| **Infrastructure** | Approve deployments, validate in Azure portal | Create Bicep templates, deploy via workflows |
| **Development** | Enable Copilot, approve licenses | Create function code, shared libraries, tests |
| **Partner Config** | Gather partner data, coordinate testing | Generate configurations, mapping rules |
| **Operations** | Define on-call, configure alert recipients | Create dashboards, runbooks, monitoring |
| **Production** | Security audit, DR testing, stakeholder approval | Performance tests, optimization scripts |

---

## Next Steps After GitHub Setup

Once GitHub is fully configured (Phases 1-4 complete):

1. **Start AI-Driven Development:** Begin with [08-create-bicep-templates.md](08-create-bicep-templates.md)
2. **Follow Implementation Plan:** Reference `/implementation-plan/00-implementation-overview.md`
3. **Track Progress:** Use project board in GitHub Projects
4. **Weekly Reviews:** Assess KPIs and adjust approach

---

**Document Version:** 1.0  
**Last Updated:** October 4, 2025  
**Owner:** Platform Engineering Team  
**AI Framework:** GitHub Copilot + Custom Prompts
