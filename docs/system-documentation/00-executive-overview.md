# Healthcare EDI Platform - Executive Overview

**Version:** 3.0  
**Last Updated:** October 6, 2025  
**Document Owner:** EDI Platform Lead  
**Status:** Production Specification

---

## Platform Purpose

The Healthcare EDI Platform is a **HIPAA-aligned, event-driven Azure solution** that enables secure, scalable, and compliant exchange of healthcare electronic data interchange (EDI) transactions between trading partners.

### What It Does

The platform processes X12 EDI files through a complete lifecycle:

```text
External Partners → Ingestion → Validation → Routing → Processing → Acknowledgment → Delivery
```

### Transaction Types Supported

| Transaction | Type | Purpose | Example Partners |
|-------------|------|---------|------------------|
| **837** | Claims | Healthcare claims submission | Payers, Clearinghouses |
| **834** | Enrollment | Member enrollment and maintenance | Health Plans, Employers |
| **270/271** | Eligibility | Real-time eligibility inquiries and responses | Providers, Payers |
| **835** | Remittance | Payment and remittance advice | Payers, Providers |
| **276/277** | Status | Claim status inquiries and responses | Providers, Payers |
| **278** | Auth | Prior authorization requests | Providers, Payers |
| **999/TA1** | Acks | Technical acknowledgments | All Partners |

---

## Core Value Proposition

### For Healthcare Organizations

- **Rapid Partner Onboarding**: New trading partners operational in days, not weeks
- **SLA-Driven Performance**: Predictable processing times with automated SLA tracking
- **Complete Auditability**: Every transaction tracked with full lineage for compliance and dispute resolution
- **Reduced Integration Costs**: Unified integration model eliminates custom point-to-point connections

### For IT Operations

- **Self-Service Configuration**: Partner setup via declarative configuration, no code changes
- **Automated Monitoring**: Real-time dashboards, alerts, and anomaly detection
- **Simplified Troubleshooting**: End-to-end correlation IDs and comprehensive logging
- **Scalable Architecture**: Elastic scaling handles volume spikes without manual intervention

### For Compliance & Security

- **HIPAA-Aligned**: Encryption, access controls, audit logging, and data retention policies
- **Immutable Audit Trail**: Complete history of all transactions and state changes
- **Least-Privilege Access**: Role-based access control with managed identities
- **Data Lineage**: Track data flow from source to destination for regulatory requirements

---

## Key Capabilities

### 1. Multi-Channel Ingestion

**Capability**: Accept EDI files through multiple protocols
- SFTP (primary)
- AS2 (encrypted transfers)
- REST API (future)

**Benefits**:
- Partner flexibility in submission methods
- Secure encrypted transmission
- Automatic file validation and quarantine

**Status**: ✅ Specified, 🔨 Bicep modules in progress

---

### 2. Intelligent Routing

**Capability**: Event-driven message routing to trading partners
- Service Bus topic/subscription architecture
- Declarative filter rules (no code changes)
- Priority-based processing
- Dead-letter queue handling

**Benefits**:
- Decouple ingestion from processing
- Independent scaling per partner
- Fault isolation and retry logic

**Status**: ✅ Specified, ⏳ Router Function planned

---

### 3. Trading Partner Abstraction

**Capability**: Unified model for all partners (external and internal)

**Key Innovation**: Internal systems (claims processing, eligibility, enrollment) are configured as **internal trading partners** with the same integration patterns as external partners.

| Partner Type | Examples | Integration Method |
|--------------|----------|-------------------|
| **External** | Medicare, Commercial Payers, Clearinghouses | SFTP, AS2, API |
| **Internal** | Claims System, Eligibility Service, Enrollment DB | Service Bus, Database, Internal API |

**Benefits**:
- Consistent architecture across all integrations
- Flexible internal system implementations (event sourcing, CRUD, custom)
- Independent evolution of each system
- Simplified operational model

**Status**: ✅ Specified, 📋 Configuration schema complete

---

### 4. Acknowledgment Management

**Capability**: Automated generation of EDI acknowledgments
- **TA1**: Interchange-level acceptance/rejection
- **999**: Functional syntax validation
- **271**: Eligibility response
- **277CA**: Claim acknowledgment
- **835**: Remittance advice

**Features**:
- Control number management (monotonic, gap-free sequences)
- SLA-driven acknowledgment timing
- Correlation to original transactions
- Automated delivery to partners

**Status**: ✅ Specified, 🔨 Azure SQL control number store designed

---

### 5. Event Sourcing (834 Enrollment)

**Capability**: Complete audit trail with transaction reversibility

**Key Features**:
- Immutable event log of all enrollment changes
- Point-in-time state reconstruction
- Batch reversal and replay
- Temporal queries

**Benefits**:
- Complete audit trail for compliance
- Ability to reverse and reprocess files
- Historical analysis capabilities
- Simplified debugging

**Status**: ✅ Fully specified in doc 11, ⏳ Implementation planned

---

### 6. Enterprise Scheduling

**Capability**: Time-based EDI generation for proactive workflows

**Use Cases**:
- Nightly enrollment snapshots
- Weekly compliance reports
- Monthly financial reconciliations
- Hourly control number audits

**Features**:
- Configuration-driven schedules
- Business calendar support
- Dependency management
- SLA tracking and alerting

**Status**: ✅ Specified, ⏳ ADF scheduler pipeline planned

---

### 7. Real-Time Monitoring

**Capability**: Comprehensive observability and SLA tracking

**Components**:
- **Log Analytics**: Custom tables for all events
- **KQL Queries**: 25+ operational queries
- **Dashboards**: Real-time performance metrics
- **Alerts**: Automated notifications for SLA breaches

**Metrics Tracked**:
- Ingestion latency (p50, p95, p99)
- Acknowledgment timing
- Error rates and types
- Control number gaps
- Partner-specific SLAs

**Status**: ✅ Complete query library, 📋 Dashboard templates ready

---

### 8. Infrastructure as Code

**Capability**: Reproducible, version-controlled infrastructure

**Technologies**:
- Bicep modules for all Azure resources
- GitHub Actions for CI/CD
- OpenID Connect (OIDC) authentication
- Multi-environment promotion (dev → test → prod)

**Features**:
- Automated what-if analysis
- Security scanning (Checkov, PSRule)
- Drift detection
- Automated rollback

**Status**: ✅ GitHub Actions workflows complete, 🔨 Bicep modules in progress

---

## Business Impact

### Quantified Benefits

| Metric | Before Platform | With Platform | Improvement |
|--------|-----------------|---------------|-------------|
| **Partner Onboarding Time** | 4-6 weeks | 2-3 days | 90% faster |
| **Eligibility Response Time** | 5-30 minutes | < 5 minutes (p95) | 6x faster |
| **Claim Acknowledgment** | 4-24 hours | < 4 hours | 6x faster |
| **Manual Intervention** | 40% of transactions | < 5% | 87% reduction |
| **Integration Cost per Partner** | $50-100K | $5-10K | 90% reduction |
| **Incident Resolution Time** | 4-8 hours | 30-60 minutes | 85% faster |

### Strategic Value

**Scalability**: Support for 50+ trading partners without linear cost increase

**Compliance**: Simplified regulatory reporting with complete audit trail

**Agility**: New transaction types deployed in weeks, not months

**Reliability**: 99.5% uptime SLA with automated failover

---

## System Architecture Overview

### High-Level Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                   Trading Partners                          │
│    (External: Payers, Providers, Clearinghouses)           │
│    (Internal: Claims, Eligibility, Enrollment Systems)     │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  Data Ingestion Layer                       │
│  SFTP Landing → Validation → Raw Storage (Immutable)       │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  Routing & Messaging                        │
│  Router Function → Service Bus → Partner Subscriptions     │
└─────────────────────────┬───────────────────────────────────┘
                          │
                ┌─────────┴─────────┐
                ▼                   ▼
┌─────────────────────────┐  ┌─────────────────────────┐
│  Partner Integration    │  │  Partner Integration    │
│  Adapters (Mappers +    │  │  Adapters (Mappers +    │
│  Connectors)            │  │  Connectors)            │
└─────────┬───────────────┘  └───────────┬─────────────┘
          │                              │
          ▼                              ▼
┌─────────────────────────────────────────────────────────────┐
│              Trading Partner Systems                        │
│  Process transactions, generate responses/outcomes          │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│               Outbound Assembly Layer                       │
│  Aggregate outcomes → Generate acknowledgments              │
│  Control Numbers (Azure SQL) → 999, TA1, 271, 277CA, 835   │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  Delivery to Partners                       │
│  SFTP Pickup, API Push, Email, Portal Download             │
└─────────────────────────────────────────────────────────────┘
```

### Layer Descriptions

See detailed documentation:
- [Data Ingestion Layer](./01-data-ingestion-layer.md)
- [Processing Pipeline](./02-processing-pipeline.md)
- [Routing & Messaging](./03-routing-messaging.md)
- [Mapper & Transformation](./04-mapper-transformation.md)
- [Outbound Delivery](./05-outbound-delivery.md)

---

## Technology Stack

### Azure Services (Core)

| Service | Purpose | SKU |
|---------|---------|-----|
| **Azure Data Lake Storage Gen2** | Raw/curated file storage | Standard LRS (Hot/Cool tiers) |
| **Azure Data Factory** | Ingestion orchestration | Standard with Managed VNet |
| **Azure Functions** | Serverless compute | Premium Plan (EP1) |
| **Azure Service Bus** | Message routing | Standard (Premium for prod) |
| **Azure SQL Database** | Control numbers, event store | General Purpose S2/S4 |
| **Azure Key Vault** | Secrets management | Standard with RBAC |
| **Azure Log Analytics** | Logging and metrics | Pay-as-you-go, 30-day retention |
| **Azure Monitor** | Dashboards and alerts | Standard |

### Development & Deployment

- **Infrastructure as Code**: Bicep
- **CI/CD**: GitHub Actions with OIDC
- **Application Runtime**: .NET 9 (C#)
- **Version Control**: Git (GitHub)
- **Package Management**: Azure Artifacts (NuGet)

---

## Implementation Timeline

### 18-Week AI-Accelerated Timeline

| Phase | Weeks | Focus | Status |
|-------|-------|-------|--------|
| **Phase 0** | 1-2 | Foundation, repositories, CI/CD | ✅ Complete |
| **Phase 1** | 3-6 | Core platform, ingestion, storage | ✅ Specified, 🔨 In Progress |
| **Phase 2** | 7-10 | Routing layer, Service Bus | ✅ Specified, ⏳ Planned |
| **Phase 3** | 11-14 | First trading partner (eligibility) | ✅ Specified, ⏳ Planned |
| **Phase 4** | 15-16 | Scale partners (claims, enrollment) | ✅ Specified, ⏳ Planned |
| **Phase 5** | 17-18 | Outbound assembly, scheduler | ✅ Specified, ⏳ Planned |
| **Phase 6** | 19-20 | Production hardening | ✅ Specified, ⏳ Planned |

**Current Status**: End of Phase 0 / Beginning of Phase 1  
**Next Milestone**: Core platform ingestion operational

---

## Success Criteria

### Technical Metrics

- ✅ **Ingestion SLA**: p95 latency < 5 minutes from file arrival to raw zone
- ✅ **Routing SLA**: p95 latency < 2 seconds for message publication
- ✅ **Eligibility SLA**: p95 end-to-end < 5 minutes (270 → 271)
- ✅ **Claims Ack SLA**: p95 < 4 hours (837 → 277CA)
- ✅ **Acknowledgment Accuracy**: 999 generated within 15 minutes, 0 control number gaps
- ✅ **Availability**: 99.5% uptime SLA
- ✅ **Throughput**: 5,000 files/hour sustained

### Business Outcomes

- ✅ **Partner Onboarding**: < 5 days from request to production
- ✅ **Operational Cost**: < $10K per partner integration
- ✅ **Manual Intervention**: < 5% of transactions require manual review
- ✅ **Compliance**: Pass HIPAA security audit
- ✅ **Incident Response**: Mean time to resolution < 1 hour

---

## Current Status Summary

### ✅ Completed

- Architecture specifications (15 core documents)
- Implementation plan and AI strategy
- GitHub Actions CI/CD workflows
- Partner configuration schema
- KQL query library (25+ queries)
- Operational runbooks
- Security and compliance specifications
- Event sourcing design (834 enrollment)
- Enterprise scheduler design

### 🔨 In Progress

- Bicep infrastructure modules
- Core platform ingestion (ADF pipelines)
- Shared libraries (NuGet packages)

### ⏳ Planned (Next 16 Weeks)

- Router Function implementation
- Mapper/Connector Functions
- Outbound Orchestrator
- Control number store (Azure SQL)
- End-to-end integration testing
- Production deployment

---

## Key Stakeholders

### Platform Team

- **EDI Platform Lead**: Architecture, strategy, partner coordination
- **Senior Platform Engineers** (2): Infrastructure, Functions, operations
- **Platform Engineers** (2): Development, testing, monitoring
- **AI Agent Coordinator**: Prompt engineering, code generation oversight
- **Healthcare EDI SME** (0.5 FTE): Standards validation, compliance

### Business Stakeholders

- **VP of Operations**: Executive sponsor
- **Compliance Officer**: HIPAA oversight
- **Partner Relations**: Trading partner coordination
- **Finance**: Budget and cost management

---

## Next Steps

### For New Team Members

1. Review this executive overview
2. Study [Glossary](./16-glossary.md) for domain terminology
3. Read [Routing & Messaging](./03-routing-messaging.md) for core architecture
4. Explore subsystem documents relevant to your role

### For Implementation

1. Complete Bicep infrastructure modules (Phase 1)
2. Deploy dev environment and validate ingestion
3. Implement Router Function and Service Bus routing
4. Onboard first pilot trading partner (eligibility)
5. Scale to additional partners and transaction types

---

## References

### Primary Documentation

- [Architecture Specification](../01-architecture-spec.md)
- [Data Flow Specification](../02-data-flow-spec.md)
- [Security Specification](../03-security-compliance-spec.md)
- [Routing Specification](../08-transaction-routing-outbound-spec.md)
- [Implementation Overview](../../implementation-plan/00-implementation-overview.md)

### Operational Resources

- [SLA Targets](../../ACK_SLA.md)
- [KQL Queries](../../queries/kusto/)
- [Partner Configuration](../../config/partners/)
- [GitHub Actions Guide](../04a-github-actions-implementation.md)

---

**Document Version:** 3.0  
**Last Updated:** October 6, 2025  
**Next Review:** January 6, 2026  
**Owner:** EDI Platform Lead
