# AI Prompts Index

Quick reference guide for all AI prompts available for EDI Platform implementation.

## 📋 Overview

This directory contains AI prompts that automate various aspects of the EDI Platform setup and implementation. Each prompt is designed to work with GitHub Copilot, ChatGPT, or similar AI assistants.

## 🚀 Quick Start

1. **Start with the README**: Read [README.md](README.md) for the complete implementation roadmap
2. **Identify your current phase**: See what needs human action vs AI automation
3. **Run prompts in order**: Follow the numbered sequence for best results
4. **Validate each step**: Use the validation steps in each prompt file

## 📂 Available Prompts

### Phase 1: Repository Setup (Week 1)

| # | Prompt File | Purpose | Type |
|---|------------|---------|------|
| 01 | [01-create-monorepo-structure.md](01-create-monorepo-structure.md) | Create complete directory structure and initial files | 🤖 Automated |
| 02 | [02-create-codeowners.md](02-create-codeowners.md) | Generate CODEOWNERS file for automatic reviewer assignment | 🤖 Automated |
| 03 | [03-configure-github-variables.md](03-configure-github-variables.md) | Script to set GitHub repository variables | 🤖 Automated |

### Phase 2: CI/CD Workflows (Week 2-3)

| # | Prompt File | Purpose | Type |
|---|------------|---------|------|
| 04 | [04-create-infrastructure-workflows.md](04-create-infrastructure-workflows.md) | Create Bicep CI/CD and drift detection workflows | 🤖 Automated |
| 05 | [05-create-function-workflows.md](05-create-function-workflows.md) | Create Azure Functions build and deployment workflows | 🤖 Automated |
| 06 | [06-create-monitoring-workflows.md](06-create-monitoring-workflows.md) | Create cost, security, and health monitoring workflows | 🤖 Automated |

### Phase 3: Infrastructure (Week 3)

| # | Prompt File | Purpose | Type |
|---|------------|---------|------|
| 08 | [08-create-bicep-templates.md](08-create-bicep-templates.md) | Generate complete Bicep infrastructure as code | 🤖 Automated |

### Phase 4: Partner Configuration (Week 4)

| # | Prompt File | Purpose | Type |
|---|------------|---------|------|
| 15 | [15-onboard-trading-partner.md](15-onboard-trading-partner.md) | Create partner configuration schema and onboarding automation | 🤖 Automated |

## 🎯 Prompts Coming Soon

These prompts are referenced in the README but not yet created. Contribute or request:

- `07-create-dependabot-config.md` - Dependabot configuration
- `09-create-function-projects.md` - Azure Function project scaffolding
- `10-create-ai-prompt-library.md` - Additional AI prompts for development
- `11-create-dev-setup-script.md` - Development environment automation
- `12-create-shared-libraries.md` - Shared library projects
- `13-create-partner-config-schema.md` - Partner configuration schema
- `14-create-integration-tests.md` - Integration test suite
- `16-create-monitoring-dashboards.md` - Application Insights dashboards
- `17-create-operations-runbooks.md` - Operations documentation
- `18-create-performance-tests.md` - Load and performance testing

## 🔧 How to Use These Prompts

### Option 1: GitHub Copilot Chat (Recommended)

1. Open the prompt file in VS Code
2. Copy the entire prompt section
3. Open Copilot Chat (Ctrl+Alt+I or Cmd+Alt+I)
4. Paste the prompt and send
5. Review generated code/files
6. Follow validation steps

### Option 2: ChatGPT or Claude

1. Open the prompt file
2. Copy the entire prompt section
3. Paste into ChatGPT/Claude
4. Provide additional context if requested
5. Copy generated output to your repository
6. Follow validation steps

### Option 3: GitHub Copilot Workspace (Enterprise)

1. Reference the prompt file in your workspace
2. Use `@workspace` to give AI full context
3. AI can directly create and modify files
4. Validate changes via integrated tools

## 📊 Prompt Effectiveness Tracking

Track your AI code acceptance rate (target: >70%):

| Prompt | AI Generated LOC | Accepted | Modified | Rejected | Rate |
|--------|------------------|----------|----------|----------|------|
| 01-monorepo | - | - | - | - | - |
| 02-codeowners | - | - | - | - | - |
| 04-infra-workflows | - | - | - | - | - |
| ... | ... | ... | ... | ... | ... |

## 🎓 Best Practices

### Before Running a Prompt

✅ **DO:**
- Read the prerequisite section carefully
- Ensure previous dependencies are complete
- Have required credentials/access ready
- Review the expected outcome section

❌ **DON'T:**
- Skip validation steps
- Run prompts out of order (unless dependencies met)
- Ignore "Human Required" tasks
- Commit AI-generated code without review

### After Running a Prompt

✅ **DO:**
- Review all generated code thoroughly
- Run validation steps provided
- Test functionality before committing
- Update team names, handles, and placeholders
- Document any deviations from AI output

❌ **DON'T:**
- Blindly commit without testing
- Skip security reviews
- Ignore linting or compilation errors
- Deploy to production without approval

## 🔍 Prompt Anatomy

Each prompt file follows this structure:

```markdown
# AI Prompt: [Title]

## Objective
What this prompt accomplishes

## Prerequisites
What must be completed first

## Prompt
```
The actual prompt to copy/paste to AI
```

## Expected Outcome
What you should have after running

## Validation Steps
How to verify it worked

## Troubleshooting
Common issues and solutions

## Next Steps
What to do after success
```

## 🤝 Contributing New Prompts

To add a new prompt:

1. Copy an existing prompt file as template
2. Follow the anatomy structure above
3. Test with at least 2 AI tools
4. Document validation steps thoroughly
5. Add to this index
6. Submit PR with example output

## 📈 Success Metrics

Per the implementation plan, track:

- **AI Code Acceptance Rate**: >70% target
- **Time Saved**: Compare traditional vs AI-assisted
- **Quality**: Bugs found in AI-generated vs manual code
- **Prompt Effectiveness**: Iterations needed to get working code

## 🆘 Getting Help

**Prompt doesn't work?**
1. Check prerequisites are met
2. Review troubleshooting section
3. Try rephrasing or adding more context
4. Consult with team or create GitHub issue

**AI generates incorrect code?**
1. Add more context to the prompt
2. Reference specific architecture docs
3. Provide examples of expected output
4. Manually correct and document learnings

**Need a new prompt?**
1. Check if similar prompt exists
2. Create GitHub issue with request
3. Provide clear use case and context
4. Contribute it yourself (encouraged!)

## 📚 Related Documentation

- [Implementation Overview](../00-implementation-overview.md)
- [Architecture Specification](../../docs/01-architecture-spec.md)
- [GitHub Actions Implementation](../../docs/04a-github-actions-implementation.md)
- [Partner Onboarding Playbook](../12-partner-onboarding-playbook.md)

## 📅 Prompt Roadmap

### Completed ✅
- Repository setup automation
- CODEOWNERS generation
- Infrastructure workflows
- Function workflows
- Monitoring workflows
- Bicep template generation
- Partner configuration system

### In Progress 🚧
- Dependabot configuration
- Function project scaffolding
- Integration testing framework

### Planned 📋
- Performance testing automation
- Security audit automation
- Disaster recovery testing
- Cost optimization recommendations
- Partner mapping generation

---

**Last Updated**: October 4, 2025  
**Version**: 1.0  
**Maintainer**: Platform Engineering Team
