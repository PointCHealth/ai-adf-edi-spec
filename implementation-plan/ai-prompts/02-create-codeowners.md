# AI Prompt: Create CODEOWNERS File

## Objective
Create a GitHub CODEOWNERS file to automatically assign reviewers based on the files being changed.

## Prerequisites
- Monorepo structure created
- Team structure and GitHub handles identified
- Repository permissions configured

## Prompt

```
I need you to create a comprehensive CODEOWNERS file for the EDI Healthcare Platform monorepo.

Context:
- Project: Healthcare EDI platform with infrastructure, Azure Functions, and partner configurations
- Teams: Platform Engineering, Data Engineering, Security, DevOps
- Security-sensitive areas require security team review
- Infrastructure changes require platform team review

Please create a .github/CODEOWNERS file with the following ownership rules:

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
- ✅ `.github/CODEOWNERS` file created
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
