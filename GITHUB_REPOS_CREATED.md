# GitHub Repositories Created - EDI Platform# GitHub Repositories Created - EDI Platform# GitHub Repositories Created - Summary



**Last Updated:** October 6, 2025  

**Organization:** PointCHealth  

**Total Repositories:** 9 active repositories**Last Updated:** January 15, 2025  **Date:** October 6, 2025  



## Summary**Organization:** PointCHealth  **Last Updated:** October 6, 2025  



This document tracks all GitHub repositories created for the EDI Platform implementation across multiple layers: Core Infrastructure, Integration Layer, Data Layer, and Configuration.**Total Repositories:** 9 (2 new, 7 existing)**Action:** Created and configured GitHub repositories for EDI platform projects  



## Repository Status Overview**Total Repositories:** 9 active repositories



| Repository | Status | GitHub URL | Last Commit |## Summary

|------------|--------|------------|-------------|

| edi-platform | ✅ Active | https://github.com/PointCHealth/edi-platform | 10 hours ago |---

| edi-platform-core | ✅ Active | https://github.com/PointCHealth/edi-platform-core | 10 hours ago |

| edi-sftp-connector | ✅ Active | https://github.com/PointCHealth/edi-sftp-connector | 3 hours ago |This document tracks all GitHub repositories created for the EDI Platform implementation across multiple layers: Core Infrastructure, Integration Layer, Data Layer, and Configuration.

| edi-connectors | ✅ Active | https://github.com/PointCHealth/edi-connectors | 17 hours ago |

| edi-database-controlnumbers | ✅ Active | https://github.com/PointCHealth/edi-database-controlnumbers | 12 hours ago |## Repository Status Overview

| edi-database-eventstore | ✅ Active | https://github.com/PointCHealth/edi-database-eventstore | 10 hours ago |

| edi-database-sftptracking | ✅ Active | https://github.com/PointCHealth/edi-database-sftptracking | 3 hours ago |## Repository Categories

| edi-mappers | ✅ Active | https://github.com/PointCHealth/edi-mappers | 17 hours ago |

| edi-partner-configs | ✅ Active | https://github.com/PointCHealth/edi-partner-configs | 19 hours ago || Repository | Status | GitHub URL | Last Commit |



---### Core Infrastructure (3 repositories)|------------|--------|------------|-------------|



## Repository Categories| edi-platform | ✅ Active | https://github.com/PointCHealth/edi-platform | 10 hours ago |



### Core Infrastructure (3 repositories)1. **edi-platform** - Workspace management| edi-platform-core | ✅ Active | https://github.com/PointCHealth/edi-platform-core | 10 hours ago |



1. **edi-platform** - Workspace management2. **edi-platform-core** - Shared libraries and domain models  | edi-sftp-connector | ✅ Active | https://github.com/PointCHealth/edi-sftp-connector | 3 hours ago |

2. **edi-platform-core** - Shared libraries and domain models

3. **edi-sftp-connector** - SFTP file ingestion3. **edi-sftp-connector** - SFTP file ingestion| edi-connectors | ✅ Active | https://github.com/PointCHealth/edi-connectors | 17 hours ago |



### Integration Layer (2 repositories)| edi-database-controlnumbers | ✅ Active | https://github.com/PointCHealth/edi-database-controlnumbers | 12 hours ago |



4. **edi-mappers** - Transaction type-specific mappers (834, 837, 270/271, 835)### Integration Layer (2 repositories)| edi-database-eventstore | ✅ Active | https://github.com/PointCHealth/edi-database-eventstore | 10 hours ago |

5. **edi-connectors** - External system integration connectors

| edi-database-sftptracking | ✅ Active | https://github.com/PointCHealth/edi-database-sftptracking | 3 hours ago |

### Data Layer (3 repositories)

4. **edi-mappers** - Transaction type-specific mappers (834, 837, 270/271, 835)| edi-mappers | ✅ Active | https://github.com/PointCHealth/edi-mappers | 17 hours ago |

6. **edi-database-controlnumbers** - X12 control number generation (DACPAC)

7. **edi-database-eventstore** - Event sourcing storage (DACPAC)5. **edi-connectors** - External system integration connectors| edi-partner-configs | ✅ Active | https://github.com/PointCHealth/edi-partner-configs | 19 hours ago |

8. **edi-database-sftptracking** - SFTP file tracking (EF Core migrations)



### Configuration (1 repository)

### Data Layer (3 repositories)---

9. **edi-partner-configs** - Trading partner JSON configurations



---

6. **edi-database-controlnumbers** - X12 control number generation (DACPAC)## Detailed Repository Information

## Detailed Repository Information

7. **edi-database-eventstore** - Event sourcing storage (DACPAC)

### 1. edi-platform

8. **edi-database-sftptracking** - SFTP file tracking (EF Core migrations)### 1. ✅ edi-database-eventstore

**GitHub URL:** https://github.com/PointCHealth/edi-platform



**Latest Commit:** `1e4446b - Initial commit: EDI Platform workspace setup scripts and templates (10 hours ago)`

### Configuration (1 repository)**Repository:** https://github.com/PointCHealth/edi-database-eventstore  

**Purpose:** Central workspace repository for multi-repository EDI platform development

**Visibility:** Private  

**Technology Stack:**

9. **edi-partner-configs** - Trading partner JSON configurations**Status:** ✅ Created and pushed successfully

- PowerShell scripts for workspace management

- Git workspace configuration

- Documentation templates

## Detailed Repository Information**Description:**

**Key Components:**

Event Store database schema using DACPAC (SQL Server Database Project) - replaced by EF Core migrations in ai-adf-edi-spec

- `setup-core.ps1` - Core repository cloning and configuration script

- `README.md` - Workspace setup and usage documentation### 1. edi-platform (NEW)

- `.github/` - GitHub Actions workflows for CI/CD

**Purpose:**

**Status:** ✅ Active development

**GitHub URL:** https://github.com/PointCHealth/edi-platform.git- Original DACPAC-based Event Store database schema

---

- Contains tables, views, stored procedures, and sequences

### 2. edi-platform-core

**Latest Commit:** `1e4446b - Initial commit: EDI Platform workspace setup scripts and templates (10 hours ago)`- Used as reference for EF Core migration implementation

**GitHub URL:** https://github.com/PointCHealth/edi-platform-core

- Retained for documentation and schema comparison

**Latest Commit:** `7db01b8 - feat: Add Partner Configuration System and EligibilityMapper tests (10 hours ago)`

**Purpose:** Central workspace repository for multi-repository EDI platform development

**Purpose:** Core shared libraries, domain models, and abstractions used across all EDI platform services

**Contents:**

**Technology Stack:**

**Technology Stack:**- 6 tables: DomainEvent, TransactionBatch, TransactionHeader, Member, Enrollment, EventSnapshot

- .NET 8

- C# 12- 6 views: Event stream, active enrollments, batch summary, member history, projection lag, statistics

- xUnit for testing

- NuGet package publishing- PowerShell scripts for workspace management- 8 stored procedures: Append event, get stream, snapshots, projections, reversal, replay



**Key Components:**- Git submodules or workspace configuration- 1 sequence: EventSequence



- Partner configuration system with validation- Documentation templates- SQL Server Database Project (.sqlproj)

- Eligibility mapper with comprehensive unit tests

- Shared utilities and helper classes

- Domain models: Transaction, Partner, ControlNumber, FileTracking

- Result pattern and common abstractions**Key Components:****Note:** This database schema has been replaced by EF Core migrations in the `ai-adf-edi-spec` repository. The EF Core approach provides better source control, easier deployment, and resolved build issues with the DACPAC SDK.



**Status:** ✅ Active development



---- `setup-core.ps1` - Core repository cloning and configuration script---



### 3. edi-sftp-connector- `README.md` - Workspace setup and usage documentation



**GitHub URL:** https://github.com/PointCHealth/edi-sftp-connector- `.github/` - GitHub Actions workflows for CI/CD### 2. ✅ edi-database-controlnumbers



**Latest Commit:** `b142100 - docs: Add partner configuration migration guide (3 hours ago)`



**Purpose:** SFTP file ingestion service for downloading/uploading partner files with tracking**Status:** ✅ Active development**Repository:** https://github.com/PointCHealth/edi-database-controlnumbers  



**Technology Stack:****Visibility:** Private  



- .NET 8 Azure Functions (Timer-triggered, Event Grid-triggered)---**Status:** ✅ Created and pushed successfully

- SSH.NET library for SFTP operations

- EF Core for file tracking database

- Azure Storage SDK for blob operations

### 2. edi-platform-core**Description:**

**Key Components:**

Control Numbers database schema using SQL Server Database Project (DACPAC) for X12 interchange/group/transaction control number management

- SFTP download function (timer-triggered)

- SFTP upload function (Event Grid-triggered)**GitHub URL:** https://github.com/PointCHealth/edi-platform-core.git

- Partner configuration integration

- File tracking database operations**Purpose:**

- Migration guide for partner configuration (recently added)

**Latest Commit:** `7db01b8 - feat: Add Partner Configuration System and EligibilityMapper tests (10 hours ago)`- Manages X12 control numbers for EDI transactions

**Database:** `edi-database-sftptracking` (EF Core Code-First)

- Ensures sequential, non-duplicate control numbers per partner

**Status:** ✅ Active development, recently updated documentation

**Purpose:** Core shared libraries, domain models, and abstractions used across all EDI platform services- Supports ISA, GS, and ST control number sequences

---

- Critical for EDI compliance and transaction tracking

### 4. edi-mappers

**Technology Stack:**

**GitHub URL:** https://github.com/PointCHealth/edi-mappers

**Contents:**

**Latest Commit:** `8fb7392 - Add transaction mapper function scaffolds (17 hours ago)`

- .NET 8- Tables for control number sequences

**Purpose:** Transaction type-specific mapping services for EDI X12 transactions

- C# 12- Stored procedures for control number generation

**Technology Stack:**

- xUnit for testing- Views for control number monitoring

- .NET 8 Azure Functions (Service Bus-triggered)

- X12 parsing libraries- NuGet package publishing- SQL Server Database Project (.sqlproj)

- Custom mapping logic per transaction type



**Key Components:**

**Key Components:****Status:** Successfully deployed and operational. This database remains as DACPAC since it has no build issues.

- **Mapper834** - Enrollment/benefit enrollment (834) mapper

- **Mapper837** - Healthcare claim (837) mapper

- **Mapper270271** - Eligibility inquiry/response (270/271) mapper

- **Mapper835** - Claims payment/remittance advice (835) mapper- Partner configuration system with validation---

- Mapper interfaces and base classes

- Function scaffolds (recently added)- Eligibility mapper with comprehensive unit tests



**Status:** ✅ Active development, scaffolds in place- Shared utilities and helper classes### 3. ✅ edi-platform



---- Domain models: Transaction, Partner, ControlNumber, FileTracking



### 5. edi-connectors- Result pattern and common abstractions**Repository:** https://github.com/PointCHealth/edi-platform  



**GitHub URL:** https://github.com/PointCHealth/edi-connectors**Visibility:** Private  



**Latest Commit:** `994ce3f - Add integration connector function scaffolds (17 hours ago)`**Status:** ✅ Active development**Status:** ✅ Created and pushed successfully



**Purpose:** Integration connectors for external system communication (outbound delivery)



**Technology Stack:**---**Description:**



- .NET 8 Azure Functions (Service Bus-triggered, HTTP-triggered)EDI Platform workspace with setup scripts, templates, and submodule references for multi-repo development environment

- HTTP clients for REST API integration

- Database connectors (ADO.NET, EF Core)### 3. edi-sftp-connector



**Key Components:****Purpose:**



- HTTP API connectors (REST, SOAP)**GitHub URL:** https://github.com/PointCHealth/edi-sftp-connector.git- Central workspace for multi-repository EDI platform development

- Database connectors (SQL Server, external DBs)

- File-based connectors (FTP, SFTP, file shares)- Contains setup scripts for repository initialization

- Integration function scaffolds (recently added)

**Latest Commit:** `b142100 - docs: Add partner configuration migration guide (3 hours ago)`- VS Code workspace configuration

**Status:** ✅ Active development, scaffolds in place

- Development environment templates

---

**Purpose:** SFTP file ingestion service for downloading/uploading partner files with tracking

### 6. edi-database-controlnumbers

**Contents:**

**GitHub URL:** https://github.com/PointCHealth/edi-database-controlnumbers

**Technology Stack:**- `setup-core.ps1` - PowerShell script for core repository setup

**Latest Commit:** `cb3e2cb - Initial commit: EDI Control Numbers Database (DACPAC) (12 hours ago)`

- `setup-structures.ps1` - Repository structure initialization

**Purpose:** X12 control number generation and tracking for ISA/GS/ST segments

- .NET 8 Azure Functions (Timer-triggered, Event Grid-triggered)- `edi-platform.code-workspace` - VS Code multi-root workspace

**Technology Stack:**

- SSH.NET library for SFTP operations- `.gitignore.template` - Git ignore template for EDI projects

- SQL Server Database Project (DACPAC)

- Stored procedures for atomic number generation- EF Core for file tracking database- Phase completion documentation

- Unique constraints for partner + type + direction

- Azure Storage SDK for blob operations- GitHub configuration scripts

**Database Objects:**



- **Table:** `ControlNumberSequence` - Stores current control numbers

  - Columns: PartnerId, ControlNumberType (ISA/GS/ST), Direction (Inbound/Outbound), CurrentValue, LastUpdated**Key Components:****Submodules referenced:**

  - Unique constraint: (PartnerId, ControlNumberType, Direction)

- edi-platform-core

- **Stored Procedure:** `usp_GetNextControlNumber` - Atomic increment and retrieval

  - Parameters: @PartnerId, @ControlNumberType, @Direction- SFTP download function (timer-triggered)- edi-mappers

  - Returns: Next control number with guaranteed uniqueness

- SFTP upload function (Event Grid-triggered)- edi-connectors

**Status:** ✅ Initial commit complete

- Partner configuration integration- edi-partner-configs

---

- File tracking database operations- edi-data-platform

### 7. edi-database-eventstore

- Migration guide for partner configuration (recently added)

**GitHub URL:** https://github.com/PointCHealth/edi-database-eventstore

**Use Case:** 

**Latest Commit:** `644edb2 - chore: Add original DACPAC Event Store database schema files (10 hours ago)`

**Database:** `edi-database-sftptracking` (EF Core Code-First)This workspace allows developers to work across multiple EDI repositories simultaneously with a single VS Code workspace. It streamlines onboarding and ensures consistent development environment setup.

**Purpose:** Event sourcing storage for domain events and event-driven architecture



**Technology Stack:**

**Status:** ✅ Active development, recently updated documentation---

- SQL Server Database Project (DACPAC)

- Event sourcing pattern

- Snapshot tables for projections

---

**Database Objects:**



- **Table:** `DomainEvent` - Event store (append-only)

  - Columns: EventId, AggregateId, EventType, EventData (JSON), Timestamp, Version### 4. edi-mappers## Repository Summary

  - Primary key: EventId (uniqueidentifier)

  - Clustered index: (AggregateId, Version)



- **Table:** `TransactionBatch` - Transaction batch aggregates**GitHub URL:** https://github.com/PointCHealth/edi-mappers.git### Total New Repositories: 4

- **Table:** `TransactionHeader` - Individual transaction headers

- **Table:** `Member` - Member entity projections

- **Table:** `Enrollment` - Enrollment entity projections

- **Table:** `EventSnapshot` - Snapshot storage for performance**Latest Commit:** `8fb7392 - Add transaction mapper function scaffolds (17 hours ago)`| Repository | Purpose | Language/Tech | Status |



**Status:** ✅ Repository created and pushed to GitHub|------------|---------|---------------|--------|



---**Purpose:** Transaction type-specific mapping services for EDI X12 transactions| edi-database-eventstore | Event Store DACPAC schema (deprecated) | SQL/DACPAC | ✅ Pushed |



### 8. edi-database-sftptracking| edi-database-controlnumbers | Control Numbers database | SQL/DACPAC | ✅ Pushed |



**GitHub URL:** https://github.com/PointCHealth/edi-database-sftptracking**Technology Stack:**| edi-platform | Workspace setup & templates | PowerShell/Config | ✅ Pushed |



**Latest Commit:** `1db63fb - feat: Initial commit - EDI SFTP Tracking database EF Core migrations (3 hours ago)`|



**Purpose:** SFTP file download/upload tracking for audit and idempotency- .NET 8 Azure Functions (Service Bus-triggered)### Previously Existing Repositories: 7



**Technology Stack:**- X12 parsing libraries



- EF Core Code-First migrations- Custom mapping logic per transaction typeThese repositories already had GitHub remotes and were previously pushed:

- .NET 8

- SQL Server



**Database Objects:****Key Components:**| Repository | Purpose | Last Updated |



- **Entity:** `FileTracking` - File download/upload records|------------|---------|--------------|

  - Properties: FileTrackingId, PartnerId, FileName, FilePath, FileSize, FileHash, Direction (Download/Upload), Status, ProcessedDate, CreatedDate, ModifiedDate

  - Indexes: (PartnerId, FileName, Direction), (FileHash), (ProcessedDate)- **Mapper834** - Enrollment/benefit enrollment (834) mapper| ai-adf-edi-spec | Specifications & planning | 3 minutes ago |



- **DbContext:** `SftpTrackingDbContext` - EF Core context- **Mapper837** - Healthcare claim (837) mapper  | edi-platform-core | Shared libraries & core functions | 2 minutes ago |

- **Migrations:** Code-First migration history

- **Mapper270271** - Eligibility inquiry/response (270/271) mapper| edi-partner-configs | Partner metadata | 8 hours ago |

**Status:** ✅ Initial commit complete

- **Mapper835** - Claims payment/remittance advice (835) mapper| edi-mappers | Transaction mappers | 7 hours ago |

---

- Mapper interfaces and base classes| edi-connectors | Partner connectors | 7 hours ago |

### 9. edi-partner-configs

- Function scaffolds (recently added)| edi-data-platform | ADF pipelines | 8 hours ago |

**GitHub URL:** https://github.com/PointCHealth/edi-partner-configs



**Latest Commit:** `d6173bc - chore: Add Dependabot configuration for automated dependency updates (19 hours ago)`

**Status:** ✅ Active development, scaffolds in place

**Purpose:** Trading partner JSON configuration files for centralized partner management

---

**Technology Stack:**

---

- JSON configuration files

- JSON schema validation## Complete Repository Inventory

- Dependabot for automated dependency updates (recently added)

### 5. edi-connectors

**Configuration Structure:**

### EDI Platform Ecosystem (11 repositories)

Each partner configuration file includes:

**GitHub URL:** https://github.com/PointCHealth/edi-connectors.git

- Partner identification (ID, name, type)

- SFTP connection settings (host, port, username, path)#### Core Infrastructure

- Transaction type support (834, 837, 270/271, 835)

- Routing rules (destination endpoints)**Latest Commit:** `994ce3f - Add integration connector function scaffolds (17 hours ago)`1. **edi-platform** ⭐ NEW

- Validation rules (schema, business rules)

- Schedule configuration (polling intervals, business hours)   - Workspace setup and templates



**Status:** ✅ Active development, Dependabot automation enabled**Purpose:** Integration connectors for external system communication (outbound delivery)   - https://github.com/PointCHealth/edi-platform



---



## Organization Structure**Technology Stack:**2. **edi-platform-core**



```   - Shared libraries and core functions

PointCHealth GitHub Organization

├── Core Infrastructure (3 repos)- .NET 8 Azure Functions (Service Bus-triggered, HTTP-triggered)   - https://github.com/PointCHealth/edi-platform-core

│   ├── edi-platform (workspace)

│   ├── edi-platform-core (shared libraries)- HTTP clients for REST API integration

│   └── edi-sftp-connector (ingestion)

├── Integration Layer (2 repos)- Database connectors (ADO.NET, EF Core)3. **ai-adf-edi-spec**

│   ├── edi-mappers (transaction mappers)

│   └── edi-connectors (external systems)   - Architecture specifications and planning

├── Data Layer (3 repos)

│   ├── edi-database-controlnumbers (DACPAC)**Key Components:**   - https://github.com/PointCHealth/ai-adf-edi-spec

│   ├── edi-database-eventstore (DACPAC)

│   └── edi-database-sftptracking (EF Core)

└── Configuration (1 repo)

    └── edi-partner-configs (JSON configs)- HTTP API connectors (REST, SOAP)#### Integration Layer

```

- Database connectors (SQL Server, external DBs)4. **edi-mappers**

---

- File-based connectors (FTP, SFTP, file shares)   - Transaction mapping functions (270/271, 834, 835, 837)

## Development Workflow

- Integration function scaffolds (recently added)   - https://github.com/PointCHealth/edi-mappers

**Multi-Repository Development:**



1. Clone workspace: `edi-platform`

2. Run `setup-core.ps1` to clone all core repositories**Status:** ✅ Active development, scaffolds in place5. **edi-connectors**

3. Each repository has independent CI/CD workflows

4. Shared libraries published as NuGet packages from `edi-platform-core`   - Partner connectivity (SFTP, HTTP, AS2)



**Branching Strategy:**---   - https://github.com/PointCHealth/edi-connectors



- `main` - Production-ready code

- `develop` - Integration branch for features

- `feature/*` - Feature branches### 6. edi-database-controlnumbers6. **edi-partner-configs**

- `hotfix/*` - Production hotfixes

   - Partner metadata and routing rules

**CI/CD:**

**GitHub URL:** https://github.com/PointCHealth/edi-database-controlnumbers.git   - https://github.com/PointCHealth/edi-partner-configs

- GitHub Actions workflows in each repository

- Automated testing on pull requests

- Automated deployment to Azure on merge to `main`

**Latest Commit:** `cb3e2cb - Initial commit: EDI Control Numbers Database (DACPAC) (12 hours ago)`#### Data Layer

---

7. **edi-data-platform**

## Action Items

**Purpose:** X12 control number generation and tracking for ISA/GS/ST segments   - Azure Data Factory pipelines

### Ongoing Maintenance

   - https://github.com/PointCHealth/edi-data-platform

1. **Dependabot Updates:**

   - All repositories should enable Dependabot (currently enabled in edi-partner-configs)**Technology Stack:**

   - Automated dependency updates for security patches

8. **edi-database-eventstore** ⭐ NEW

2. **Documentation:**

   - Keep README.md up-to-date in each repository- SQL Server Database Project (DACPAC)   - Event Store DACPAC schema (deprecated)

   - Add CONTRIBUTING.md for contribution guidelines

   - Add CODE_OF_CONDUCT.md for community standards- Stored procedures for atomic number generation   - https://github.com/PointCHealth/edi-database-eventstore



3. **Security:**- Unique constraints for partner + type + direction

   - Enable GitHub Advanced Security (if available)

   - Enable secret scanning9. **edi-database-controlnumbers** ⭐ NEW

   - Enable dependency vulnerability alerts

**Database Objects:**   - Control Numbers database

---

   - https://github.com/PointCHealth/edi-database-controlnumbers

## Repository Metrics (as of October 6, 2025)

- **Table:** `ControlNumberSequence` - Stores current control numbers

| Repository | Commits | Recent Activity | Status |

|------------|---------|-----------------|--------|  - Columns: PartnerId, ControlNumberType (ISA/GS/ST), Direction (Inbound/Outbound), CurrentValue, LastUpdated#### Utilities

| edi-platform | 1+ | 10 hours ago | ✅ Active |

| edi-platform-core | 10+ | 10 hours ago | ✅ Active |  - Unique constraint: (PartnerId, ControlNumberType, Direction)10. **ai-cvs-claim-parser** ⭐ NEW

| edi-sftp-connector | 20+ | 3 hours ago | ✅ Active |

| edi-mappers | 5+ | 17 hours ago | ✅ Active |      - CVS 837 claim parsing scripts

| edi-connectors | 5+ | 17 hours ago | ✅ Active |

| edi-database-controlnumbers | 1+ | 12 hours ago | ✅ Active |- **Stored Procedure:** `usp_GetNextControlNumber` - Atomic increment and retrieval    - https://github.com/PointCHealth/ai-cvs-claim-parser

| edi-database-eventstore | 5+ | 10 hours ago | ✅ Active |

| edi-database-sftptracking | 1+ | 3 hours ago | ✅ Active |  - Parameters: @PartnerId, @ControlNumberType, @Direction

| edi-partner-configs | 10+ | 19 hours ago | ✅ Active |

  - Returns: Next control number with guaranteed uniqueness

---

---

**Document Version:** 1.2  

**Last Updated:** October 6, 2025  **Status:** ✅ Initial commit complete

**Maintained By:** EDI Platform Team

## Git Remote Configuration

---

All local repositories now have proper GitHub remotes configured:

### 7. edi-database-eventstore

```bash

**GitHub URL:** https://github.com/PointCHealth/edi-database-eventstore# Event Store Database

cd C:\repos\edi-database-eventstore

**Latest Commit:** `644edb2 - chore: Add original DACPAC Event Store database schema files (10 hours ago)`git remote -v

# origin  https://github.com/PointCHealth/edi-database-eventstore.git

**Purpose:** Event sourcing storage for domain events and event-driven architecture

# Control Numbers Database

**Technology Stack:**cd C:\repos\edi-database-controlnumbers

git remote -v

- SQL Server Database Project (DACPAC)# origin  https://github.com/PointCHealth/edi-database-controlnumbers.git

- Event sourcing pattern

- Snapshot tables for projections# Platform Workspace

cd C:\repos\edi-platform

**Database Objects:**git remote -v

# origin  https://github.com/PointCHealth/edi-platform.git

- **Table:** `DomainEvent` - Event store (append-only)

  - Columns: EventId, AggregateId, EventType, EventData (JSON), Timestamp, Version```

  - Primary key: EventId (uniqueidentifier)

  - Clustered index: (AggregateId, Version)---

  

- **Table:** `TransactionBatch` - Transaction batch aggregates## Benefits of GitHub Migration

- **Table:** `TransactionHeader` - Individual transaction headers

- **Table:** `Member` - Member entity projections### 1. Source Control & History

- **Table:** `Enrollment` - Enrollment entity projections  - ✅ Full commit history preserved

- **Table:** `EventSnapshot` - Snapshot storage for performance- ✅ Ability to track changes over time

- ✅ Easy rollback to previous versions

**Status:** ⚠️ **Action Required** - Repository needs GitHub remote configuration and push

### 2. Collaboration

**Next Steps:**- ✅ Team members can clone and contribute

- ✅ Pull request workflows for code review

1. Create GitHub repository: `edi-database-eventstore`- ✅ Issue tracking and project management

2. Configure remote: `git remote add origin https://github.com/PointCHealth/edi-database-eventstore.git`

3. Push commits: `git push -u origin main`### 3. Backup & Recovery

- ✅ Remote backup of all code

---- ✅ Disaster recovery capability

- ✅ Access from any location

### 8. edi-database-sftptracking

### 4. CI/CD Integration

**GitHub URL:** https://github.com/PointCHealth/edi-database-sftptracking.git- ✅ GitHub Actions workflows ready to implement

- ✅ Automated testing and deployment

**Latest Commit:** `1db63fb - feat: Initial commit - EDI SFTP Tracking database EF Core migrations (3 hours ago)`- ✅ Integration with Azure services



**Purpose:** SFTP file download/upload tracking for audit and idempotency### 5. Documentation

- ✅ README files viewable on GitHub

**Technology Stack:**- ✅ Documentation rendered properly

- ✅ Easy navigation and discovery

- EF Core Code-First migrations

- .NET 8---

- SQL Server

## Next Steps

**Database Objects:**

### Immediate Actions

- **Entity:** `FileTracking` - File download/upload records

  - Properties: FileTrackingId, PartnerId, FileName, FilePath, FileSize, FileHash, Direction (Download/Upload), Status, ProcessedDate, CreatedDate, ModifiedDate1. **Update Documentation**

  - Indexes: (PartnerId, FileName, Direction), (FileHash), (ProcessedDate)   - Add repository URLs to main documentation

     - Update architecture diagrams with GitHub links

- **DbContext:** `SftpTrackingDbContext` - EF Core context   - Create README files for any repos missing them

- **Migrations:** Code-First migration history

2. **Configure Repository Settings**

**Status:** ✅ Initial commit complete   - Set up branch protection rules (require PR reviews)

   - Configure CODEOWNERS files

---   - Enable dependabot for dependency updates

   - Set up GitHub Actions workflows

### 9. edi-partner-configs

3. **Team Access**

**GitHub URL:** https://github.com/PointCHealth/edi-partner-configs.git   - Grant appropriate access levels to team members

   - Configure repository teams and permissions

**Latest Commit:** `d6173bc - chore: Add Dependabot configuration for automated dependency updates (19 hours ago)`   - Set up notification preferences



**Purpose:** Trading partner JSON configuration files for centralized partner management### Future Enhancements



**Technology Stack:**4. **CI/CD Pipelines**

   - Set up GitHub Actions for build and test

- JSON configuration files   - Configure automated deployments to Azure

- JSON schema validation   - Implement quality gates and code coverage

- Dependabot for automated dependency updates (recently added)

5. **Documentation**

**Configuration Structure:**   - Create comprehensive README files

   - Add architecture diagrams

Each partner configuration file includes:   - Document development workflows

   - Create contribution guidelines

- Partner identification (ID, name, type)

- SFTP connection settings (host, port, username, path)6. **Repository Cleanup**

- Transaction type support (834, 837, 270/271, 835)   - Consider archiving edi-database-eventstore (deprecated)

- Routing rules (destination endpoints)   - Add appropriate topics/tags to repositories

- Validation rules (schema, business rules)   - Create repository descriptions on GitHub web UI

- Schedule configuration (polling intervals, business hours)

---

**Status:** ✅ Active development, Dependabot automation enabled

## Migration Notes

---

### edi-database-eventstore

## Organization Structure- **Status:** Deprecated in favor of EF Core migrations

- **Action:** Mark as archived after EF Core migrations are deployed to Azure

```- **Reason:** Microsoft.Build.Sql DACPAC SDK has persistent build issues

PointCHealth GitHub Organization- **Replacement:** EF Core migrations in ai-adf-edi-spec repository

├── Core Infrastructure (3 repos)

│   ├── edi-platform (workspace) ⭐ NEW### edi-database-controlnumbers

│   ├── edi-platform-core (shared libraries)- **Status:** Active and operational

│   └── edi-sftp-connector (ingestion)- **Action:** Continue using DACPAC approach (no build issues)

├── Integration Layer (2 repos)- **Note:** Successfully deployed to Azure SQL

│   ├── edi-mappers (transaction mappers)

│   └── edi-connectors (external systems)### edi-platform

├── Data Layer (3 repos)- **Status:** Active workspace repository

│   ├── edi-database-controlnumbers (DACPAC)- **Contains:** Submodule references (not actual code)

│   ├── edi-database-eventstore (DACPAC)- **Note:** This is a meta-repository for developer workspace setup

│   └── edi-database-sftptracking (EF Core)

└── Configuration (1 repo)

    └── edi-partner-configs (JSON configs)---

```

## Repository Topology

## Development Workflow

```

**Multi-Repository Development:**PointCHealth Organization

│

1. Clone workspace: `edi-platform`├── EDI Platform Core

2. Run `setup-core.ps1` to clone all core repositories│   ├── edi-platform (workspace) ⭐ NEW

3. Each repository has independent CI/CD workflows│   ├── edi-platform-core (shared libs)

4. Shared libraries published as NuGet packages from `edi-platform-core`│   └── ai-adf-edi-spec (specs)

│

**Branching Strategy:**├── Integration Layer

│   ├── edi-mappers (transaction mapping)

- `main` - Production-ready code│   ├── edi-connectors (partner connectivity)

- `develop` - Integration branch for features│   └── edi-partner-configs (metadata)

- `feature/*` - Feature branches│

- `hotfix/*` - Production hotfixes├── Data Layer

│   ├── edi-data-platform (ADF pipelines)

**CI/CD:**│   ├── edi-database-eventstore (DACPAC - deprecated) ⭐ NEW

│   └── edi-database-controlnumbers (DACPAC - active) ⭐ NEW

- GitHub Actions workflows in each repository│

- Automated testing on pull requests---

- Automated deployment to Azure on merge to `main`

## Success Metrics

## Action Items

✅ **4 new repositories created**  

### Immediate Actions✅ **All local code now backed up to GitHub**  

✅ **Proper remote configuration for all repos**  

1. **⚠️ edi-database-eventstore Remote Setup:**✅ **Private visibility for all EDI repositories**  

   - Create GitHub repository✅ **Descriptive repository descriptions**  

   - Configure remote origin✅ **Initial commits with meaningful messages**  

   - Push existing commits

   - Update this document with GitHub URL---



### Ongoing Maintenance## Commands Used



2. **Dependabot Updates:**```powershell

   - All repositories should enable Dependabot (currently enabled in edi-partner-configs)# Create and push edi-database-eventstore

   - Automated dependency updates for security patchescd C:\repos\edi-database-eventstore

gh repo create PointCHealth/edi-database-eventstore --private --description "Event Store database schema using DACPAC (SQL Server Database Project) - replaced by EF Core migrations in ai-adf-edi-spec" --source=. --remote=origin --push

3. **Documentation:**

   - Keep README.md up-to-date in each repository# Create and push edi-database-controlnumbers

   - Add CONTRIBUTING.md for contribution guidelinescd C:\repos\edi-database-controlnumbers

   - Add CODE_OF_CONDUCT.md for community standardsgh repo create PointCHealth/edi-database-controlnumbers --private --description "Control Numbers database schema using SQL Server Database Project (DACPAC) for X12 interchange/group/transaction control number management" --source=. --remote=origin --push

git remote set-url origin https://github.com/PointCHealth/edi-database-controlnumbers.git

4. **Security:**git push -u origin main

   - Enable GitHub Advanced Security (if available)

   - Enable secret scanning# Initialize, create and push edi-platform

   - Enable dependency vulnerability alertscd C:\repos\edi-platform

git init

## Repository Metrics (as of January 15, 2025)git add .

git commit -m "Initial commit: EDI Platform workspace setup scripts and templates"

| Repository | Commits | Recent Activity | Status |gh repo create PointCHealth/edi-platform --private --description "EDI Platform workspace with setup scripts, templates, and submodule references for multi-repo development environment" --source=. --remote=origin --push

|------------|---------|-----------------|--------|

| edi-platform | 1+ | 10 hours ago | ✅ Active |# Initialize, create and push ai-cvs-claim-parser

| edi-platform-core | 10+ | 10 hours ago | ✅ Active |cd C:\repos\ai-cvs-claim-parser

| edi-sftp-connector | 20+ | 3 hours ago | ✅ Active |git init

| edi-mappers | 5+ | 17 hours ago | ✅ Active |git add .

| edi-connectors | 5+ | 17 hours ago | ✅ Active |git commit -m "Initial commit: CVS claim parser Python scripts for 837 transaction parsing and analysis"

| edi-database-controlnumbers | 1+ | 12 hours ago | ✅ Active |gh repo create PointCHealth/ai-cvs-claim-parser --private --description "Python scripts for parsing and analyzing CVS 837 claim transactions, including field position mapping and monetary validation" --source=. --remote=origin --push

| edi-database-eventstore | 5+ | 10 hours ago | ✅ Active |```

| edi-database-sftptracking | 1+ | 3 hours ago | ✅ Active |

| edi-partner-configs | 10+ | 19 hours ago | ✅ Active |---



---**Status:** ✅ All local EDI repositories now have GitHub remotes and are pushed



**Document Version:** 1.1  **Date Completed:** October 6, 2025

**Last Updated:** January 15, 2025  
**Maintained By:** EDI Platform Team
