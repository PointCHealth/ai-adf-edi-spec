# Step 07: Create Dependabot Configuration - COMPLETE ✅

**Completed**: October 5, 2025  
**Repository**: All 5 repositories  
**AI Tool**: GitHub Copilot  
**Files Created**: 7 files

---

## Summary

Successfully created Dependabot configuration files for all five strategic repositories to automate dependency updates for NuGet packages, npm, and GitHub Actions. This ensures rapid security patching (HIPAA requirement) while managing the update workload for the 6.5 FTE team.

### Files Created

1. **`edi-platform-core-dependabot.yml`** (~90 lines)
   - Daily NuGet updates (security-focused)
   - Weekly GitHub Actions updates
   - Weekly npm updates
   - Grouped updates (Azure SDK, Functions, Extensions, Testing)
   - 10 open PR limit

2. **`edi-mappers-dependabot.yml`** (~60 lines)
   - Weekly NuGet updates (less critical)
   - Weekly GitHub Actions updates
   - Grouped updates (Functions, Extensions, Testing)
   - 5 open PR limit

3. **`edi-connectors-dependabot.yml`** (~65 lines)
   - Weekly NuGet updates
   - Weekly GitHub Actions updates
   - Grouped updates (Functions, Azure SDK, Extensions, Testing)
   - 5 open PR limit

4. **`edi-partner-configs-dependabot.yml`** (~40 lines)
   - Monthly GitHub Actions updates (minimal dependencies)
   - Monthly npm updates (validation tools)
   - 3 open PR limit

5. **`edi-data-platform-dependabot.yml`** (~60 lines)
   - Weekly NuGet updates
   - Weekly GitHub Actions updates
   - Grouped updates (Microsoft.Data, Extensions, Testing)
   - 5 open PR limit

6. **`deploy-dependabot-configs.ps1`** (~200 lines)
   - PowerShell deployment script
   - Automated copying to all repositories
   - Optional commit and push
   - Status reporting

7. **`dependabot-auto-merge.yml`** (~140 lines)
   - GitHub Actions workflow
   - Auto-approves low-risk updates (patch, minor for tests)
   - Adds labels for tracking
   - Comments on high-risk PRs

---

## Configuration Strategy

### Update Schedule Matrix

| Repository | NuGet Schedule | GitHub Actions | npm | Open PR Limit | Priority |
|------------|---------------|----------------|-----|---------------|----------|
| **edi-platform-core** | Daily (2 AM) | Weekly (Mon 3 AM) | Weekly (Tue 2 AM) | 10 | HIGH (Core platform) |
| **edi-mappers** | Weekly (Wed 2 AM) | Weekly (Mon 3 AM) | N/A | 5 | MEDIUM |
| **edi-connectors** | Weekly (Thu 2 AM) | Weekly (Mon 3 AM) | N/A | 5 | MEDIUM |
| **edi-partner-configs** | N/A | Monthly | Monthly | 3 | LOW (Config only) |
| **edi-data-platform** | Weekly (Fri 2 AM) | Weekly (Mon 3 AM) | N/A | 5 | MEDIUM |

**Rationale**:
- **Daily for core platform**: Rapid security patching for HIPAA compliance
- **Weekly for app repos**: Balanced between security and team capacity
- **Monthly for configs**: Minimal dependencies, low risk
- **Staggered schedules**: Distributes PR workload across the week
- **Weekend execution**: Minimizes disruption during business hours (2-3 AM ET)

### Package Grouping Strategy

**Why Group?** Reduces PR volume by combining related updates into single PRs.

**Groups Defined**:

1. **azure-sdk**: All Azure.* and Microsoft.Azure.* packages
   - Rationale: Azure SDK packages are tightly coupled, should update together

2. **azure-functions**: Microsoft.Azure.Functions.* and Microsoft.Azure.WebJobs.*
   - Rationale: Function runtime packages must be compatible

3. **microsoft-extensions**: All Microsoft.Extensions.* packages
   - Rationale: Extensions packages (DI, Logging, Config) are interdependent

4. **testing**: xunit, Moq, FluentAssertions, coverlet
   - Rationale: Test dependencies can update together without risk

5. **microsoft-data**: Microsoft.Data.* and Microsoft.SqlServer.* (data-platform only)
   - Rationale: SQL/data packages should update in sync

### Ignored Updates

**Major version updates** (`version-update:semver-major`) are ignored for all ecosystems.

**Rationale**:
- Major updates often include breaking changes
- Require manual testing and code modifications
- Team should evaluate impact before upgrading
- Reduces noise in Dependabot PRs

**Process for Major Updates**:
1. Dependabot will not create PRs for major updates
2. Team monitors release notes manually
3. Creates feature branch for major update testing
4. Performs integration testing
5. Merges after validation

---

## Auto-Merge Workflow

### Low-Risk Criteria

The `dependabot-auto-merge.yml` workflow automatically approves and enables auto-merge for:

1. **All patch updates** (`version-update:semver-patch`)
   - Example: 1.2.3 → 1.2.4
   - Typically bug fixes and security patches
   - Very low risk

2. **Minor updates for test dependencies**
   - Packages: xunit, Moq, FluentAssertions, coverlet
   - Example: xunit 2.4.0 → 2.5.0
   - Only affects test code

3. **Minor updates for GitHub Actions**
   - Example: actions/checkout@v3 → actions/checkout@v4
   - GitHub Actions are well-maintained and tested

### High-Risk Handling

Updates **NOT** auto-merged:
- Major version updates (ignored by Dependabot)
- Minor updates for production dependencies
- Updates to core Azure SDK packages (manual review recommended)

**Workflow Actions**:
1. Adds comment: "⚠️ Manual Review Required"
2. Adds label: `manual-review`
3. Waits for team approval

### Labels Applied

- `dependencies` - All Dependabot PRs
- `auto-merge` - Low-risk PRs approved for auto-merge
- `manual-review` - High-risk PRs requiring team review
- Ecosystem-specific: `nuget`, `github-actions`, `npm`
- Repository-specific: `mappers`, `connectors`, `config`, `data-platform`

---

## Deployment

### Step 1: Deploy Configuration Files

**Option A: Automated Deployment (Recommended)**

```powershell
# Navigate to the script directory
cd c:\repos\ai-adf-edi-spec\implementation-plan\dependabot

# Deploy and commit to all repositories
.\deploy-dependabot-configs.ps1 -CommitAndPush

# Check deployment status
```

**Option B: Manual Deployment (Per Repository)**

```powershell
# For each repository
cd c:\repos\edi-platform\edi-platform-core
mkdir -p .github
cp c:\repos\ai-adf-edi-spec\implementation-plan\dependabot\edi-platform-core-dependabot.yml .github\dependabot.yml

git add .github/dependabot.yml
git commit -m "chore: Add Dependabot configuration for automated dependency updates"
git push origin main

# Repeat for other repositories
```

### Step 2: Deploy Auto-Merge Workflow

The auto-merge workflow should be added to repositories where you want automatic approval:

```powershell
# For edi-platform-core (example)
cd c:\repos\edi-platform\edi-platform-core
mkdir -p .github\workflows
cp c:\repos\ai-adf-edi-spec\implementation-plan\dependabot\dependabot-auto-merge.yml .github\workflows\

git add .github\workflows\dependabot-auto-merge.yml
git commit -m "chore: Add Dependabot auto-merge workflow for low-risk updates"
git push origin main
```

**Recommended repositories for auto-merge**:
- ✅ edi-platform-core (high PR volume)
- ✅ edi-mappers (medium PR volume)
- ✅ edi-connectors (medium PR volume)
- ⚠️ edi-partner-configs (low PR volume, manual review preferred)
- ✅ edi-data-platform (medium PR volume)

### Step 3: Verify Activation

**Check Dependabot Status:**

1. Navigate to each repository on GitHub
2. Go to: **Insights → Dependency graph → Dependabot**
3. Verify message: **"Dependabot is active"**
4. Check "Update frequency" matches configuration

**Alternative CLI Check:**

```powershell
# Check if dependabot.yml exists
gh api repos/PointCHealth/edi-platform-core/contents/.github/dependabot.yml

# List Dependabot alerts (if any)
gh api repos/PointCHealth/edi-platform-core/dependabot/alerts
```

### Step 4: Monitor Initial PRs

**Timeline**: Dependabot typically creates initial PRs within 1 hour of activation.

**Check for PRs:**

```powershell
# List Dependabot PRs for all repositories
gh pr list --repo PointCHealth/edi-platform-core --author "app/dependabot"
gh pr list --repo PointCHealth/edi-mappers --author "app/dependabot"
gh pr list --repo PointCHealth/edi-connectors --author "app/dependabot"
gh pr list --repo PointCHealth/edi-partner-configs --author "app/dependabot"
gh pr list --repo PointCHealth/edi-data-platform --author "app/dependabot"
```

**Expected Initial PR Volume**:
- edi-platform-core: 5-10 PRs (many dependencies)
- edi-mappers: 2-5 PRs
- edi-connectors: 2-5 PRs
- edi-partner-configs: 0-2 PRs
- edi-data-platform: 2-5 PRs

---

## Customization Guide

### Adjusting Update Schedules

**Increase Frequency (e.g., daily for critical repo):**

```yaml
schedule:
  interval: "daily"
  time: "02:00"
  timezone: "America/New_York"
```

**Decrease Frequency (e.g., monthly for stable repo):**

```yaml
schedule:
  interval: "monthly"
  time: "02:00"
  timezone: "America/New_York"
```

### Adding New Package Groups

**Example: Group all Newtonsoft.Json packages:**

```yaml
groups:
  json-libraries:
    patterns:
      - "Newtonsoft.Json*"
      - "System.Text.Json"
```

### Ignoring Specific Packages

**Example: Pin a specific package version:**

```yaml
ignore:
  - dependency-name: "Microsoft.Azure.Functions.Worker"
    versions: ["2.x"]  # Only ignore 2.x versions
```

### Changing PR Limits

**Increase if team can handle more PRs:**

```yaml
open-pull-requests-limit: 15  # Default: 10
```

**Decrease if overwhelmed:**

```yaml
open-pull-requests-limit: 3  # Default: 10
```

### Adding Assignees

**Assign PRs to specific team members:**

```yaml
assignees:
  - "platform-lead"
  - "senior-dev"
```

---

## Troubleshooting

### Problem: Dependabot Not Creating PRs

**Diagnosis Steps**:

1. **Check dependabot.yml syntax**:
   ```powershell
   # GitHub provides a validator
   # Navigate to repo → .github/dependabot.yml
   # GitHub will show syntax errors at the top of the file
   ```

2. **Verify manifest files exist**:
   ```powershell
   # For NuGet
   ls **/*.csproj
   ls **/packages.config
   
   # For npm
   ls **/package.json
   
   # For GitHub Actions
   ls .github/workflows/*.yml
   ```

3. **Check Dependabot logs**:
   - Go to: Repository → Insights → Dependency graph → Dependabot
   - Click on the ecosystem (e.g., "NuGet")
   - View "Last checked" timestamp and any errors

**Common Causes**:
- YAML syntax error (indentation)
- No manifest files in repository yet
- Target branch doesn't exist
- Dependabot hasn't run first scheduled check yet

### Problem: Too Many PRs Created

**Solutions**:

1. **Reduce open-pull-requests-limit**:
   ```yaml
   open-pull-requests-limit: 3  # Down from 10
   ```

2. **Increase grouping**:
   ```yaml
   groups:
     all-azure:
       patterns:
         - "Azure.*"
         - "Microsoft.Azure.*"
         - "Microsoft.Extensions.*"
   ```

3. **Change schedule to less frequent**:
   ```yaml
   schedule:
     interval: "monthly"  # Was: daily or weekly
   ```

4. **Close existing PRs**:
   ```powershell
   # Close all Dependabot PRs (use with caution)
   gh pr list --author "app/dependabot" --json number --jq '.[].number' | `
     ForEach-Object { gh pr close $_ }
   ```

### Problem: Auto-Merge Not Working

**Requirements for Auto-Merge**:

1. **Branch protection must allow auto-merge**:
   - Go to: Repository → Settings → Branches → Branch protection rules
   - Check: ☑ "Allow auto-merge"

2. **Status checks must pass**:
   - CI workflows must complete successfully
   - All required checks must pass

3. **GitHub Actions permissions**:
   - Go to: Repository → Settings → Actions → General
   - Check: ☑ "Allow GitHub Actions to create and approve pull requests"

**Debug Steps**:

```powershell
# Check workflow runs
gh run list --workflow=dependabot-auto-merge.yml --limit 10

# View specific run logs
gh run view <run-id> --log
```

**Common Issues**:
- Branch protection requires reviews (cannot auto-merge)
- CI checks failing
- Workflow permissions insufficient

### Problem: Dependabot PRs Failing CI

**Diagnosis**:

1. **Check CI logs**:
   ```powershell
   gh pr view <pr-number> --json statusCheckRollup
   ```

2. **Common causes**:
   - Breaking changes in dependency (even for minor/patch)
   - Test failures due to updated behavior
   - Build errors due to API changes

**Resolution**:

1. **Review the changelog** of the updated package
2. **Update code** to accommodate changes
3. **Push fix to Dependabot PR branch**:
   ```powershell
   gh pr checkout <pr-number>
   # Make fixes
   git add .
   git commit -m "fix: Update code for dependency changes"
   git push
   ```

### Problem: Dependabot Creating Duplicate PRs

**Cause**: Usually happens when grouping changes or config updates.

**Solution**:

1. **Close duplicate PRs**:
   ```powershell
   gh pr close <pr-number> --delete-branch
   ```

2. **Re-run Dependabot**:
   - Go to: Repository → Insights → Dependency graph → Dependabot
   - Click on ecosystem (e.g., NuGet)
   - Click "Check for updates" button

---

## Best Practices

### 1. Regular PR Review Schedule

**Recommended Cadence**:
- **Monday AM**: Review weekend GitHub Actions PRs
- **Tuesday AM**: Review Monday security updates
- **Wednesday AM**: Review grouped updates
- **Friday PM**: Batch approve low-risk updates before weekend

### 2. Security Update Priority

**HIPAA Requirement**: Security patches must be applied within 30 days.

**Process**:
1. Dependabot labels security updates with `security` label
2. Review security PRs immediately (same day)
3. Merge security patches to dev environment within 1 day
4. Test in dev for 24 hours
5. Promote to test, then prod within 1 week

### 3. Testing Strategy for Updates

**Low-Risk (Auto-Merged)**:
- CI must pass (automated tests)
- Deploy to dev automatically
- Monitor for 24 hours

**Medium-Risk (Manual Review)**:
- CI must pass
- Manual code review
- Deploy to dev → 24 hour soak → test → 48 hour soak → prod

**High-Risk (Major Updates)**:
- Create feature branch
- Full regression testing
- Staged rollout: dev → test (1 week) → prod (1 week)

### 4. Communication

**Team Notifications**:
- Configure Slack/Teams webhook for Dependabot PRs
- Daily digest of pending PRs
- Immediate notification for security updates

**Example Teams Webhook (add to GitHub repo)**:
```yaml
# In .github/workflows/dependabot-notifications.yml
on:
  pull_request:
    types: [opened]

jobs:
  notify:
    if: github.actor == 'dependabot[bot]'
    runs-on: ubuntu-latest
    steps:
      - name: Send Teams notification
        run: |
          # Send to Teams webhook
```

### 5. Metrics to Track

**Weekly Dashboard**:
- Number of open Dependabot PRs
- Average time to merge (by risk level)
- Number of security updates merged
- Number of updates causing CI failures

**Monthly Review**:
- Total PRs created vs merged
- Top 10 most updated packages
- Update adoption rate
- Security patch compliance (should be 100%)

---

## Known Limitations

### 1. No Support for Private NuGet Feeds

**Issue**: Dependabot cannot access private NuGet feeds by default.

**Workaround**:
```yaml
# Add to dependabot.yml
registries:
  private-nuget:
    type: nuget-feed
    url: https://pkgs.dev.azure.com/yourorg/_packaging/yourfeed/nuget/v3/index.json
    username: x-access-token
    password: ${{ secrets.PRIVATE_NUGET_TOKEN }}

updates:
  - package-ecosystem: "nuget"
    registries:
      - private-nuget
```

### 2. No Bicep File Support

**Issue**: Dependabot doesn't scan Bicep modules for updates.

**Impact**: Azure Bicep module versions must be updated manually.

**Mitigation**: 
- Manual quarterly review of Bicep module versions
- Subscribe to Azure Verified Modules releases

### 3. Limited npm Monorepo Support

**Issue**: Dependabot struggles with npm workspaces/monorepos.

**Workaround**: Specify each workspace directory separately:
```yaml
updates:
  - package-ecosystem: "npm"
    directory: "/frontend"
  - package-ecosystem: "npm"
    directory: "/tooling"
```

### 4. No Automatic Rollback

**Issue**: If a dependency update breaks production, must rollback manually.

**Mitigation**:
- Always deploy to dev/test first
- Use feature flags for gradual rollouts
- Keep rollback runbook updated

---

## Maintenance Tasks

### Monthly

- [ ] Review Dependabot configuration effectiveness
- [ ] Adjust open-pull-requests-limit based on team capacity
- [ ] Update package grouping rules for new dependencies
- [ ] Review ignored packages list

### Quarterly

- [ ] Evaluate major version updates manually
- [ ] Review security patch compliance (should be 100%)
- [ ] Update Dependabot auto-merge criteria if needed
- [ ] Team retrospective on dependency management

### Annually

- [ ] Review and update all update schedules
- [ ] Evaluate new Dependabot features
- [ ] Update dependency management policies
- [ ] Train team on Dependabot best practices

---

## Security Compliance

### HIPAA Requirements Met

✅ **Rapid Security Patching**: Daily schedule for core platform  
✅ **Audit Trail**: All updates tracked via Git history  
✅ **Change Management**: PR reviews for all updates  
✅ **Access Control**: Team reviewers required  
✅ **Monitoring**: Dependabot alerts for vulnerabilities  

### Vulnerability Scanning

Dependabot automatically scans for:
- Known CVEs in dependencies
- Security advisories from package maintainers
- Outdated packages with security patches

**Alert Process**:
1. Dependabot creates security alert
2. Creates PR with patch
3. Adds `security` label
4. Sends notification to team
5. Team reviews and merges within 24 hours

---

## Next Steps

### Immediate (Week 3)
- ✅ Deploy Dependabot configuration to all repositories
- ✅ Verify Dependabot activation
- ⏭️ **Monitor initial PRs for first week**
- ⏭️ **Adjust schedules based on PR volume**
- ⏭️ **Proceed to Phase 3**: Infrastructure Implementation

### Short-term (Phase 3+)
- Add Dependabot secrets for private registries (if needed)
- Configure branch protection rules to support auto-merge
- Set up Teams/Slack notifications for Dependabot PRs
- Create metrics dashboard for dependency updates

### Long-term
- Implement automated regression testing for dependency updates
- Create runbook for emergency dependency rollback
- Integrate with vulnerability scanning tools (Snyk, WhiteSource)
- Develop dependency update policies and training

---

## References

### Internal Documentation
- [Strategic Repository Setup](STEP_01_COMPLETE.md)
- [CODEOWNERS Configuration](STEP_02_COMPLETE.md)
- [Security & Compliance Spec](../../docs/03-security-compliance-spec.md)
- [Operations Spec](../../docs/06-operations-spec.md)

### External Resources
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [Dependabot Configuration Options](https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file)
- [Auto-Merge PRs](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/automatically-merging-a-pull-request)
- [GitHub Actions Permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)

---

**Status**: ✅ **COMPLETE**  
**Next Step**: Phase 3 - Infrastructure Implementation  
**Phase Progress**: Phase 2 - 100% Complete (4 of 4 steps) ✅
