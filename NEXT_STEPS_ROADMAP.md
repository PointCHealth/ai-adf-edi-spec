# Next Steps Roadmap - Post InboundRouter Completion

**Last Updated:** January 6, 2025  
**Current Phase:** End of Phase 2 (Week 10 of 28)  
**Status:** InboundRouter ✅ Complete - Ready for Phase 3

---

## Current Project Status

### ✅ Completed (20% of 28-week plan)

**Phase 1-2: Foundation & Routing Layer**
- ✅ Infrastructure as Code (All Bicep modules)
- ✅ CI/CD Pipelines (GitHub Actions workflows)
- ✅ Shared Libraries (6 libraries - EDI.Core, EDI.X12, EDI.Configuration, EDI.Storage, EDI.Messaging, EDI.Logging)
- ✅ InboundRouter Function (Fully implemented with comprehensive configuration)
- ✅ Documentation (Architecture specs, function specs, configuration guides)

**Build Status:**
```
✅ All projects building successfully
✅ .NET 9.0 compatibility verified
✅ Zero compilation errors
✅ Security patches applied
```

### 🔄 Scaffolded Only (5% - Structure exists, no implementation)

**11 Function Projects:**
- EligibilityMapper.Function
- EnrollmentMapper.Function
- RemittanceMapper.Function
- ClaimsMapper.Function
- SftpConnector.Function
- ApiConnector.Function
- MftConnector.Function
- AckGenerator.Function
- ControlNumberService.Function
- OutboundOrchestrator.Function
- EnterpriseScheduler.Function

### ❌ Not Started (75% - Phases 3-6)

**Phase 3-4: Trading Partner Implementation**
- Mapper function implementations (4 functions)
- Connector function implementations (3 functions)
- Partner configuration system
- SQL database projects (2 databases)
- Partner onboarding process

**Phase 5: Outbound Assembly**
- Acknowledgment generation
- Control number management
- Enterprise scheduler
- Outbound orchestration

**Phase 6: Production Hardening**
- Security audit
- Performance optimization
- DR testing
- Production deployment

---

## Recommended Implementation Priority

### Priority 1: Phase 3 Foundation (Weeks 11-14)

**Critical Path:** Build first complete end-to-end flow

#### 1.1 EligibilityMapper Function (Week 11-12)
**Why First:** Simplest transaction type, validates architecture end-to-end

**Implementation Tasks:**
- [ ] Create X12 270/271 parsing logic (using EDI.X12 library)
- [ ] Implement mapping rules (X12 → Internal format)
- [ ] Build validation logic (business rules)
- [ ] Add error handling (invalid transactions → error queue)
- [ ] Configure Service Bus triggers (eligibility-mapper-queue)
- [ ] Create unit tests (parsing, mapping, validation)
- [ ] Create integration tests (queue → mapper → output)
- [ ] Document mapper configuration

**Deliverables:**
- Working mapper function processing 270/271 transactions
- Test coverage > 80%
- Documentation complete
- Deployed to dev environment

**Estimated Effort:** 40-60 hours

---

#### 1.2 Partner Configuration System (Week 11-12)
**Why Critical:** Required by all mappers for partner-specific rules

**Implementation Tasks:**
- [ ] Define partner configuration schema (JSON Schema)
- [ ] Implement PartnerConfigService (blob storage loader)
- [ ] Add in-memory caching (5-minute TTL)
- [ ] Build auto-refresh mechanism (blob change detection)
- [ ] Create partner config validation
- [ ] Add partner config management API (CRUD operations)
- [ ] Create sample partner configs (3-5 partners)
- [ ] Document configuration schema

**Deliverables:**
- Partner configuration schema (v1.0)
- PartnerConfigService implementation
- Sample partner configurations
- Configuration management documentation

**Estimated Effort:** 30-40 hours

---

#### 1.3 SQL Database Projects (Week 13-14)
**Why Needed:** Control numbers and event sourcing for 834 enrollment

**Implementation Tasks:**

**Control Numbers Database:**
- [ ] Create schema (ISA/GS/ST control number tables)
- [ ] Add stored procedures (GetNextControlNumber, ValidateControlNumber)
- [ ] Implement concurrency handling (optimistic locking)
- [ ] Add indexes (performance optimization)
- [ ] Create migration scripts (initial setup)
- [ ] Build database unit tests

**Enrollment Event Store Database:**
- [ ] Create event store schema (events, snapshots, metadata)
- [ ] Add stored procedures (AppendEvent, GetEventStream, CreateSnapshot)
- [ ] Implement event versioning
- [ ] Add indexes (event stream queries)
- [ ] Create migration scripts
- [ ] Build database unit tests

**Deliverables:**
- 2 SQL Database projects (SSDT)
- Migration scripts for all environments
- Stored procedures with tests
- Database deployment documentation

**Estimated Effort:** 40-50 hours

---

#### 1.4 SFTP Connector Function (Week 13-14)
**Why Critical:** Required for partner file transfers (first integration pattern)

**Implementation Tasks:**
- [ ] Create SFTP client service (SSH.NET library)
- [ ] Implement connection pooling (reuse connections)
- [ ] Add retry logic (transient failures)
- [ ] Build file upload operations (outbound)
- [ ] Build file download operations (inbound)
- [ ] Add credential management (Key Vault)
- [ ] Create connection health checks
- [ ] Implement file transfer monitoring
- [ ] Add error handling (connection failures, timeouts)
- [ ] Create unit tests (mocked SFTP)
- [ ] Create integration tests (test SFTP server)
- [ ] Document connector configuration

**Deliverables:**
- Working SFTP connector function
- Connection pooling and retry logic
- Credential management via Key Vault
- Test coverage > 75%
- Documentation complete

**Estimated Effort:** 30-40 hours

---

### Priority 2: Integration Testing (Week 14)

**Why Critical:** Validate end-to-end flows before scaling

#### 2.1 Integration Testing Framework
**Implementation Tasks:**
- [ ] Create test data generation (sample X12 files)
- [ ] Build test harness (Service Bus test client)
- [ ] Implement end-to-end flow tests:
  - [ ] Blob → InboundRouter → EligibilityMapper → SFTP Connector
  - [ ] Error scenarios (invalid X12, unknown partner, connection failures)
  - [ ] Performance tests (100 files, latency < 2s P95)
- [ ] Create test environment setup scripts
- [ ] Add test data cleanup (after test runs)
- [ ] Document testing procedures

**Deliverables:**
- Integration test project
- 20+ end-to-end test scenarios
- Test data generation tools
- CI/CD integration (automated test runs)

**Estimated Effort:** 20-30 hours

---

### Priority 3: Phase 3 Completion (Week 15-16)

#### 3.1 Deploy First Complete Flow
**Implementation Tasks:**
- [ ] Deploy all components to test environment
- [ ] Configure partner (1 pilot partner)
- [ ] Run end-to-end validation
- [ ] Load test (1,000 files/hour sustained)
- [ ] Monitor performance (Application Insights)
- [ ] Document operational procedures
- [ ] Train support team

**Deliverables:**
- Working end-to-end flow in test environment
- Performance validated (meets SLA)
- Operational documentation
- Support team trained

**Estimated Effort:** 20-30 hours

---

### Priority 4: Scale to Additional Transaction Types (Phase 4, Weeks 17-20)

**Sequential Implementation (4 weeks):**

#### 4.1 EnrollmentMapper (834 transactions) - Week 17
- Event sourcing integration (enrollment event store)
- Complex validation rules (member demographics)
- Estimated: 50-60 hours

#### 4.2 RemittanceMapper (835 transactions) - Week 18
- Payment parsing (complex loops)
- Financial validation
- Estimated: 50-60 hours

#### 4.3 ClaimsMapper (837 transactions) - Week 19
- Most complex transaction type
- Claims-specific business rules
- Estimated: 60-70 hours

#### 4.4 API Connector - Week 20
- REST API integration pattern
- OAuth2 authentication
- Estimated: 30-40 hours

---

### Priority 5: Phase 5 - Outbound Assembly (Weeks 21-24)

#### 5.1 AckGenerator Function - Week 21-22
- Generate 997 (Functional Acknowledgments)
- Generate TA1 (Interchange Acknowledgments)
- Generate 277CA (Claim Acknowledgments)
- Control number assignment
- Estimated: 50-60 hours

#### 5.2 OutboundOrchestrator Function - Week 22-23
- Collect outbound transactions
- Apply partner-specific formatting
- Route to partner connectors
- Estimated: 40-50 hours

#### 5.3 EnterpriseScheduler Function - Week 23-24
- Cron-based scheduling
- Partner-specific schedules
- Batch processing
- Estimated: 40-50 hours

---

### Priority 6: Phase 6 - Production Hardening (Weeks 25-28)

#### 6.1 Security Audit - Week 25
- HIPAA compliance verification
- PHI data flow audit
- Security scan results review
- Penetration testing
- Estimated: 40-50 hours

#### 6.2 Performance Optimization - Week 26
- Load testing (5,000+ files/hour)
- Latency optimization (P95 < 1s)
- Cost optimization
- Estimated: 30-40 hours

#### 6.3 DR Testing - Week 27
- Failover procedures
- Backup/restore testing
- RPO/RTO validation
- Estimated: 20-30 hours

#### 6.4 Production Deployment - Week 28
- Production environment setup
- Blue-green deployment
- Production validation
- Go-live support
- Estimated: 30-40 hours

---

## Immediate Next Actions (This Week)

### 1. Start EligibilityMapper Implementation ⭐

**Today:**
1. Create mapper configuration model (MappingOptions)
2. Implement X12 270 parser (eligibility request)
3. Build mapping rules engine

**This Week:**
1. Complete X12 271 parser (eligibility response)
2. Add validation logic
3. Write unit tests
4. Create integration tests

### 2. Define Partner Configuration Schema ⭐

**Today:**
1. Create partner configuration JSON schema
2. Define routing rules structure
3. Define mapping rules structure

**This Week:**
1. Create sample partner configs
2. Implement PartnerConfigService loader
3. Add caching layer
4. Write tests

### 3. Plan SQL Database Projects

**This Week:**
1. Design control numbers schema
2. Design enrollment event store schema
3. Create SSDT projects
4. Write initial migration scripts

---

## Success Metrics by Phase

### Phase 3 (Weeks 11-14)
- ✅ EligibilityMapper processing 270/271 transactions
- ✅ Partner configuration system operational
- ✅ SQL databases deployed and tested
- ✅ SFTP connector operational
- ✅ End-to-end integration tests passing
- ✅ First pilot partner onboarded

### Phase 4 (Weeks 15-20)
- ✅ 4 mapper functions operational (834/835/837/270-271)
- ✅ 3 connector functions operational (SFTP/API/MFT)
- ✅ 5+ partners onboarded
- ✅ Processing 1,000+ files/day
- ✅ < 1% error rate

### Phase 5 (Weeks 21-24)
- ✅ Acknowledgment generation operational
- ✅ Control number management operational
- ✅ Scheduler operational
- ✅ Complete bidirectional flows (inbound + outbound)
- ✅ 10+ partners operational

### Phase 6 (Weeks 25-28)
- ✅ Security audit passed
- ✅ Performance targets met (5,000+ files/hour)
- ✅ DR procedures validated
- ✅ Production deployment successful
- ✅ Production certification achieved

---

## Technical Debt & Risks

### Current Technical Debt
1. **No integration tests yet** - Built infrastructure and InboundRouter without integration testing
2. **No partner configurations** - Partner config system needs implementation
3. **No test data** - Need sample X12 files for all transaction types
4. **No monitoring dashboards** - Application Insights queries exist but no dashboards

### Top Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| X12 parsing complexity (837 claims) | High | Start with simpler transactions (270/271), build up expertise |
| Partner-specific quirks | Medium | Build configurable mapping engine, avoid hard-coding |
| Performance at scale | High | Load test early and often, optimize hot paths |
| Control number collisions | High | Implement database-backed control numbers with locking |
| HIPAA compliance gaps | Critical | Security audit in Phase 6, compliance checks throughout |

---

## Decision Points

### Architecture Decisions Needed

1. **Mapping Rules Engine:**
   - Option A: Code-based mapping (C# classes)
   - Option B: Configuration-based mapping (JSON rules)
   - Option C: Hybrid (code for complex, config for simple)
   - **Recommendation:** Option C (flexibility + maintainability)

2. **Partner Configuration Storage:**
   - Option A: Blob storage (current design)
   - Option B: Azure App Configuration
   - Option C: Cosmos DB
   - **Recommendation:** Option A (simpler, already designed)

3. **Event Sourcing Implementation:**
   - Option A: Custom SQL-based event store
   - Option B: Azure Event Hubs
   - Option C: Azure Cosmos DB changefeed
   - **Recommendation:** Option A (full control, lower cost)

---

## Resources Required

### Development Effort (Remaining)

| Phase | Estimated Hours | FTE (40h/week) | Calendar Weeks |
|-------|----------------|----------------|----------------|
| Phase 3 | 160-190 hours | 1 FTE | 4 weeks |
| Phase 4 | 220-270 hours | 1 FTE | 6 weeks |
| Phase 5 | 130-160 hours | 1 FTE | 4 weeks |
| Phase 6 | 120-150 hours | 1 FTE | 4 weeks |
| **Total** | **630-770 hours** | **1 FTE** | **18 weeks** |

### Skills Required
- .NET/C# development (Azure Functions)
- X12 EDI expertise (parsing, mapping)
- Azure services (Storage, Service Bus, SQL)
- SQL Server (SSDT, stored procedures)
- Testing (unit, integration, load)
- DevOps (CI/CD, monitoring)

---

## Key Documents to Review

### Implementation Guides
- [Phase 3 Implementation Plan](implementation-plan/10-phase-3-first-trading-partner.md)
- [Mapper Function Spec](implementation-plan/02-azure-function-projects.md)
- [Partner Onboarding Playbook](implementation-plan/12-partner-onboarding-playbook.md)
- [Testing Strategy](implementation-plan/21-testing-strategy.md)

### Configuration & Schema
- [Partner Configuration Schema](implementation-plan/19-partner-configuration-schema.md)
- [Mapping Rules Specification](implementation-plan/20-mapping-rules-specification.md)
- [Database Projects](implementation-plan/13-database-project-control-numbers.md)

### Operations
- [Operations Spec](docs/06-operations-spec.md)
- [Monitoring & Observability](docs/06-operations-spec.md#monitoring)
- [Runbooks](docs/06-operations-spec.md#runbooks)

---

## Summary

**Current Position:** End of Phase 2 (Week 10 of 28, 36% time elapsed)  
**Progress:** 20% complete (foundation solid)  
**Remaining Work:** 18-20 weeks (75% of implementation)  
**Next Milestone:** Phase 3 complete (Week 14) - First end-to-end flow operational

**Critical Path Forward:**
1. **Week 11-12:** EligibilityMapper + Partner Config System
2. **Week 13-14:** SQL Databases + SFTP Connector + Integration Tests
3. **Week 15-16:** End-to-end validation + First pilot partner
4. **Week 17-20:** Scale to all transaction types (834/835/837)
5. **Week 21-24:** Outbound assembly (acknowledgments, scheduler)
6. **Week 25-28:** Production hardening + go-live

**Success Factors:**
- Start simple (270/271 first)
- Build reusable patterns (mapping engine, connector framework)
- Test continuously (unit, integration, load)
- Document as you go (configuration, operations)
- Validate with pilot partner early

---

**Ready to start Phase 3!** 🚀
