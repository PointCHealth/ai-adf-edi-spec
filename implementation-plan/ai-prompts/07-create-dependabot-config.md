# AI Prompt: Create Dependabot Configuration

## Objective

Create Dependabot configuration files for all five strategic repositories to automate dependency updates for NuGet packages, npm, and GitHub Actions.

## Prerequisites

- All five repositories created and accessible
- Understanding of dependency update cadence requirements
- Team members identified for review assignments

## Prompt

```text
I need you to create Dependabot configuration files for the EDI Healthcare Platform repositories.

Context:
- Organization: PointCHealth
- Five repositories: edi-platform-core, edi-mappers, edi-connectors, edi-partner-configs, edi-data-platform
- Technology: .NET 9, Azure Functions, Bicep, npm (for any tooling), GitHub Actions
- Security: HIPAA compliance requires rapid security patching
- Team: Single DevOps/Platform Engineering team (6.5 FTE)

Please create `.github/dependabot.yml` for EACH repository with these requirements:

---

## Repository 1: edi-platform-core

Ecosystem coverage:
- **nuget**: Shared libraries (EDI.Core, EDI.X12, etc.) and function projects
- **github-actions**: Workflow dependencies
- **npm**: Any frontend tooling or build scripts

Configuration:
- Update schedule: Daily for security updates, weekly for version updates
- Auto-merge: Minor and patch updates for non-breaking changes
- Grouping: Group related updates (e.g., all Azure SDK packages)
- Reviewers: @edi-platform-team
- Labels: dependencies, security (for security updates)
- Open pull request limit: 10
- Rebase strategy: Auto

---

## Repository 2: edi-mappers

Ecosystem coverage:
- **nuget**: Function projects and mapper libraries
- **github-actions**: Workflow dependencies

Configuration:
- Update schedule: Weekly (mappers less critical for immediate updates)
- Auto-merge: Patch updates only
- Reviewers: @edi-platform-team
- Labels: dependencies, mappers
- Open pull request limit: 5

---

## Repository 3: edi-connectors

Ecosystem coverage:
- **nuget**: Function projects and connector libraries
- **github-actions**: Workflow dependencies

Configuration:
- Update schedule: Weekly
- Auto-merge: Patch updates only
- Reviewers: @edi-platform-team
- Labels: dependencies, connectors
- Open pull request limit: 5

---

## Repository 4: edi-partner-configs

Ecosystem coverage:
- **github-actions**: Validation workflow dependencies (if any)
- **npm**: JSON schema validation tools (if applicable)

Configuration:
- Update schedule: Monthly (minimal dependencies)
- Reviewers: @edi-platform-team
- Labels: dependencies, config
- Open pull request limit: 3

---

## Repository 5: edi-data-platform

Ecosystem coverage:
- **nuget**: SQL DACPAC projects (if any .NET tooling)
- **github-actions**: Workflow dependencies

Configuration:
- Update schedule: Weekly
- Reviewers: @edi-platform-team
- Labels: dependencies, data-platform
- Open pull request limit: 5

---

Best practices to include:
- Separate security updates from version updates
- Group related packages (e.g., all Microsoft.Azure.* packages)
- Ignore major version updates that require breaking changes (handle manually)
- Schedule updates during low-activity times (weekends for dev/test)
- Configure commit message prefix: "chore(deps):"
- Enable vulnerability alerts
- Set appropriate target branches (main)

Also provide:
1. Script to deploy all dependabot.yml files to their respective repositories
2. GitHub Actions workflow to auto-approve and merge low-risk updates
3. Documentation on how to customize update schedules per environment
4. Troubleshooting guide for common Dependabot issues
```

## Expected Outcome

After running this prompt, you should have:

- ✅ `.github/dependabot.yml` files created for all five repositories
- ✅ Appropriate ecosystem coverage per repository
- ✅ Security-focused update schedules
- ✅ Team review assignments configured
- ✅ Grouping rules for related packages
- ✅ Auto-merge policies for low-risk updates

## Validation Steps

1. Deploy Dependabot configs to repositories:

   ```powershell
   # Assuming AI generated files in local directory
   cd edi-platform-core
   git add .github/dependabot.yml
   git commit -m "chore: Add Dependabot configuration"
   git push origin main
   
   # Repeat for other repositories
   ```

2. Verify Dependabot is active:
   - Navigate to each repository → Insights → Dependency graph → Dependabot
   - Should show "Dependabot is active"

3. Check for initial update PRs:
   - Wait 1 hour after deploying
   - Check Pull Requests tab in each repository
   - Should see PRs for outdated dependencies

4. Test auto-merge workflow (if created):

   ```powershell
   # Trigger workflow manually or wait for PR
   gh pr list --repo PointCHealth/edi-platform-core --label dependencies
   ```

## Troubleshooting

**Dependabot not creating PRs:**

- Verify dependabot.yml syntax: Use GitHub's dependabot.yml validator
- Check if all package ecosystems have manifest files (e.g., .csproj, package.json)
- Ensure target branch exists

**Too many PRs created:**

- Reduce `open-pull-request-limit`
- Increase grouping rules to batch related updates
- Adjust schedule to less frequent intervals

**Auto-merge not working:**

- Verify GitHub Actions has write permissions
- Check branch protection rules allow auto-merge
- Ensure PR meets all status check requirements

## Next Steps

After successful completion:

- Monitor Dependabot PRs for first week
- Adjust schedules based on PR volume
- Configure Dependabot secrets if needed for private registries
- Proceed to [09-create-function-projects.md](09-create-function-projects.md)
