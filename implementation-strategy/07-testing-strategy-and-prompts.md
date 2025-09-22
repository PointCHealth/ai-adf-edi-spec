# 07 - Testing Strategy & Prompt Set

---
## Prompt
You are defining a multi-layer testing strategy for the EDI platform covering code, infrastructure, integration, data quality, performance, and operational readiness.

### Objectives
1. Enumerate test layers: unit, component, contract (API & messaging), integration, performance, chaos/resilience, security, data quality (control numbers, SLAs), observability validation
2. Define test ownership & gating (which layers block promotion)
3. Provide tooling matrix (frameworks, runners, load tools, security scanners)
4. Specify contract testing approach for Service Bus topics/queues & REST endpoints (from `api/partner-portal/openapi.v1.yaml`)
5. Outline test data management (synthetic vs masked, generation scripts, retention)
6. Provide performance test scenarios & SLA thresholds referencing queries under `queries/kusto`
7. Describe resilience & chaos experiments (latency injection, queue backpressure, downstream failures)
8. Define quality gates & coverage thresholds (minimum unit/component coverage, contract test pass rate)
9. Provide observability validation tests (ensure metrics, logs, traces emitted with required dimensions)
10. Include automated test prompt templates for each layer

### Constraints
- Sensitive partner data must not be used in lower environments
- Performance tests isolated from production scale resources unless explicitly planned
- Test data cleanup must be idempotent
- Chaos experiments gated behind explicit flag

### Required Output Sections
1. Test Layer Definitions
2. Ownership & Promotion Gates
3. Tooling Matrix
4. Contract Testing Strategy
5. Test Data Management Plan
6. Performance & Resilience Scenarios
7. Quality Gates & Coverage Thresholds
8. Observability Validation Plan
9. Prompt Templates (per layer)
10. Open Questions

### Acceptance Criteria
- Every layer lists purpose, scope, anti-goals
- Contract strategy covers version negotiation & backward compatibility
- Performance scenarios link to business SLAs (latency, throughput, error budget)
- Prompt templates clearly instruct AI to produce tests with assertions & mocks

### Variable Placeholders
- MAX_ACCEPTABLE_AVG_LATENCY_MS = <number>
- TARGET_THROUGHPUT_MSG_PER_MIN = <number>
- ERROR_BUDGET_PERCENT = <number>

Return only the structured output sections.

---
## Usage
Execute after core service design. Provide placeholders; use AI to generate concrete test artifacts.
