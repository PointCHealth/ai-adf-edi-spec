# Healthcare EDI Ingestion – Non-Functional Requirements & Risk Register

## 1. Purpose

Document measurable non-functional requirements (NFRs) and enumerate key delivery/operational risks with mitigation strategies.

## 2. Non-Functional Requirements Summary

| Category | Requirement | Target / Metric | Notes |
|----------|------------|-----------------|-------|
| Performance | Ingestion latency (p95) | < 5 minutes from SFTP arrival to raw zone | Event-driven path |
| Performance | Pipeline start delay | < 60 seconds from blob event | Event Grid SLA dependent |
| Scalability | Partner count | Scale to 50 partners initial, design to 200 | Horizontal path naming |
| Scalability | Burst handling | 100 files/minute sustained 10 min | Parallel pipeline branches |
| Availability | Platform availability | 99.5% monthly for ingestion pipeline | Excludes planned maintenance |
| Reliability | Reprocessing success rate | > 98% after first retry | Idempotent design |
| Durability | Data loss events | 0 accepted | Raw zone retention & redundancy |
| Security | Unauthorized access incidents | 0 | Audited & alerting |
| Compliance | HIPAA alignment | Passed internal audit | Controls implemented |
| Observability | Telemetry coverage | 100% pipelines logged | Structured metadata |
| Maintainability | Infra deployment time | < 30 min env stand-up | Automated IaC |
| Cost Efficiency | Storage lifecycle | > 80% cold after 1 year | Policy automation |
| Recovery | RPO | 15 minutes | Metadata + Storage durability |
| Recovery | RTO | 2 hours | Redeploy + config restore |

## 3. Detailed NFR Definitions

### 3.1 Latency

Measurement = processedUtc - receivedUtc. Exclude quarantine cases. Tracked via Log Analytics query aggregated hourly; alert if p95 > threshold for 30 consecutive minutes.

### 3.2 Availability

Defined as successful completion of at least one valid ingestion path every 5 minutes when files are present. Pipeline failure with automated retry not counted as downtime unless final state = Failed.

### 3.3 Scalability

Design avoids central bottlenecks (no DB hot path). Event Grid scales automatically; ADF pipelines use parameterization and parallel copy where file size large.

### 3.4 Security & Compliance

Quarterly access reviews; Key Vault purge protection enabled; all secrets accessed via Managed Identity; encryption at rest mandatory.

### 3.5 Observability

All ingestion actions yield structured record (EDIIngestion_CL). Coverage validated by comparing event count vs. metadata rows per day (must be 1:1 except duplicates/quarantine).

### 3.6 Reliability & Reprocessing

Retry policy: 3 transient retries (exponential backoff) for Storage or network issues; manual reprocess supports up to 5 attempts before escalation.

## 4. Capacity Assumptions

| Dimension | Assumption | Validation Plan |
|----------|-----------|-----------------|
| Average file size | 1–5 MB | Monitor mean/percentiles monthly |
| Peak file size | 100 MB | Stress test quarterly |
| Daily volume (initial) | 10k files | Track growth curve |
| Growth rate | 10% monthly first year | Capacity forecast review |
| Partners onboarding velocity | 5 per month | Track vs. resource usage |

## 5. Risk Register

| ID | Risk | Category | Impact | Likelihood | Mitigation | Residual |
|----|------|----------|--------|-----------|------------|----------|
| R1 | Partner naming pattern non-compliance | Data Quality | Medium | High | Strict validation + onboarding checklist | Low |
| R2 | Volume spike beyond design ( >200 files/min) | Capacity | High | Medium | Scale out pipelines; pre-stage IR performance tests | Medium |
| R3 | Malicious payload (virus) | Security | High | Low | AV scan + quarantine + Defender alerts | Low |
| R4 | Event delivery delay / loss | Reliability | Medium | Low | Event Grid retry + periodic reconciliation job | Low |
| R5 | Key rotation missed | Security | Medium | Medium | Automated reminder + dashboard aging report | Low |
| R6 | ADF region outage | Availability | High | Low | DR plan Phase 2; export config; redeploy to paired region | Medium |
| R7 | Cost overrun due to unused logs | Cost | Medium | Medium | Adjust retention, sampling strategy, dashboard review | Low |
| R8 | Schema evolution for downstream parsing | Extensibility | Medium | Medium | Versioned parsers + ADR governance | Low |
| R9 | Policy misconfiguration blocks deployment | Deployment | Medium | Medium | Pre-deploy policy validation stage | Low |
| R10 | Accidental deletion (non-immutable) | Data Loss | High | Low | Enable soft delete / versioning; consider immutability | Low |
| R11 | Partner credential compromise | Security | High | Low | IP allowlists, rotation, anomaly detection (volume anomalous) | Medium |
| R12 | Duplicate processing due to race | Data Quality | Low | Medium | Checksum + metadata dedupe flag | Low |
| R13 | Metadata store drift vs. actual blobs | Governance | Medium | Medium | Reconciliation batch job daily | Low |
| R14 | Purview cost escalation | Cost | Medium | Medium | Scope scans; schedule off-peak | Low |
| R15 | Insufficient operational staffing | Operations | High | Medium | Automation + cross-training + clear runbooks | Medium |

## 6. Risk Scoring Approach

Qualitative scale: Impact (Low/Medium/High) aligned to cost of downtime or compliance exposure. Likelihood estimated from historical patterns or industry norms. Residual risk recalculated after mitigation adoption; tracked quarterly.

## 7. Risk Monitoring Cadence

| Activity | Frequency | Owner |
|----------|-----------|-------|
| Risk review workshop | Quarterly | Platform Lead |
| Metrics/NFR review | Monthly | Operations |
| Security posture assessment | Quarterly | Security Team |
| Capacity trend analysis | Monthly | Data Engineering |

## 8. Open NFR Questions

- Confirm exact retention timeline & WORM necessity
- Define whether cross-region DR is mandated in Year 1
- Determine acceptable cost ceiling (monthly budget guardrail)

---
