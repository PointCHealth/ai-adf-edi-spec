# AI Prompt: Configure GitHub Variables

## Objective
Create a script to configure GitHub repository variables for Azure resource names and common configuration.

## Prerequisites
- GitHub CLI installed and authenticated
- Repository admin permissions
- Azure resource naming conventions approved

## Prompt

```
I need you to create a PowerShell script to configure GitHub repository variables for the EDI platform.

Context:
- Project: Healthcare EDI platform on Azure
- Environments: dev, test, prod
- Azure region: East US 2
- Resource naming convention: <resource-type>-edi-<env>-<location>

Please create a PowerShell script named 'configure-github-variables.ps1' that:

1. Uses GitHub CLI to set these repository-level variables:
   - AZURE_LOCATION = "eastus2"
   - PROJECT_NAME = "edi-platform"
   - DEV_RESOURCE_GROUP = "rg-edi-dev-eastus2"
   - TEST_RESOURCE_GROUP = "rg-edi-test-eastus2"
   - PROD_RESOURCE_GROUP = "rg-edi-prod-eastus2"
   - STORAGE_ACCOUNT_PREFIX = "stedi"
   - FUNCTION_APP_PREFIX = "func-edi"
   - SERVICE_BUS_PREFIX = "sb-edi"
   - ADF_PREFIX = "adf-edi"
   - KEY_VAULT_PREFIX = "kv-edi"
   - SQL_SERVER_PREFIX = "sql-edi"
   - APP_INSIGHTS_PREFIX = "appi-edi"

2. Include validation:
   - Check if GitHub CLI is installed
   - Verify authentication to GitHub
   - Confirm the repository exists
   - Check for admin permissions

3. Add error handling:
   - Catch and display errors clearly
   - Provide troubleshooting guidance
   - Allow retry on failure

4. Include a summary report:
   - List all variables set successfully
   - Show any failures
   - Provide next steps

5. Add documentation:
   - Comment explaining each variable's purpose
   - Usage instructions at the top
   - Examples of how to reference variables in workflows

Also provide:
1. Instructions for running the script
2. How to verify variables were set correctly
3. How to update variables later if needed
4. Alternative manual steps if GitHub CLI is not available
```

## Expected Outcome

After running this prompt, you should have:
- ✅ PowerShell script created: `scripts/configure-github-variables.ps1`
- ✅ Script includes validation and error handling
- ✅ Documentation and usage instructions included

## Execution Steps (Human Required)

1. Review the generated script:
   ```powershell
   cat scripts/configure-github-variables.ps1
   ```

2. Run the script:
   ```powershell
   cd c:\repos\edi-platform-core
   .\scripts\configure-github-variables.ps1
   ```

3. Verify variables were set:
   ```powershell
   gh variable list
   ```

## Alternative: Manual Configuration

If the script fails, set variables manually via GitHub UI:

1. Navigate to: **Settings → Secrets and variables → Actions → Variables tab**
2. Click "New repository variable"
3. Add each variable from the list above

Or via GitHub CLI individually:

```powershell
gh variable set AZURE_LOCATION --body "eastus2"
gh variable set PROJECT_NAME --body "edi-platform"
gh variable set DEV_RESOURCE_GROUP --body "rg-edi-dev-eastus2"
# ... repeat for all variables
```

## Validation Steps

1. List all variables:
   ```powershell
   gh variable list
   ```

2. Check specific variable:
   ```powershell
   gh variable get AZURE_LOCATION
   ```

3. Test in workflow:
   - Create a test workflow that references `${{ vars.AZURE_LOCATION }}`
   - Run workflow and verify variable value is correct

## Troubleshooting

**Error: "GitHub CLI not found"**
- Install: `winget install GitHub.cli`
- Authenticate: `gh auth login`

**Error: "Resource not accessible by integration"**
- Verify you have admin permissions on the repository
- Check organization settings allow GitHub CLI access

**Error: "Variable already exists"**
- Use `gh variable set` with `--overwrite` flag
- Or delete first: `gh variable delete VARIABLE_NAME`

## Next Steps

After successful completion:
- Variables are available to reference in all workflows
- Proceed to workflow creation [04-create-infrastructure-workflows.md](04-create-infrastructure-workflows.md)
