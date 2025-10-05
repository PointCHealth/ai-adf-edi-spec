# Repository Setup Guide - Strategic Multi-Repository Structure

**Document Version:** 1.0  
**Last Updated:** October 5, 2025  
**Status:** Active Implementation Guide  
**Owner:** DevOps and Platform Architecture Team

---

## Table of Contents

1. [Overview](#1-overview)
2. [GitHub Organization Setup](#2-github-organization-setup)
3. [Repository Creation](#3-repository-creation)
4. [Branch Protection Rules](#4-branch-protection-rules)
5. [CODEOWNERS Configuration](#5-codeowners-configuration)
6. [GitHub Actions Configuration](#6-github-actions-configuration)
7. [Azure Artifacts Setup](#7-azure-artifacts-setup)
8. [Access Control and Security](#8-access-control-and-security)
9. [Repository Setup Validation](#9-repository-setup-validation)
10. [Validation and Testing](#10-validation-and-testing)

---

## 1. Overview

### 1.1 Purpose

This document provides detailed instructions for setting up the GitHub repository infrastructure that supports the Healthcare EDI Platform using a strategic multi-repository structure from day one.

### 1.2 Repository Structure

**Five Strategic Repositories**:

- `edi-platform-core`: Infrastructure, shared libraries, router, scheduler
- `edi-mappers`: Transaction family mappers (eligibility, claims, enrollment, remittance)
- `edi-connectors`: Integration pattern connectors (SFTP, API, database)
- `edi-partner-configs`: Partner metadata and routing configurations
- `edi-data-platform`: ADF pipelines and SQL databases

### 1.3 Key Principles

- **Security First**: OIDC authentication, secrets in Key Vault, branch protection
- **Automation**: GitHub Actions for CI/CD, automated validation, policy checks
- **Compliance**: HIPAA audit trails, change ticket validation, deployment approval gates
- **AI-Optimized**: Multi-root workspaces, comprehensive documentation, cross-repo references

### 1.4 Dependencies

- [00-implementation-overview.md](./00-implementation-overview.md) - Overall strategic approach

---

## 2. GitHub Organization Setup

### 2.1 Organization Configuration

**Organization**: `PointCHealth`

**Settings to Configure**:

```yaml
Member Privileges:
  - Base permissions: Read
  - Repository creation: Admins only
  - Repository forking: Disabled (private repos)
  - Pages creation: Disabled

Member Actions:
  - Allow members to change repository visibilities: No
  - Allow members to delete or transfer repositories: No
  - Allow members to create teams: No

Security:
  - Two-factor authentication: Required for all members
  - SSO: Enabled (if applicable)
  - Verified domains: pointchealth.com

Actions Permissions:
  - Allow all actions and reusable workflows
  - Allow actions created by GitHub: Yes
  - Allow Marketplace verified creators: Yes
```

### 2.2 GitHub Teams

Create teams for clear ownership and access control:

| Team Name | Purpose | Members | Default Permission |
|-----------|---------|---------|-------------------|
| `edi-platform-admins` | Repository administration | Platform Architect, DevOps Lead | Admin |
| `edi-platform-core-team` | Core infrastructure development | Platform Engineers | Write |
| `edi-integration-team` | Mapper and connector development | Integration Engineers | Write |
| `edi-operations-team` | Monitoring, troubleshooting | Operations Engineers | Read |
| `edi-readonly` | Stakeholders, auditors | Various stakeholders | Read |

**Team Creation Script**:

```bash
# Create teams via GitHub CLI
gh api orgs/PointCHealth/teams -f name="edi-platform-admins" -f privacy="closed"
gh api orgs/PointCHealth/teams -f name="edi-platform-core-team" -f privacy="closed"
gh api orgs/PointCHealth/teams -f name="edi-integration-team" -f privacy="closed"
gh api orgs/PointCHealth/teams -f name="edi-operations-team" -f privacy="closed"
gh api orgs/PointCHealth/teams -f name="edi-readonly" -f privacy="closed"
```

---

## 3. Repository Creation

### 3.1 Strategic Repositories Setup (Week 1)

**Script**: `scripts/create-strategic-repos.sh`

```bash
#!/bin/bash
# Create five strategic repositories

REPOS=(
  "edi-platform-core:Core infrastructure and shared services"
  "edi-mappers:EDI transaction mappers"
  "edi-connectors:Trading partner connectors"
  "edi-partner-configs:Partner metadata and configurations"
  "edi-data-platform:ADF pipelines and SQL databases"
)

for repo_info in "${REPOS[@]}"; do
  IFS=':' read -r repo_name repo_desc <<< "$repo_info"
  
  echo "Creating repository: $repo_name"
  gh repo create PointCHealth/$repo_name \
    --private \
    --description "$repo_desc" \
    --gitignore VisualStudio
  
  # Clone and set up initial structure
  git clone https://github.com/PointCHealth/$repo_name.git
  cd $repo_name
  
  # Create base structure (customize per repo below)
  mkdir -p .github/workflows
  mkdir -p docs
  
  # Create README
  cat > README.md << EOF
# $repo_name

$repo_desc

## Overview
Part of the Healthcare EDI Platform strategic repository structure.

## Related Repositories
- [edi-platform-core](https://github.com/PointCHealth/edi-platform-core)
- [edi-mappers](https://github.com/PointCHealth/edi-mappers)
- [edi-connectors](https://github.com/PointCHealth/edi-connectors)
- [edi-partner-configs](https://github.com/PointCHealth/edi-partner-configs)
- [edi-data-platform](https://github.com/PointCHealth/edi-data-platform)

## Documentation
Architecture documentation is centralized in [edi-platform-core/docs](https://github.com/PointCHealth/edi-platform-core/tree/main/docs)
EOF
  
  git add .
  git commit -m "Initial repository structure"
  git push origin main
  
  cd ..
done

echo "All strategic repositories created successfully"
```

**Execute**:

```powershell
# From Git Bash or WSL
bash scripts/create-strategic-repos.sh
```

---

## 4. Branch Protection Rules

### 4.1 Standard Protection Rules (All Repositories)

Apply to `main` branch:

```yaml
Protect matching branches:
  - Require a pull request before merging: Yes
    - Require approvals: 2 (for edi-platform-core), 1 (for others)
    - Dismiss stale pull request approvals: Yes
    - Require review from Code Owners: Yes
  
  - Require status checks to pass before merging: Yes
    - Require branches to be up to date: Yes
    - Status checks required:
      - build-and-test
      - security-scan
      - policy-validation
  
  - Require conversation resolution before merging: Yes
  - Require signed commits: Yes (recommended)
  - Require linear history: Yes
  - Include administrators: No (for emergency hotfixes)
  - Allow force pushes: No
  - Allow deletions: No
```

**Automation Script**:

```bash
#!/bin/bash
# Apply branch protection rules to all repositories

bash scripts/setup-branch-protection.sh
```

See Section 4 in the full implementation guide for detailed branch protection configuration.

---

## 5. CODEOWNERS Configuration

### 5.1 Repository Ownership Matrix

| Repository | Primary Owners | Secondary Owners |
|------------|----------------|------------------|
| `edi-platform-core` | Platform Architect, Core Team | - |
| `edi-mappers` | Integration Team | Healthcare SME |
| `edi-connectors` | Integration Team | Database Engineer |
| `edi-partner-configs` | Integration Team, Healthcare SME | - |
| `edi-data-platform` | Core Team, Database Engineer | - |

### 5.2 Sample CODEOWNERS Files

See Section 5 in the full guide for complete CODEOWNERS templates for each repository.

---

## 6. GitHub Actions Configuration

### 6.1 Organization-Level Secrets

**Required Secrets**:

- `AZURE_CLIENT_ID` - Service principal for OIDC authentication
- `AZURE_TENANT_ID` - Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID` - Target Azure subscription
- `AZURE_ARTIFACTS_PAT` - Personal access token for NuGet feed
- `CODECOV_TOKEN` - Code coverage reporting
- `SONAR_TOKEN` - Static analysis

**Setup**:

```bash
gh secret set AZURE_CLIENT_ID --org PointCHealth --body "<value>"
gh secret set AZURE_TENANT_ID --org PointCHealth --body "<value>"
gh secret set AZURE_SUBSCRIPTION_ID --org PointCHealth --body "<value>"
gh secret set AZURE_ARTIFACTS_PAT --org PointCHealth --body "<value>"
```

### 6.2 Deployment Environments

Create environments for approval gates:

- **dev**: No approvals, auto-deploy on merge
- **test**: 1 approval from core team
- **prod**: 2 approvals from admins, 15-minute wait timer

---

## 7. Azure Artifacts Setup

### 7.1 NuGet Feed Configuration

**Feed Name**: `edi-packages`

**Purpose**: Host shared libraries published from `edi-platform-core`

**Setup Steps**:

1. Create Azure DevOps organization: `PointCHealth`
2. Create project: `EDI-Platform`
3. Create artifact feed: `edi-packages`
4. Generate PAT with Packaging permissions
5. Configure NuGet.config in consuming repositories

**NuGet.config Template**:

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    <add key="azure-artifacts" value="https://pkgs.dev.azure.com/PointCHealth/_packaging/edi-packages/nuget/v3/index.json" />
  </packageSources>
  <packageSourceCredentials>
    <azure-artifacts>
      <add key="Username" value="AzureDevOps" />
      <add key="ClearTextPassword" value="%AZURE_ARTIFACTS_PAT%" />
    </azure-artifacts>
  </packageSourceCredentials>
</configuration>
```

---

## 8. Access Control and Security

### 8.1 Azure OIDC Federation

**Benefits**: Secretless authentication from GitHub Actions to Azure

**Setup**:

```bash
# Run OIDC setup script
bash scripts/setup-oidc-federation.sh
```

This configures federated credentials for all repositories to authenticate with Azure without storing credentials in GitHub Secrets.

### 8.2 RBAC Assignments

| Service Principal | Environment | Role | Scope |
|-------------------|-------------|------|-------|
| `gh-actions-edi-platform` | Dev | Contributor | `rg-edi-platform-dev` |
| `gh-actions-edi-platform` | Test | Contributor | `rg-edi-platform-test` |
| `gh-actions-edi-platform` | Prod | Limited (Function deploy only) | `rg-edi-platform-prod` |

---

## 9. Repository Setup Validation

### 9.1 Initial Setup Checklist (Week 1)

**Repository Creation**:

- [ ] All five strategic repositories created
- [ ] Initial README files committed
- [ ] Repository structure scaffolding in place

**Access and Security**:

- [ ] Branch protection configured on all repos
- [ ] CODEOWNERS files in place
- [ ] GitHub Actions secrets configured
- [ ] Azure Artifacts feed ready
- [ ] OIDC federation configured
- [ ] Team access permissions granted

**CI/CD Foundation**:

- [ ] Reusable workflows created in edi-platform-core
- [ ] Environment configurations (dev/test/prod) set up
- [ ] Deployment pipelines tested with sample code

---

## 10. Validation and Testing

### 10.1 Repository Health Checks

**Run validation script**:

```bash
bash scripts/validate-repo-setup.sh
```

**Checks**:

- Branch protection enabled
- CODEOWNERS file present
- GitHub Actions workflows configured
- README documentation exists
- Environments configured for deployments

### 10.2 Integration Testing

**Test scenarios**:

1. Trigger build in each repository
2. Create test PRs to validate review requirements
3. Deploy to dev environment
4. Validate cross-repo dispatch events work
5. Test NuGet package consumption

### 10.3 Developer Validation

**Test with team members**:

- Clone all repositories
- Open multi-root workspace
- Make cross-repo changes
- Create PRs with CODEOWNERS reviews
- Validate AI context awareness

---

## Quick Reference

### Common Commands

**GitHub CLI**:

```bash
# List repos
gh repo list PointCHealth

# View workflows
gh run list --repo PointCHealth/<repo>

# Create PR
gh pr create --title "Title" --body "Description"
```

**Azure CLI**:

```bash
# List function apps
az functionapp list --resource-group rg-edi-platform-dev

# Deploy function
az functionapp deployment source config-zip \
  --resource-group rg-edi-platform-dev \
  --name func-edi-router-dev \
  --src ./artifacts/function.zip
```

**NuGet**:

```bash
# Restore packages
dotnet restore

# Pack library
dotnet pack --configuration Release

# Push to Azure Artifacts
dotnet nuget push ./artifacts/*.nupkg --source azure-artifacts
```

---

## AI Collaboration

This document was developed using AI agent orchestration within GitHub Copilot Workspace. Updates are validated through automated linting, compliance scans, and dependency checks.

---

**Document Status**: Active Implementation Guide  
**Next Review**: End of Week 11 (post-migration)  
**Approval Required From**: DevOps Lead, Platform Architect
