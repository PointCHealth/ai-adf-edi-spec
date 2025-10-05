# Architecture Clarification: Multi-Repository Strategy

**Date:** October 5, 2025  
**Change Type:** Documentation Consistency Update

## Summary

This document clarifies the repository architecture strategy for the EDI Healthcare Platform and documents the changes made to align all documentation.

## Architecture Decision: Five Strategic Repositories

The EDI Healthcare Platform follows a **multi-repository (polyrepo) strategy** with **five separate, independently deployable repositories**:

1. **edi-platform-core** - Core infrastructure, shared libraries, InboundRouter, EnterpriseScheduler
2. **edi-mappers** - All EDI transaction mapper functions (270/271, 834, 837, 835)
3. **edi-connectors** - Trading partner connector functions (SFTP, API, Database)
4. **edi-partner-configs** - Partner metadata, routing rules, mapping configurations
5. **edi-data-platform** - ADF pipelines and SQL databases

### Why NOT a Monorepo?

- **Independent deployment cycles** - Each repo can be versioned and deployed separately
- **Clear separation of concerns** - Infrastructure, mappers, connectors, configs, data pipelines are distinct
- **Team ownership boundaries** - Different teams can own different repositories
- **Reduced CI/CD complexity** - Smaller codebases = faster builds and deployments
- **Security isolation** - Partner configs and credentials in separate repo with stricter access control

### VS Code Multi-Root Workspace

While using **separate repositories**, developers use a **VS Code multi-root workspace** to work across all five repos simultaneously. This provides:
- Single VS Code window with all repositories
- Unified search and navigation across repos
- Shared workspace settings and extensions
- Cross-repository references and documentation

This is **NOT a monorepo** - it's a development convenience for working with multiple repositories.

## Changes Made

### 1. File Renamed

**Before:** `01-create-monorepo-structure.md`  
**After:** `01-create-strategic-repositories.md`

**Reason:** The filename incorrectly suggested a monorepo approach when the content clearly describes creating five separate strategic repositories.

### 2. Documentation Updates

#### INDEX.md
- Updated filename reference from `01-create-monorepo-structure.md` to `01-create-strategic-repositories.md`
- Updated tracking table from `01-monorepo` to `01-strategic-repos`
- Clarified architecture description as "Five strategic repositories"

#### README.md
- Updated filename reference in Section 1.2
- Fixed Azure AD setup to reference multiple repositories (not "edi-platform-monorepo")
- Updated deployment example to reference `edi-platform-core` repository
- Changed success criteria from "monorepo structure" to "Five strategic repositories created"

#### 02-create-codeowners.md
- Updated title to "Create CODEOWNERS Files for All Repositories" (plural)
- Changed prerequisite from "Monorepo structure created" to "Strategic repositories created"
- Enhanced prompt to explicitly create CODEOWNERS for EACH of the five repositories
- Added repository-specific ownership rules for:
  - edi-platform-core (infrastructure, shared libs, core functions)
  - edi-mappers (mapper functions, test data)
  - edi-connectors (connector functions, connection logic)
  - edi-partner-configs (partner configs, schemas, routing)
  - edi-data-platform (ADF pipelines, SQL schemas)
- Updated expected outcome to clarify files created in ALL FIVE repositories

#### 03-configure-github-variables.md
- Updated script execution path from `edi-platform-monorepo` to `edi-platform-core`

## Terminology Clarification

| Term | Meaning in This Project | NOT |
|------|-------------------------|-----|
| **Strategic Repositories** | Five separate Git repositories | A monorepo |
| **Multi-root Workspace** | VS Code workspace file (.code-workspace) | A monorepo |
| **Monorepo** | Single repository with multiple projects | What we're doing |
| **Polyrepo / Multi-repo** | Multiple separate repositories | ✅ Our approach |

## Impact on AI Prompts

All AI prompts now consistently:
1. Reference the correct filename (`01-create-strategic-repositories.md`)
2. Clarify they create FIVE separate repositories
3. Emphasize independence and separate deployment
4. Mention multi-root workspace as a development tool (not architecture)

## Developer Workflow

Developers will:
1. Clone all five repositories to a parent directory (e.g., `c:\repos\edi-platform\`)
2. Open the multi-root workspace file: `edi-platform.code-workspace`
3. Work across all repositories in a single VS Code window
4. Commit and push to individual repositories
5. Deploy repositories independently via their own CI/CD pipelines

## References

- Original architecture spec: `docs/01-architecture-spec.md` (correctly describes multi-repo approach)
- Implementation overview: `implementation-plan/00-implementation-overview.md`
- Prompt index: `implementation-plan/ai-prompts/INDEX.md`

## Questions & Clarifications

If you have questions about the repository strategy, contact:
- **Architecture Owner:** @vincemic
- **Platform Team:** @platform-team
- **GitHub Issues:** Use label `architecture-question`

---

**Last Updated:** October 5, 2025  
**Maintainer:** Platform Engineering Team
