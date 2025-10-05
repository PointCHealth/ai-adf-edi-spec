# AI Prompt: Create Strategic Repository Structure

## Objective
Create five strategic repositories for the EDI platform and initialize each with the appropriate directory structure as specified in the implementation plan.

## Prerequisites
- GitHub organization `PointCHealth` exists with appropriate permissions
- GitHub CLI (`gh`) installed and authenticated
- Git installed and configured locally
- VS Code with multi-root workspace support

## Prompt

```
I need you to help me set up five strategic repositories for the EDI Healthcare Platform project.

Context:
- Organization: PointCHealth
- Project: Healthcare EDI transaction processing platform using Azure Data Factory, Azure Functions, and Service Bus
- Architecture: Event-driven, microservices-based, strategic multi-repository approach
- Timeline: 18-week AI-accelerated implementation

Please create these FIVE repositories with their respective structures:

---
## Repository 1: edi-platform-core

Purpose: Core infrastructure, shared libraries, router, and scheduler

Directory structure:
```
edi-platform-core/
├── .github/
│   ├── workflows/ (infra CI/CD, core function workflows)
│   ├── ISSUE_TEMPLATE/
│   └── PULL_REQUEST_TEMPLATE.md
├── infra/
│   └── bicep/
│       ├── main.bicep
│       ├── modules/ (storage, key-vault, service-bus, sql, etc.)
│       └── parameters/ (dev/test/prod.parameters.json)
├── shared/
│   ├── EDI.Core/
│   ├── EDI.X12/
│   ├── EDI.Configuration/
│   ├── EDI.Storage/
│   ├── EDI.Messaging/
│   └── EDI.Logging/
├── functions/
│   ├── InboundRouter.Function/
│   └── EnterpriseScheduler.Function/
├── tests/
│   ├── Integration.Tests/
│   └── Unit.Tests/
├── docs/
│   ├── architecture/
│   ├── api/
│   └── cross-repo-guide.md
├── scripts/
├── README.md
└── .gitignore
```

---
## Repository 2: edi-mappers

Purpose: All EDI transaction mapper functions

Directory structure:
```
edi-mappers/
├── .github/
│   └── workflows/ (mapper CI/CD)
├── functions/
│   ├── EligibilityMapper.Function/ (270/271)
│   ├── ClaimsMapper.Function/ (837/277)
│   ├── EnrollmentMapper.Function/ (834)
│   └── RemittanceMapper.Function/ (835)
├── shared/
│   └── EDI.Mappers.Common/
├── tests/
│   ├── Integration.Tests/
│   └── TestData/ (sample transactions)
├── README.md
└── .gitignore
```

---
## Repository 3: edi-connectors

Purpose: Trading partner connector functions

Directory structure:
```
edi-connectors/
├── .github/
│   └── workflows/ (connector CI/CD)
├── functions/
│   ├── SftpConnector.Function/
│   ├── ApiConnector.Function/
│   └── DatabaseConnector.Function/
├── shared/
│   └── EDI.Connectors.Common/
├── tests/
│   ├── Integration.Tests/
│   └── TestData/
├── README.md
└── .gitignore
```

---
## Repository 4: edi-partner-configs

Purpose: Partner metadata and routing configurations

Directory structure:
```
edi-partner-configs/
├── .github/
│   └── workflows/ (config validation)
├── partners/
│   ├── anthem/
│   │   ├── partner.json
│   │   ├── mappings/
│   │   └── credentials/ (encrypted)
│   └── template/
├── schemas/
│   ├── partner-schema.json
│   └── mapping-schema.json
├── routing/
│   └── routing-rules.json
├── README.md
└── .gitignore
```

---
## Repository 5: edi-data-platform

Purpose: ADF pipelines and SQL databases

Directory structure:
```
edi-data-platform/
├── .github/
│   └── workflows/ (ADF and SQL CI/CD)
├── adf/
│   ├── pipelines/
│   ├── datasets/
│   ├── linkedServices/
│   └── triggers/
├── sql/
│   ├── ControlNumbers/
│   │   ├── schemas/
│   │   ├── tables/
│   │   └── stored-procedures/
│   └── EventStore/
│       ├── schemas/
│       ├── tables/
│       └── stored-procedures/
├── tests/
├── README.md
└── .gitignore
```

---

For EACH repository:

1. Create the repository in GitHub: `gh repo create PointCHealth/<repo-name> --private`

2. Create comprehensive .gitignore with:
   - .NET specific ignores (bin/, obj/, *.user, *.suo)
   - Azure Functions ignores (local.settings.json, __blobstorage__, __queuestorage__, __azurite_db*)
   - VS Code ignores (.vscode/ except workspace settings)
   - OS ignores (Thumbs.db, .DS_Store)
   - Sensitive files (*.pfx, *.p12, *.key, secrets.json)

3. Create README.md with:
   - Repository purpose
   - Links to other repositories in the stack
   - Link to centralized docs in edi-platform-core
   - Quick start guide
   - Development setup
   - How to deploy

4. Add .gitkeep files to maintain empty directories

5. Create initial commit and push

6. Create VS Code multi-root workspace file: `edi-platform.code-workspace`

Please provide:
1. Complete bash/PowerShell script to create all repositories
2. Multi-root workspace configuration
3. Summary of what was created
4. Next steps for team setup
```

## Expected Outcome

After running this prompt, you should have:
- ✅ Five repositories created in GitHub under PointCHealth organization
- ✅ Each repository initialized with appropriate directory structure
- ✅ .gitignore files configured in each repository
- ✅ README.md files with repository-specific documentation
- ✅ Cross-repository references documented
- ✅ Multi-root VS Code workspace file created
- ✅ All directories tracked in Git (via .gitkeep)
- ✅ Initial commits pushed to all repositories

## Validation Steps

1. Verify all repositories created:
   ```powershell
   gh repo list PointCHealth --limit 100 | Select-String "edi-"
   ```

2. Clone all repositories locally:
   ```powershell
   mkdir c:\repos\edi-platform
   cd c:\repos\edi-platform
   gh repo clone PointCHealth/edi-platform-core
   gh repo clone PointCHealth/edi-mappers
   gh repo clone PointCHealth/edi-connectors
   gh repo clone PointCHealth/edi-partner-configs
   gh repo clone PointCHealth/edi-data-platform
   ```

3. Open multi-root workspace in VS Code:
   ```powershell
   code edi-platform.code-workspace
   ```

4. Verify structure in each repository:
   ```powershell
   cd edi-platform-core
   tree /F /A
   ```

5. Test .gitignore in one repository:
   ```powershell
   cd edi-platform-core\functions\InboundRouter.Function
   echo "test" > local.settings.json
   cd ..\..
   git status  # Should not show local.settings.json
   ```

## Next Steps

After successful completion:
- Proceed to [02-create-codeowners.md](02-create-codeowners.md) for each repository
- Configure branch protection rules on all repositories
- Set up GitHub secrets and variables [03-configure-github-variables.md](03-configure-github-variables.md)
- Begin infrastructure template development [08-create-bicep-templates.md](08-create-bicep-templates.md)
- Set up shared library packaging to Azure Artifacts
