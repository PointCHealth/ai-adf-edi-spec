# AI Prompt: Create CODEOWNERS Files for All Repositories

## Objective
Create GitHub CODEOWNERS files for each of the five strategic repositories to automatically assign reviewers based on the files being changed.

## Prerequisites
- Strategic repositories created (edi-platform-core, edi-mappers, edi-connectors, edi-partner-configs, edi-data-platform)
- Team structure and GitHub handles identified
- Repository permissions configured

## Prompt

```
I need you to create CODEOWNERS files for each of the five strategic repositories in the EDI Healthcare Platform.

Context:
- Architecture: Five separate repositories (edi-platform-core, edi-mappers, edi-connectors, edi-partner-configs, edi-data-platform)
- Project: Healthcare EDI platform with infrastructure, Azure Functions, and partner configurations
- Teams: Platform Engineering, Data Engineering, Security, DevOps
- Security-sensitive areas require security team review
- Infrastructure changes require platform team review

For EACH repository, create a .github/CODEOWNERS file appropriate to that repository's content:

## edi-platform-core CODEOWNERS

Create .github/CODEOWNERS with these ownership rules:

1. Default ownership:
   - All files: @vincemic (platform lead)

2. Infrastructure ownership:
   - /infra/ → @vincemic @platform-team
   - /infra/sql/ → @vincemic @data-engineering-team
   - Bicep files → @platform-team @devops-team

3. Application code ownership:
   - /functions/ → @data-engineering-team @vincemic
   - /shared/ → @data-engineering-team @vincemic
   - C# files (*.cs) in functions → @data-engineering-team

4. Configuration ownership:
   - /config/ → @security-team @vincemic
   - /config/partners/ → @security-team @data-engineering-team @vincemic
   - /config/routing/ → @data-engineering-team @vincemic

5. CI/CD ownership:
   - /.github/workflows/ → @devops-team @platform-team
   - /.github/actions/ → @devops-team

6. Security-sensitive files:
   - *.key, *.pfx, *.p12 → @security-team @vincemic
   - Key Vault references → @security-team
   - Any files with "secret" or "credential" → @security-team

7. Documentation:
   - /docs/ → @vincemic
   - README.md files → (use default owner)
   - Architecture docs → @platform-team @vincemic

8. Test code:
   - /tests/ → @data-engineering-team @devops-team

## edi-mappers CODEOWNERS

Create .github/CODEOWNERS for mapper functions:

1. Default ownership: @data-engineering-team @vincemic
2. Mapper functions: /functions/ → @data-engineering-team
3. Shared mapper code: /shared/ → @data-engineering-team
4. Test data: /tests/TestData/ → @data-engineering-team @security-team
5. CI/CD: /.github/workflows/ → @devops-team @data-engineering-team

## edi-connectors CODEOWNERS

Create .github/CODEOWNERS for connector functions:

1. Default ownership: @data-engineering-team @vincemic
2. Connector functions: /functions/ → @data-engineering-team
3. Connection logic: /shared/ → @data-engineering-team @security-team
4. CI/CD: /.github/workflows/ → @devops-team @data-engineering-team

## edi-partner-configs CODEOWNERS

Create .github/CODEOWNERS for partner configurations:

1. Default ownership: @security-team @vincemic
2. Partner configurations: /partners/ → @security-team @data-engineering-team
3. Configuration schemas: /schemas/ → @data-engineering-team @security-team
4. Routing rules: /routing/ → @data-engineering-team
5. Validation workflows: /.github/workflows/ → @devops-team @security-team

## edi-data-platform CODEOWNERS

Create .github/CODEOWNERS for ADF and SQL:

1. Default ownership: @data-engineering-team @vincemic
2. ADF pipelines: /adf/ → @data-engineering-team
3. SQL schemas: /sql/ → @data-engineering-team @vincemic
4. CI/CD: /.github/workflows/ → @devops-team @data-engineering-team

## Common Requirements for ALL CODEOWNERS Files

Requirements:
- Use proper CODEOWNERS syntax
- Add comments explaining each section
- Include fallback patterns
- Ensure most specific patterns come last
- Include guidance comments at the top of the file

Also provide:
1. Instructions for team members to test if they're code owners
2. How to request ownership changes
3. Best practices for using CODEOWNERS with PRs
```

## Expected Outcome

After running this prompt, you should have:
- ✅ `.github/CODEOWNERS` files created in ALL FIVE repositories
- ✅ Repository-specific ownership rules appropriate to each codebase
- ✅ All critical paths have designated owners
- ✅ Security-sensitive areas protected
- ✅ Clear documentation in file comments

## Post-Creation Tasks (Human Required)

1. **Update team handles** in the CODEOWNERS file:
   - Replace `@platform-team` with actual GitHub team handle
   - Replace `@data-engineering-team` with actual team handle
   - Replace `@security-team` with actual team handle
   - Replace `@devops-team` with actual team handle
   - Replace `@vincemic` with actual lead's GitHub handle

2. **Create GitHub teams** if they don't exist:
   - Navigate to: Organization → Teams → New team
   - Add team members with appropriate permissions

3. **Verify CODEOWNERS** is enforced:
   - Go to: Settings → Branches → Edit main rule
   - Enable "Require review from Code Owners"

## Validation Steps

1. Commit the CODEOWNERS file:
   ```powershell
   git add .github/CODEOWNERS
   git commit -m "feat: Add CODEOWNERS for automated reviewer assignment"
   git push origin main
   ```

2. Test ownership detection:
   ```powershell
   # Create test PR to verify
   git checkout -b test/codeowners
   echo "test" >> infra/bicep/test.bicep
   git add infra/bicep/test.bicep
   git commit -m "test: Verify CODEOWNERS"
   git push origin test/codeowners
   # Create PR and check if correct reviewers are automatically assigned
   ```

3. Verify in GitHub UI:
   - Create a PR
   - Check if reviewers are automatically requested
   - Verify correct teams are assigned based on files changed

## Next Steps

After successful completion:
- Configure branch protection to require CODEOWNERS review
- Proceed to workflow creation [04-create-infrastructure-workflows.md](04-create-infrastructure-workflows.md)
