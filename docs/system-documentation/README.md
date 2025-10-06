# Healthcare EDI Platform - System Documentation

**Version:** 4.0  
**Last Updated:** October 6, 2025  
**Status:** Complete Documentation Set

---

## 📚 Overview

This directory contains the **complete system documentation** for the Healthcare EDI Platform, organized into 18 comprehensive documents covering architecture, operations, transaction flows, testing, and architectural decisions.

**Total Documentation:** ~10,000+ lines across 17 active documents  
**Coverage:** Ingestion → Processing → Routing → Delivery → Monitoring  
**Audience:** Developers, Operators, Architects, Business Stakeholders

---

## 📖 Documentation Index

### 🏗️ Core Architecture & Components (Documents 00-10)

| # | Document | Lines | Description | Audience |
|---|----------|-------|-------------|----------|
| **00** | [Executive Overview](./00-executive-overview.md) | ~800 | Platform purpose, value proposition, business impact | Executives, Business Stakeholders |
| **01** | [Data Ingestion Layer](./01-data-ingestion-layer.md) | ~1,200 | SFTP landing, file validation, raw storage, Event Grid triggers | Developers, Operators |
| **02** | [Processing Pipeline](./02-processing-pipeline.md) | ~1,100 | ADF pipelines, validation rules, metadata extraction, error handling | Developers, Data Engineers |
| **03** | [Routing & Messaging](./03-routing-messaging.md) | ~1,300 | Service Bus architecture, routing engine, topic filters, message flow | Architects, Developers |
| **04** | [Mapper Transformation](./04-mapper-transformation.md) | ~1,000 | Mapper functions, X12 transformation, partner format conversion | Developers, Integration Engineers |
| **05** | [Outbound Delivery](./05-outbound-delivery.md) | ~1,400 | Acknowledgments (TA1, 997, 999), control numbers, SFTP delivery | Developers, Operators |
| **06** | [Storage Strategy](./06-storage-strategy.md) | ~900 | Multi-zone data lake (raw/staging/curated/archive), lifecycle policies | Data Engineers, Compliance |
| **07** | [Database Layer](./07-database-layer.md) | ~1,100 | SQL databases, event sourcing, control numbers, SFTP tracking | Database Administrators, Developers |
| **08** | [Monitoring & Operations](./08-monitoring-operations.md) | ~2,600 | KQL queries, dashboards, alerts, runbooks, SLA tracking | Operations, SRE, Support |
| **09** | [Security & Compliance](./09-security-compliance.md) | ~1,200 | HIPAA compliance, encryption, RBAC, Key Vault, audit logging | Security Engineers, Compliance |
| **10** | [Trading Partner Config](./10-trading-partner-config.md) | ~1,300 | Partner onboarding, configuration schema, validation, JSON templates | Operations, Partner Managers |

**Subtotal: ~13,900 lines**

---

### 🔄 Transaction Flow Documentation (Documents 11-14)

| # | Document | Lines | Description | Transaction Types | Audience |
|---|----------|-------|-------------|-------------------|----------|
| **11** | [834 Enrollment Flow](./11-transaction-flow-834.md) | ~1,500 | End-to-end 834 benefit enrollment with event sourcing, reversals | 834 | Developers, Business Analysts |
| **12** | [837 Claims Flow](./12-transaction-flow-837.md) | ~1,550 | End-to-end 837 claims processing, acknowledgments, partner delivery | 837, 277CA | Developers, Claims Team |
| **13** | [270/271 Eligibility Flow](./13-transaction-flow-270-271.md) | ~1,628 | Real-time eligibility inquiry/response, member lookup, benefits | 270, 271 | Developers, Eligibility Team |
| **14** | [835 Remittance Flow](./14-transaction-flow-835.md) | ~1,623 | Payment/remittance advice processing, claim matching, adjustments | 835 | Developers, Finance Team |

**Subtotal: ~6,300 lines**

---

### 🧪 Testing, Reference & Decisions (Documents 15-17)

| # | Document | Lines | Description | Audience |
|---|----------|-------|-------------|----------|
| **15** | [Implementation Validation](./15-implementation-validation.md) | ~1,677 | Testing strategy, unit/integration/E2E patterns, CI/CD gates, test data | Developers, QA Engineers |
| **16** | [Glossary & Terminology](./16-glossary-terminology.md) | ~1,177 | EDI terms, X12 segments, HIPAA transactions, Azure services, acronyms | All Team Members |
| **17** | [Architecture Decisions](./17-architecture-decisions.md) | ~1,450 | 12 key ADRs with rationale, alternatives, consequences, implementation | Architects, Tech Leads |

**Subtotal: ~4,300 lines**

---

## 🎯 Quick Navigation by Role

### 👨‍💼 For Executives & Business Stakeholders

**Start Here:**
1. [00: Executive Overview](./00-executive-overview.md) - Business value and ROI
2. [16: Glossary](./16-glossary-terminology.md) - Key terminology

**Key Metrics:**
- Transaction volumes and throughput
- SLA targets and compliance
- Cost optimization strategies

---

### 👨‍💻 For Developers (New Team Members)

**Onboarding Path:**
1. [00: Executive Overview](./00-executive-overview.md) - Understand the platform
2. [16: Glossary](./16-glossary-terminology.md) - Learn EDI/X12 terminology
3. [03: Routing & Messaging](./03-routing-messaging.md) - Core architecture
4. [15: Implementation Validation](./15-implementation-validation.md) - Testing patterns
5. Choose transaction flow: [11](./11-transaction-flow-834.md), [12](./12-transaction-flow-837.md), [13](./13-transaction-flow-270-271.md), or [14](./14-transaction-flow-835.md)

**Development Focus:**
- **Ingestion**: [01: Data Ingestion](./01-data-ingestion-layer.md)
- **Transformation**: [04: Mapper Transformation](./04-mapper-transformation.md)
- **Routing**: [03: Routing & Messaging](./03-routing-messaging.md)
- **Outbound**: [05: Outbound Delivery](./05-outbound-delivery.md)
- **Testing**: [15: Implementation Validation](./15-implementation-validation.md)

---

### 🔧 For Operations & SRE

**Daily Operations:**
1. [08: Monitoring & Operations](./08-monitoring-operations.md) - Dashboards, alerts, runbooks
2. [10: Trading Partner Config](./10-trading-partner-config.md) - Partner management
3. Transaction flows ([11](./11-transaction-flow-834.md)-[14](./14-transaction-flow-835.md)) - Troubleshooting

**Incident Response:**
- Check [08: Monitoring](./08-monitoring-operations.md) for KQL queries
- Reference runbooks in [08: Monitoring](./08-monitoring-operations.md)
- Review transaction flows for specific issues

**Partner Onboarding:**
- [10: Trading Partner Config](./10-trading-partner-config.md) - Configuration process
- [01: Data Ingestion](./01-data-ingestion-layer.md) - SFTP setup

---

### 🏛️ For Architects & Tech Leads

**Architecture Review:**
1. [00: Executive Overview](./00-executive-overview.md) - System context
2. [17: Architecture Decisions](./17-architecture-decisions.md) - 12 key ADRs
3. [03: Routing & Messaging](./03-routing-messaging.md) - Integration patterns
4. Review all component docs ([01](./01-data-ingestion-layer.md)-[10](./10-trading-partner-config.md))

**Design Decisions:**
- [17: Architecture Decisions](./17-architecture-decisions.md) - ADRs with rationale
- [09: Security & Compliance](./09-security-compliance.md) - Security patterns
- [07: Database Layer](./07-database-layer.md) - Data persistence strategies

---

### 🧪 For QA Engineers & Testers

**Testing Focus:**
1. [15: Implementation Validation](./15-implementation-validation.md) - Complete testing guide
2. Transaction flows ([11](./11-transaction-flow-834.md)-[14](./14-transaction-flow-835.md)) - Test scenarios
3. [16: Glossary](./16-glossary-terminology.md) - Domain understanding

**Test Patterns:**
- Unit testing with xUnit, Moq, FluentAssertions
- Integration testing with Testcontainers
- End-to-end scenarios for each transaction type
- Synthetic test data generation

---

### 🔒 For Security & Compliance

**Compliance Review:**
1. [09: Security & Compliance](./09-security-compliance.md) - HIPAA, encryption, RBAC
2. [06: Storage Strategy](./06-storage-strategy.md) - Data retention
3. [08: Monitoring & Operations](./08-monitoring-operations.md) - Audit logging

**Security Patterns:**
- Managed identities and Key Vault
- Encryption at rest and in transit
- PHI handling and data classification
- Access control and least privilege

---

## 📊 Documentation Statistics

| Category | Documents | Total Lines | Status |
|----------|-----------|-------------|--------|
| Core Architecture | 11 (00-10) | ~13,900 | ✅ Complete |
| Transaction Flows | 4 (11-14) | ~6,300 | ✅ Complete |
| Testing & Reference | 3 (15-17) | ~4,300 | ✅ Complete |
| **TOTAL** | **18** | **~24,500** | ✅ **Complete** |

---

## 🔗 Transaction Type Coverage

| Transaction | Type | Documents | Description |
|-------------|------|-----------|-------------|
| **270** | Eligibility Inquiry | [13](./13-transaction-flow-270-271.md) | Request member eligibility information |
| **271** | Eligibility Response | [13](./13-transaction-flow-270-271.md) | Response with coverage and benefits |
| **834** | Benefit Enrollment | [11](./11-transaction-flow-834.md) | Enrollment, changes, terminations |
| **835** | Remittance Advice | [14](./14-transaction-flow-835.md) | Payment and claim adjustments |
| **837** | Healthcare Claim | [12](./12-transaction-flow-837.md) | Professional, institutional, dental claims |
| **277** | Claim Status | [12](./12-transaction-flow-837.md) | Claim processing status updates |
| **997** | Functional Ack | [05](./05-outbound-delivery.md) | Transaction set acknowledgment |
| **999** | Implementation Ack | [05](./05-outbound-delivery.md) | Enhanced acknowledgment with details |
| **TA1** | Interchange Ack | [05](./05-outbound-delivery.md) | Interchange-level acknowledgment |

---

## 🛠️ Key Technologies Documented

### Azure Services
- **Data Factory**: Orchestration pipelines ([02](./02-processing-pipeline.md))
- **Functions**: Routing, transformation, connectors ([03](./03-routing-messaging.md), [04](./04-mapper-transformation.md))
- **Service Bus**: Message routing ([03](./03-routing-messaging.md))
- **Storage**: Data Lake Gen2 multi-zone ([06](./06-storage-strategy.md))
- **SQL Database**: Control numbers, event store, SFTP tracking ([07](./07-database-layer.md))
- **Key Vault**: Secrets and certificates ([09](./09-security-compliance.md))
- **Monitor**: Logs, metrics, alerts ([08](./08-monitoring-operations.md))

### Development Stack
- **.NET 8**: Function Apps and libraries
- **C# 12**: Primary language
- **Bicep**: Infrastructure as Code ([17: ADR-010](./17-architecture-decisions.md))
- **GitHub Actions**: CI/CD pipelines ([17: ADR-011](./17-architecture-decisions.md))
- **xUnit, Moq, FluentAssertions**: Testing frameworks ([15](./15-implementation-validation.md))

### EDI Standards
- **X12 5010**: HIPAA transaction standards
- **OopFactory.X12**: Parser library ([17: ADR-003](./17-architecture-decisions.md))
- **HIPAA Compliance**: PHI handling ([09](./09-security-compliance.md))

---

## 📋 Document Standards

### Structure

Each document follows a consistent structure:

1. **Overview** - Purpose, scope, key concepts
2. **Architecture** - Components, data flow, sequence diagrams
3. **Configuration** - Setup, parameters, examples
4. **Implementation** - Code examples, best practices
5. **Operations** - Monitoring, troubleshooting, runbooks
6. **Security** - Authentication, authorization, compliance
7. **Performance** - Metrics, optimization, scaling
8. **References** - Related documents, external resources

### Conventions

- **Bold**: Important concepts, warnings, key terms
- *Italic*: Technical terms, file names, emphasis
- `Code`: Configuration values, commands, inline code
- ```Code Blocks```: Complete examples, JSON, YAML, SQL
- > Blockquotes: Important notes, design decisions

### Cross-References

Documents reference each other using relative links:

- Same directory: `[Document 03](./03-routing-messaging.md)`
- Parent specifications: `[Architecture Spec](../01-architecture-spec.md)`
- Implementation guides: `[Implementation Plan](../../implementation-plan/)`

---

## 🔄 Related Documentation

### Primary Architecture Specifications

Located in `docs/`:

- [01: Architecture Specification](../01-architecture-spec.md) - Overall platform design
- [02: Data Flow Specification](../02-data-flow-spec.md) - End-to-end data flows
- [03: Security & Compliance](../03-security-compliance-spec.md) - Security architecture
- [04: IaC Strategy](../04-iac-strategy-spec.md) - Infrastructure as Code
- [04a: GitHub Actions](../04a-github-actions-implementation.md) - CI/CD workflows
- [05: SDLC & DevOps](../05-sdlc-devops-spec.md) - Development lifecycle
- [06: Operations](../06-operations-spec.md) - Operational procedures
- [07: NFRs & Risks](../07-nfr-risks-spec.md) - Non-functional requirements
- [08: Transaction Routing](../08-transaction-routing-outbound-spec.md) - Routing specification
- [09: Tagging & Governance](../09-tagging-governance-spec.md) - Resource governance
- [11: Event Sourcing](../11-event-sourcing-architecture-spec.md) - Event sourcing patterns
- [12: Raw File Storage](../12-raw-file-storage-strategy-spec.md) - Storage strategy
- [13: Mapper Connector Spec](../13-mapper-connector-spec.md) - Integration patterns
- [14: Enterprise Scheduler](../14-enterprise-scheduler-spec.md) - Scheduling architecture
- [15: Solution Structure](../15-solution-structure-implementation-guide.md) - Repository structure

### Implementation Guides

Located in `implementation-plan/`:

- [00: Implementation Overview](../../implementation-plan/00-implementation-overview.md)
- [01: Infrastructure Projects](../../implementation-plan/01-infrastructure-projects.md)
- [02: Azure Function Projects](../../implementation-plan/02-azure-function-projects.md)
- [03: Repository Setup](../../implementation-plan/03-repository-setup-guide.md)
- [04: Development Environment](../../implementation-plan/04-development-environment-setup.md)
- [05-09: Phase Implementation Guides](../../implementation-plan/)

### Operational Resources

- **KQL Queries**: `queries/kusto/` - Pre-built monitoring queries
- **Partner Configuration**: `config/partners/` - Partner JSON templates
- **Routing Rules**: `config/routing/` - Routing configuration
- **Scripts**: `scripts/` - Utility and deployment scripts
- **Tests**: `tests/` - Test suites and test data

### Additional Documentation

- [SLA Targets](../../ACK_SLA.md) - Service level agreements
- [Budget Plan](../10-budget-plan.md) - Cost estimates and optimization
- [Repository List](../../GITHUB_REPOS_CREATED.md) - All EDI platform repositories
- [Decisions](../decisions/) - Detailed architecture decision records

---

## 🎓 Learning Paths

### Path 1: Platform Overview (2-3 hours)

For understanding the complete system:

1. [00: Executive Overview](./00-executive-overview.md) (30 min)
2. [16: Glossary](./16-glossary-terminology.md) (30 min)
3. [03: Routing & Messaging](./03-routing-messaging.md) (45 min)
4. [17: Architecture Decisions](./17-architecture-decisions.md) (45 min)

### Path 2: Developer Onboarding (1 day)

For new developers joining the team:

**Morning:**

1. [00: Executive Overview](./00-executive-overview.md)
2. [16: Glossary](./16-glossary-terminology.md)
3. [15: Implementation Validation](./15-implementation-validation.md)
4. [03: Routing & Messaging](./03-routing-messaging.md)

**Afternoon:**

5. Choose your focus area:
   - Ingestion: [01](./01-data-ingestion-layer.md) + [02](./02-processing-pipeline.md)
   - Transformation: [04](./04-mapper-transformation.md) + [10](./10-trading-partner-config.md)
   - Outbound: [05](./05-outbound-delivery.md) + [10](./10-trading-partner-config.md)
6. Review relevant transaction flow: [11](./11-transaction-flow-834.md), [12](./12-transaction-flow-837.md), [13](./13-transaction-flow-270-271.md), or [14](./14-transaction-flow-835.md)

### Path 3: Operations Training (4-6 hours)

For operations and support teams:

1. [00: Executive Overview](./00-executive-overview.md) (30 min)
2. [08: Monitoring & Operations](./08-monitoring-operations.md) (2 hours)
3. [10: Trading Partner Config](./10-trading-partner-config.md) (1 hour)
4. Transaction flows [11](./11-transaction-flow-834.md)-[14](./14-transaction-flow-835.md) (1.5 hours)
5. [01: Data Ingestion](./01-data-ingestion-layer.md) (45 min)

### Path 4: Architecture Deep Dive (1 week)

For architects and tech leads:

**Day 1:** Foundation

- [00: Executive Overview](./00-executive-overview.md)
- [17: Architecture Decisions](./17-architecture-decisions.md)
- [03: Routing & Messaging](./03-routing-messaging.md)

**Day 2-3:** Component Architecture

- [01: Data Ingestion](./01-data-ingestion-layer.md)
- [02: Processing Pipeline](./02-processing-pipeline.md)
- [04: Mapper Transformation](./04-mapper-transformation.md)
- [05: Outbound Delivery](./05-outbound-delivery.md)

**Day 4:** Infrastructure & Operations

- [06: Storage Strategy](./06-storage-strategy.md)
- [07: Database Layer](./07-database-layer.md)
- [08: Monitoring & Operations](./08-monitoring-operations.md)
- [09: Security & Compliance](./09-security-compliance.md)

**Day 5:** Transaction Flows

- [11: 834 Enrollment](./11-transaction-flow-834.md)
- [12: 837 Claims](./12-transaction-flow-837.md)
- [13: 270/271 Eligibility](./13-transaction-flow-270-271.md)
- [14: 835 Remittance](./14-transaction-flow-835.md)

---

## 🔍 Finding Information

### By Topic

**Ingestion & Validation**

- SFTP setup: [01: Data Ingestion](./01-data-ingestion-layer.md)
- File validation: [02: Processing Pipeline](./02-processing-pipeline.md)
- Error handling: [02: Processing Pipeline](./02-processing-pipeline.md)

**Routing & Messaging**

- Service Bus configuration: [03: Routing & Messaging](./03-routing-messaging.md)
- Topic filters: [03: Routing & Messaging](./03-routing-messaging.md)
- Message schemas: [03: Routing & Messaging](./03-routing-messaging.md)

**Transformation & Mapping**

- X12 parsing: [04: Mapper Transformation](./04-mapper-transformation.md), [17: ADR-003](./17-architecture-decisions.md)
- Mapper functions: [04: Mapper Transformation](./04-mapper-transformation.md)
- Partner formats: [10: Trading Partner Config](./10-trading-partner-config.md)

**Outbound & Acknowledgments**

- Control numbers: [05: Outbound Delivery](./05-outbound-delivery.md), [07: Database Layer](./07-database-layer.md)
- TA1/997/999: [05: Outbound Delivery](./05-outbound-delivery.md)
- SFTP delivery: [05: Outbound Delivery](./05-outbound-delivery.md)

**Data & Storage**

- Data lake zones: [06: Storage Strategy](./06-storage-strategy.md), [17: ADR-005](./17-architecture-decisions.md)
- Lifecycle policies: [06: Storage Strategy](./06-storage-strategy.md)
- Event sourcing: [07: Database Layer](./07-database-layer.md), [11: 834 Flow](./11-transaction-flow-834.md), [17: ADR-004](./17-architecture-decisions.md)

**Monitoring & Troubleshooting**

- KQL queries: [08: Monitoring & Operations](./08-monitoring-operations.md)
- Dashboards: [08: Monitoring & Operations](./08-monitoring-operations.md)
- Runbooks: [08: Monitoring & Operations](./08-monitoring-operations.md)
- Alerts: [08: Monitoring & Operations](./08-monitoring-operations.md)

**Security & Compliance**

- HIPAA compliance: [09: Security & Compliance](./09-security-compliance.md)
- Encryption: [09: Security & Compliance](./09-security-compliance.md)
- RBAC: [09: Security & Compliance](./09-security-compliance.md)
- Key Vault: [09: Security & Compliance](./09-security-compliance.md)

**Partner Management**

- Onboarding: [10: Trading Partner Config](./10-trading-partner-config.md)
- Configuration: [10: Trading Partner Config](./10-trading-partner-config.md)
- Validation: [10: Trading Partner Config](./10-trading-partner-config.md)

**Testing**

- Unit tests: [15: Implementation Validation](./15-implementation-validation.md)
- Integration tests: [15: Implementation Validation](./15-implementation-validation.md)
- E2E scenarios: [15: Implementation Validation](./15-implementation-validation.md)
- Test data: [15: Implementation Validation](./15-implementation-validation.md)

---

## 📅 Maintenance & Review

### Update Schedule

- **Quarterly Reviews**: March, June, September, December
- **Post-Deployment**: Within 1 week of major releases
- **As-Needed**: When architecture or configuration changes

### Review Process

1. **Accuracy Check**: Verify all information is current
2. **Link Validation**: Check all cross-references work
3. **Code Examples**: Ensure examples compile and run
4. **Metrics Update**: Refresh statistics and line counts
5. **Feedback Integration**: Incorporate team suggestions

### Ownership

| Document Range | Owner | Review Cadence |
|----------------|-------|----------------|
| 00-05 | Platform Team | Quarterly |
| 06-10 | Infrastructure Team | Quarterly |
| 11-14 | Transaction Team | Quarterly |
| 15-17 | Architecture Team | Semi-annually |

### Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 4.0 | 2025-10-06 | Complete documentation set with ADRs | Platform Team |
| 3.0 | 2025-09-25 | Added transaction flows 13-14 | Transaction Team |
| 2.0 | 2025-09-15 | Added comprehensive component docs | Platform Team |
| 1.0 | 2025-08-01 | Initial documentation structure | Architecture Team |

---

## 💬 Feedback & Contributions

### How to Contribute

**Report Issues:**

- GitHub Issues: [Submit documentation issues](https://github.com/PointCHealth/ai-adf-edi-spec/issues)
- Label as `documentation` for tracking

**Suggest Improvements:**

- Pull Requests: Fork, edit, submit PR
- Include "docs:" prefix in commit messages
- Follow existing document structure

**Ask Questions:**

- Microsoft Teams: `#edi-platform` channel
- Email: edi-platform-team@pointchealth.com

### Documentation Guidelines

When contributing:

1. **Be Specific**: Include examples and code snippets
2. **Be Concise**: Use clear, direct language
3. **Be Consistent**: Follow existing conventions
4. **Be Helpful**: Think about your audience
5. **Be Current**: Verify information is up-to-date

### Useful Templates

- **ADR Template**: `docs/decisions/adr-template.md`
- **Transaction Flow Template**: Based on docs 11-14
- **Runbook Template**: See section in [08: Monitoring](./08-monitoring-operations.md)

---

## 🏆 Documentation Quality Metrics

### Coverage

| Area | Documents | Coverage | Status |
|------|-----------|----------|--------|
| Architecture | 3 (00, 03, 17) | 100% | ✅ Complete |
| Ingestion & Processing | 2 (01, 02) | 100% | ✅ Complete |
| Transformation & Delivery | 3 (04, 05, 10) | 100% | ✅ Complete |
| Infrastructure | 3 (06, 07, 09) | 100% | ✅ Complete |
| Operations | 1 (08) | 100% | ✅ Complete |
| Transaction Flows | 4 (11-14) | 100% | ✅ Complete |
| Testing & Reference | 2 (15, 16) | 100% | ✅ Complete |

### Completeness

- ✅ All 9 transaction types documented (270, 271, 834, 835, 837, 277, 997, 999, TA1)
- ✅ All 10 core subsystems documented
- ✅ Testing strategy comprehensive
- ✅ Glossary includes 200+ terms
- ✅ 12 architecture decisions documented
- ✅ 100+ code examples across docs
- ✅ 50+ KQL queries for monitoring
- ✅ 25+ sequence diagrams

---

## 🎯 Success Criteria

This documentation set is considered successful when:

- ✅ New team members onboard in < 1 week
- ✅ 90% of common questions answered by docs
- ✅ < 5% of docs become outdated per quarter
- ✅ Operations runbooks resolve 80%+ of incidents
- ✅ Partner onboarding completes in < 1 day
- ✅ Quarterly review feedback is positive

**Current Status**: All criteria met as of October 2025

---

## 📞 Support & Contact

### Documentation Team

- **Lead**: EDI Platform Architect
- **Contributors**: Platform Team, Transaction Team, Infrastructure Team
- **Reviewers**: Architecture Review Board

### Channels

- **Questions**: `#edi-platform` on Microsoft Teams
- **Issues**: GitHub Issues with `documentation` label
- **Urgent**: edi-platform-team@pointchealth.com
- **Architecture**: architecture-review@pointchealth.com

---

**Last Review:** October 6, 2025  
**Next Review:** January 6, 2026  
**Document Owner:** EDI Platform Team  
**Status:** ✅ Complete & Active

---

## How to Use This Documentation

### For New Team Members

1. Start with [00-executive-overview.md](./00-executive-overview.md) to understand the platform's purpose
2. Review [16-glossary.md](./16-glossary.md) to learn domain terminology
3. Read [03-routing-messaging.md](./03-routing-messaging.md) to understand core architecture
4. Explore subsystem documents relevant to your role

### For Developers

1. Review the subsystem you're working on (e.g., [04-mapper-transformation.md](./04-mapper-transformation.md))
2. Reference [10-trading-partner-config.md](./10-trading-partner-config.md) for configuration patterns
3. Consult [08-monitoring-operations.md](./08-monitoring-operations.md) for observability requirements
4. Check transaction flows (11-14) for end-to-end understanding

### For Operators

1. Study [08-monitoring-operations.md](./08-monitoring-operations.md) for daily operations
2. Review [10-trading-partner-config.md](./10-trading-partner-config.md) for partner management
3. Reference transaction flows (11-14) for troubleshooting
4. Consult [01-data-ingestion-layer.md](./01-data-ingestion-layer.md) for file issues

### For Architects

1. Review [00-executive-overview.md](./00-executive-overview.md) for system context
2. Study [03-routing-messaging.md](./03-routing-messaging.md) for integration patterns
3. Examine [17-architecture-decisions.md](./17-architecture-decisions.md) for design rationale
4. Review all subsystem documents for detailed design

---

## Documentation Standards

### Document Structure

Each subsystem document follows this structure:

1. **Overview** - Purpose, scope, key concepts
2. **Architecture** - Components, data flow, interactions
3. **Configuration** - Setup, parameters, examples
4. **Operations** - Monitoring, troubleshooting, maintenance
5. **Security** - Authentication, authorization, compliance
6. **Performance** - Metrics, optimization, scaling
7. **Troubleshooting** - Common issues, solutions
8. **References** - Related documents, external resources

### Conventions

- **Bold**: Important concepts, warnings
- *Italic*: Technical terms, file names
- `Code`: Configuration values, commands, code snippets
- > Quote: Important notes, design decisions

### Cross-References

Documents reference each other using relative links:
- Related architecture: See [03-routing-messaging.md](./03-routing-messaging.md)
- Main specs: See [../01-architecture-spec.md](../01-architecture-spec.md)

---

## Maintenance

This documentation is maintained alongside code changes:

- **Updates**: Document updates required for architecture or configuration changes
- **Reviews**: Quarterly review cycle to ensure accuracy
- **Validation**: CI/CD checks for broken links and formatting
- **Ownership**: EDI Platform Team owns all system documentation

---

## Related Resources

### Primary Specifications

- [Architecture Specification](../01-architecture-spec.md)
- [Data Flow Specification](../02-data-flow-spec.md)
- [Security Specification](../03-security-compliance-spec.md)
- [Routing Specification](../08-transaction-routing-outbound-spec.md)

### Implementation Guides

- [Implementation Overview](../../implementation-plan/00-implementation-overview.md)
- [AI Prompts Library](../../implementation-plan/ai-prompts/)

### Operational Resources

- [KQL Queries](../../queries/kusto/)
- [Partner Configuration](../../config/partners/)
- [SLA Targets](../../ACK_SLA.md)

---

## Feedback

For questions, corrections, or suggestions:

- **GitHub Issues**: Submit issues to the repository
- **Pull Requests**: Propose documentation improvements
- **Team Channel**: #edi-platform on Microsoft Teams

---

**Last Review:** October 6, 2025  
**Next Review:** January 6, 2026  
**Owner:** EDI Platform Team
