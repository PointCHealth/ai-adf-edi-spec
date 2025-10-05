# AI Prompt: Create Monorepo Structure

## Objective
Clone the EDI platform repository and create the complete monorepo directory structure as specified in the implementation plan.

## Prerequisites
- Repository `edi-platform-monorepo` already created in GitHub
- Git installed and configured locally
- GitHub authentication configured (SSH or HTTPS)

## Prompt

```
I need you to help me set up the complete monorepo structure for the EDI Healthcare Platform project.

Context:
- Repository: PointCHealth/edi-platform-monorepo
- Project: Healthcare EDI transaction processing platform using Azure Data Factory, Azure Functions, and Service Bus
- Architecture: Event-driven, microservices-based

Please perform the following tasks:

1. Create the complete directory structure with these top-level folders:
   - .github/ (workflows, actions, ISSUE_TEMPLATE, PULL_REQUEST_TEMPLATE)
   - infra/ (bicep modules, sql scripts, terraform if needed)
   - functions/ (all Azure Function projects)
   - shared/ (shared libraries and common code)
   - config/ (partner configurations, routing rules, mapping definitions)
   - tests/ (integration tests, load tests, test data)
   - docs/ (API docs, architecture diagrams, runbooks)
   - scripts/ (deployment scripts, utility scripts)
   - ai-prompts/ (AI prompt library for development tasks)

2. Under functions/, create subdirectories for:
   - InboundRouter.Function
   - OutboundOrchestrator.Function
   - X12Parser.Function
   - MapperEngine.Function
   - ControlNumberGenerator.Function
   - FileArchiver.Function
   - NotificationService.Function

3. Under infra/, create subdirectories for:
   - bicep/modules (individual resource modules)
   - bicep/main (main orchestration templates)
   - sql/schemas
   - sql/migrations
   - sql/stored-procedures

4. Under shared/, create subdirectories for:
   - EDI.Core (core abstractions and interfaces)
   - EDI.X12 (X12 parsing and validation)
   - EDI.Configuration (configuration management)
   - EDI.Storage (storage abstractions)
   - EDI.Messaging (Service Bus abstractions)

5. Under tests/, create subdirectories for:
   - Integration.Tests
   - Load.Tests
   - TestData (sample EDI files, test configurations)

6. Create a comprehensive .gitignore file that includes:
   - .NET specific ignores (bin/, obj/, *.user, *.suo)
   - Azure Functions ignores (local.settings.json, __blobstorage__, __queuestorage__, __azurite_db*)
   - VS Code ignores (.vscode/ except for recommended workspace settings)
   - Terraform ignores (*.tfstate, .terraform/)
   - OS ignores (Thumbs.db, .DS_Store)
   - Sensitive files (*.pfx, *.p12, *.key, appsettings.*.json except templates)

7. Add .gitkeep files to empty directories so they're tracked in Git

8. Create a comprehensive README.md at the root with:
   - Project overview
   - Architecture diagram link
   - Quick start guide
   - Directory structure explanation
   - Development setup requirements
   - How to run locally
   - How to deploy
   - Contributing guidelines
   - Links to detailed documentation

Please create all necessary files and directories, and provide me with:
1. A summary of what was created
2. The git commands to commit and push this initial structure
3. Any recommendations for next steps
```

## Expected Outcome

After running this prompt, you should have:
- ✅ Complete directory structure created locally
- ✅ .gitignore file configured
- ✅ README.md with project overview
- ✅ All directories tracked in Git (via .gitkeep)
- ✅ Ready to commit and push initial structure

## Validation Steps

1. Verify directory structure:
   ```powershell
   tree /F /A
   ```

2. Check .gitignore is working:
   ```powershell
   # Create a test file that should be ignored
   echo "test" > functions/InboundRouter.Function/local.settings.json
   git status  # Should not show local.settings.json
   ```

3. Commit and push:
   ```powershell
   git add .
   git commit -m "feat: Initialize monorepo structure"
   git push origin main
   ```

## Next Steps

After successful completion:
- Proceed to [02-create-codeowners.md](02-create-codeowners.md)
- Begin infrastructure template development [08-create-bicep-templates.md](08-create-bicep-templates.md)
