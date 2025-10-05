# ADR-003: X12 Parser Library Selection

**Status:** Accepted  
**Date:** 2025-10-05  
**Decision Makers:** Platform Engineering Team  
**Technical Area:** Shared Libraries

---

## Context

The Healthcare EDI Platform requires a robust X12 EDI parser to handle HIPAA-compliant healthcare transactions (270, 271, 834, 835, 837, 277). The parser must:

1. **Parse X12 Format:** Read ISA/GS/ST envelopes and segment structures
2. **Generate X12 Format:** Create syntactically valid EDI files
3. **Support Healthcare Transactions:** HIPAA 5010 transaction sets
4. **.NET Compatibility:** Work with .NET 9 (current LTS)
5. **NuGet Availability:** Easy integration via package manager
6. **Performance:** Handle high-volume processing (thousands of transactions/hour)
7. **Maintainability:** Active community or vendor support
8. **Error Handling:** Clear validation and error messages

### Business Requirements

- **HIPAA Compliance:** Must accurately parse/generate HIPAA 5010 transactions
- **Transaction Types:** 270, 271, 834, 835, 837 (Professional, Institutional, Dental), 277
- **Volume:** Production estimate 50,000 transactions/day across all partners
- **Latency:** Sub-second parsing for routing decisions
- **Extensibility:** Support adding new transaction types without major refactoring

---

## Decision

**We will use OopFactory.X12 (formerly known as X12Parser) as the primary X12 parsing library.**

**NuGet Package:** `OopFactory.X12`  
**Current Version:** 3.0.0 (as of October 2025)  
**License:** MIT License (permissive, commercial use allowed)  
**Repository:** https://github.com/Eddy-Guido/OopFactory.X12

---

## Rationale

### Why OopFactory.X12?

#### ✅ Pros

1. **Open Source & Free:**
   - MIT license allows commercial use without fees
   - Source code available for debugging and customization
   
2. **Healthcare Transaction Support:**
   - Built-in support for HIPAA 5010 transactions
   - Includes healthcare-specific validation rules
   - Supports 270, 271, 834, 835, 837, 277 out of the box

3. **Strong Parsing Capabilities:**
   - Handles complex nested loops (e.g., 837 claim lines)
   - Validates segment order and cardinality
   - Supports repeating segments and hierarchical structures

4. **X12 Generation:**
   - Can generate EDI files from object model
   - Ensures syntactically valid output (correct delimiters, control numbers, etc.)

5. **Active Community:**
   - GitHub repository with ongoing maintenance
   - Used by multiple healthcare EDI projects
   - Community-contributed bug fixes and enhancements

6. **.NET Core/.NET 5+ Support:**
   - Works with .NET 9 (current platform target)
   - No legacy dependencies on .NET Framework

7. **Moderate Learning Curve:**
   - Intuitive API: `X12Parser.ParseMultiple(x12Content)`
   - LINQ-friendly query patterns for segment access

#### ⚠️ Cons

1. **Not as Feature-Rich as Commercial Options:**
   - Less comprehensive than BizTalk or Edifecs
   - Some advanced features (acknowledgment generation) may need custom code

2. **Documentation Could Be Better:**
   - Limited official documentation
   - Relies on GitHub wiki and community examples

3. **Performance Not Guaranteed:**
   - No official benchmarks published
   - May need caching for high-throughput scenarios

4. **Breaking Changes Possible:**
   - Open-source project, major version changes could introduce breaking changes
   - Requires vigilant dependency management (Dependabot will help)

---

## Alternatives Considered

### Option 1: Custom Parser

**Description:** Build a custom X12 parser from scratch.

**Pros:**
- Full control over performance and features
- Tailored to exact use cases

**Cons:**
- **High Development Cost:** 6-8 weeks of development time
- **Maintenance Burden:** Ongoing bug fixes and X12 standard updates
- **Risk:** Subtle parsing errors could cause HIPAA compliance issues
- **No Reuse:** Not benefiting from community knowledge

**Decision:** ❌ Rejected - Too expensive and risky

---

### Option 2: Edifecs XEngine

**Description:** Commercial EDI translation engine used by major healthcare payers.

**Pros:**
- Enterprise-grade reliability
- Comprehensive HIPAA support
- Vendor support and SLAs

**Cons:**
- **Cost:** $50,000+ licensing fees per year
- **Overkill:** Our use case doesn't require a full translation engine
- **Vendor Lock-in:** Difficult to migrate away from
- **Cloud Integration:** May require on-premises infrastructure

**Decision:** ❌ Rejected - Cost prohibitive, over-engineered for our needs

---

### Option 3: BizTalk Server EDI Pipeline

**Description:** Microsoft BizTalk Server with EDI accelerators.

**Pros:**
- Microsoft support
- Proven in healthcare industry
- Built-in acknowledgment generation

**Cons:**
- **Legacy Technology:** BizTalk is being phased out by Microsoft
- **On-Premises:** Doesn't align with cloud-native Azure architecture
- **Cost:** Licensing + infrastructure costs
- **Developer Experience:** XML-based configuration, not modern C# coding

**Decision:** ❌ Rejected - Not cloud-native, Microsoft is deprecating BizTalk

---

### Option 4: Eddy.NET

**Description:** Modern .NET library for EDI parsing (supports X12 and EDIFACT).

**NuGet:** `Eddy.Edifact`, `Eddy.X12`  
**GitHub:** https://github.com/Eddy-Guido/Eddy

**Pros:**
- Clean, modern C# API
- Strong typing for transaction segments
- Active development

**Cons:**
- **Newer Library:** Less battle-tested than OopFactory.X12
- **Smaller Community:** Fewer users and less documentation
- **API Differs:** Different mental model (more strongly typed)

**Decision:** ⏸️ Keep as Backup - Monitor Eddy.NET for future migration if it gains traction

---

## Implementation Strategy

### Phase 1: Shared Library Setup (Week 2)

Create `HealthcareEDI.X12` shared library in `edi-platform-core`:

```
edi-platform-core/
├── src/
│   └── HealthcareEDI.X12/
│       ├── HealthcareEDI.X12.csproj
│       ├── Parsers/
│       │   ├── X12Envelope Parser.cs
│       │   └── InterchangeParser.cs
│       ├── Generators/
│       │   └── X12FileGenerator.cs
│       ├── Models/
│       │   ├── Interchange.cs
│       │   ├── FunctionalGroup.cs
│       │   └── Transaction.cs
│       └── Extensions/
│           └── X12Extensions.cs
```

**Dependencies:**

```xml
<ItemGroup>
  <PackageReference Include="OopFactory.X12" Version="3.0.0" />
</ItemGroup>
```

### Phase 2: Wrapper API (Week 2-3)

Build abstraction layer over OopFactory.X12 to:

1. **Simplify Common Operations:**
   ```csharp
   // Parsing
   var envelope = X12EnvelopeParser.Parse(x12Content);
   var functionalGroups = envelope.GetFunctionalGroups();
   
   // Querying
   var transactionType = envelope.GetTransactionType(); // "270", "837", etc.
   var senderId = envelope.GetSenderId();
   var receiverId = envelope.GetReceiverId();
   
   // Validation
   var validationResult = envelope.Validate();
   if (!validationResult.IsValid) {
       // Handle errors
   }
   ```

2. **Provide Healthcare-Specific Helpers:**
   ```csharp
   // Extract patient info from 270 eligibility inquiry
   var patient = eligibilityTransaction.GetPatient();
   var memberId = patient.GetMemberId();
   
   // Extract claim totals from 837
   var claim = claimTransaction.GetClaim();
   var totalCharges = claim.GetTotalCharges();
   ```

3. **Handle Control Numbers:**
   ```csharp
   // Generate outbound transaction with control numbers
   var outboundFile = X12FileGenerator.Create()
       .WithInterchangeControlNumber(12345)
       .WithGroupControlNumber(1)
       .WithTransactionControlNumber(1)
       .AddTransaction(transactionData)
       .Build();
   ```

### Phase 3: Testing (Week 3)

**Unit Tests:**
- Parse valid X12 files (one per transaction type)
- Generate X12 files and validate against schema
- Handle malformed X12 (missing segments, invalid syntax)

**Integration Tests:**
- Parse real partner samples (de-identified)
- Round-trip test: Parse → Modify → Generate → Parse again

**Test Data Sources:**
- Washington Publishing Company (WPC) sample files
- CMS HIPAA 5010 test files
- Partner-provided sample transactions

### Phase 4: Performance Testing (Week 4)

**Benchmarks:**
- Parse 1,000 270 transactions (target: < 5 seconds)
- Parse 1,000 837 transactions (target: < 10 seconds)
- Memory usage (target: < 100 MB for 10,000 transactions)

**Optimization Strategies if Needed:**
- Cache parsed schemas
- Use `Span<char>` for segment parsing
- Consider lazy loading for large interchanges

---

## Migration Path (If Needed)

If OopFactory.X12 proves insufficient, we can migrate to **Eddy.NET** or a **commercial solution** with minimal impact:

### Abstraction Benefits

Our `HealthcareEDI.X12` wrapper isolates OopFactory.X12 from business logic:

```csharp
// Business code depends on our interface, not OopFactory directly
public interface IX12Parser {
    Interchange Parse(string x12Content);
}

// Current implementation uses OopFactory
public class OopFactoryX12Parser : IX12Parser {
    public Interchange Parse(string x12Content) {
        // OopFactory.X12 logic
    }
}

// Future implementation could use Eddy.NET
public class EddyX12Parser : IX12Parser {
    public Interchange Parse(string x12Content) {
        // Eddy.NET logic
    }
}
```

**Migration Steps:**
1. Create new parser implementation
2. Update dependency injection registration
3. Re-run test suite
4. Deploy incrementally (test environment first)

**Estimated Migration Effort:** 2-3 weeks

---

## Monitoring & Success Metrics

### Metrics to Track

1. **Parsing Success Rate:**
   - Target: > 99.9% of received files parse successfully
   - Alert if parsing errors > 1% per hour

2. **Parsing Performance:**
   - Target: P95 latency < 100ms per transaction
   - Alert if P95 latency > 500ms

3. **Validation Errors:**
   - Track common validation failures (missing segments, invalid data)
   - Feedback to trading partners for file quality improvement

4. **Library Updates:**
   - Monitor OopFactory.X12 releases on GitHub
   - Review release notes for breaking changes
   - Dependabot will create PRs for version updates

### Application Insights Queries

```kql
// Parsing failures by transaction type
requests
| where name startswith "X12Parser"
| where success == false
| summarize count() by transactionType = tostring(customDimensions.TransactionType)
| order by count_ desc

// Parsing duration by transaction type
requests
| where name startswith "X12Parser"
| summarize 
    avg_duration_ms = avg(duration),
    p95_duration_ms = percentile(duration, 95),
    max_duration_ms = max(duration)
  by transactionType = tostring(customDimensions.TransactionType)
```

---

## Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| OopFactory.X12 becomes unmaintained | High | Low | Monitor GitHub activity; maintain fork if needed |
| Performance issues at scale | Medium | Medium | Performance testing in Week 4; optimize or switch library |
| Breaking changes in new versions | Medium | Medium | Pin version; use Dependabot; test before upgrading |
| Parsing errors cause HIPAA violations | High | Low | Comprehensive test suite; validation layer; partner feedback |

---

## References

- **OopFactory.X12 GitHub:** https://github.com/Eddy-Guido/OopFactory.X12
- **X12 Standards:** https://x12.org/
- **HIPAA 5010 Implementation Guides:** https://www.cms.gov/regulations-and-guidance/hipaa-administrative-simplification
- **Washington Publishing Company (WPC):** Sample X12 files and schemas

---

## Decision Log

| Date | Version | Change | Author |
|------|---------|--------|--------|
| 2025-10-05 | 1.0 | Initial decision to use OopFactory.X12 | Platform Engineering Team |

---

## Approvals

- ✅ **Platform Engineering Lead:** Approved
- ✅ **Security Team:** Reviewed (MIT license acceptable)
- ✅ **Architecture Review Board:** Approved with monitoring requirements

---

**Next Steps:**
1. Create `HealthcareEDI.X12` shared library project (Week 2, Prompt 12)
2. Install OopFactory.X12 NuGet package
3. Build wrapper API and test suite
4. Document wrapper API for function developers

---

**Last Updated:** 2025-10-05  
**ADR Status:** Accepted  
**Review Date:** 2026-04-05 (6 months from decision)
