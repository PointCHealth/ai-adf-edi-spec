# Healthcare EDI Ingestion – Operations & Runbook Specification

## 1. Purpose

Provide standardized operational procedures, monitoring strategy, incident response playbooks, and cost management practices for the EDI ingestion platform.

## 2. Operational Scope

- Routine monitoring (pipelines, latency, failures)
- Partner onboarding/offboarding
- Quarantine handling & reprocessing
- Key rotation & credential hygiene
- Capacity & cost optimization

## 3. Daily/Weekly Operational Checklist

| Frequency | Task | Tooling |
|----------|------|---------|
| Daily | Review failed pipeline runs | ADF Monitor / Log Analytics query |
| Daily | Check quarantine counts and reasons | Log Analytics dashboard |
| Daily | Validate ingestion latency p95 < SLO | Workbook metric panel |
| Daily | Inspect security alerts (Storage/Key Vault) | Sentinel/Defender alerts |
| Weekly | Review duplicate & validation failure trends | Kusto saved query |
| Weekly | Verify partner uploads vs. expected schedule | Partner SLA report |
| Weekly | Policy compliance drift summary | Azure Policy compliance view |

## 4. Monitoring & Dashboards

| Dashboard Panel | Query / Metric | Purpose |
|-----------------|----------------|---------|
| Ingestion Latency | processedUtc - receivedUtc distribution | SLA tracking |
| Failure Breakdown | Count by validationStatus | Root cause focus |
| Quarantine Trend | Time series of quarantined files | Anomaly detection |
| Top Partners by Volume | Count per partnerCode | Capacity planning |
| Large Files (>25MB) | List + size | Performance risk |
| Duplicate Rate | duplicates / total | Data hygiene |
| Routing Latency | publishTime - validationCompleteTime | Routing SLO |
| Routing DLQ Depth | Dead-letter count per subscription | Reliability risk |
| Outbound Assembly Latency | filePersisted - lastOutcomeReady | Response SLO |
| Ack Publish Count | Outbound acknowledgments per type | Throughput |
| Control Number Retry Count | Avg retries per window | Health of counter store |

## 5. Key Log Analytics Queries (Samples)

### 5.1 Quarantine Summary (Kusto)

```kusto
EDIIngestion_CL
| where validationStatus_s == 'QUARANTINED'
| summarize count() by quarantineReason_s, bin(TimeGenerated, 1d)
| order by count_ desc
```

### 5.2 Latency Distribution

```kusto
EDIIngestion_CL
| extend latencySec = datetime_diff('second', processedUtc_t, receivedUtc_t) * -1
| summarize p50=percentile(latencySec, 50), p95=percentile(latencySec, 95) by bin(TimeGenerated, 1h)
```

### 5.3 Partner SLA Compliance

```kusto
EDIIngestion_CL
| summarize totalFiles=count(), late=countif(processedUtc_t > receivedUtc_t + 5m) by partnerCode_s, bin(TimeGenerated, 1d)
| extend pctLate = todouble(late) / todouble(totalFiles) * 100
```

### 5.4 Routing Latency

```kusto
RoutingEvent_CL
| extend latencyMs = toint( (publishTime_t - validationCompleteTime_t) / 1ms )
| summarize p50=percentile(latencyMs,50), p95=percentile(latencyMs,95) by bin(TimeGenerated, 15m)
```

### 5.5 Routing DLQ Monitor (Service Bus Metrics Ingested)

```kusto
AzureMetrics
| where Resource == 'edi-routing' and MetricName == 'DeadletteredMessages'
| summarize maxTotal=max(Total) by bin(TimeGenerated, 5m)
| where maxTotal > 0
```

### 5.6 Outbound Assembly Latency

```kusto
AckAssembly_CL
| extend latencyMs = toint( (filePersistedTime_t - lastOutcomeReadyTime_t) / 1ms )
| summarize p50=percentile(latencyMs,50), p95=percentile(latencyMs,95) by bin(TimeGenerated, 30m)
```

### 5.7 Control Number Retry Outliers

```kusto
AckAssembly_CL
| where controlNumberRetries_d > 3
| project TimeGenerated, partnerCode_s, controlNumberRetries_d, assemblyId_g
```

## 6. Alert Playbooks

| Alert | Trigger Example | Immediate Action | Escalation |
|-------|-----------------|------------------|------------|
| Pipeline Failure Spike | >3 failures in 10m | Review latest failed run output | Escalate to Data Eng on-call |
| Quarantine Surge | >5% daily volume | Inspect quarantine reasons query | Security if virus/security reason |
| Latency Breach | p95 > 5 min for 30m | Check pipeline queue/backlog | Scale review / IR config |
| Duplicate Anomaly | DuplicateRate >2% | Verify partner resend behavior | Partner Mgmt contact |
| Storage Threat Alert | Defender high severity | Validate file path & hash | Security Incident Process |
| Routing Publish Failures | >5 failed publishes in 10m | Inspect Function logs; test Service Bus send | Escalate to Platform Eng |
| Routing DLQ Growth | DLQ count >0 sustained 15m | Peek DLQ; identify failing subscriber | Notify owning subsystem team |
| Outbound Assembly Failures | >2 failed assemblies in 30m | Review AckAssembly_CL errorReason | Escalate to Outbound Dev |
| Control Number Retry Spike | Avg retries >3 in 15m | Check counter store concurrency/locks | Platform Eng |

## 7. Runbook: Partner Onboarding

1. Create partner entry in `config/partners/partners.json` (status=draft).
2. Generate SFTP local user with SSH key; restrict home dir.
3. Add expected transaction sets + frequency expectations.
4. PR review & merge; deploy config to dev; send test key instructions.
5. Partner sends test file; validate ingestion end-to-end.
6. Promote config to test/prod; mark status=active.
7. Document partner SLA & contacts.

## 8. Runbook: Partner Offboarding

1. Disable SFTP user (local user disable / remove public key).
2. Update partner config status=inactive.
3. Revoke residual RBAC (if any).
4. Retain historical data per retention policy; no deletions.
5. Log offboarding record (ticket + timestamp).

## 9. Runbook: Quarantine Triage

| Step | Action |
|------|--------|
| 1 | Retrieve metadata record by ingestionId |
| 2 | Determine quarantineReason (naming, integrity, security) |
| 3 | If security (virus), escalate; do not reprocess |
| 4 | If naming/validation fixable, correct upstream or rename copy |
| 5 | Trigger `pl_reprocess` with originalBlobPath |
| 6 | Confirm success in metadata & close incident |

## 10. Runbook: Reprocessing

1. Identify original blob path (raw or quarantine).
2. Validate no active processing lock (retryCount < threshold e.g., 5).
3. Launch reprocess pipeline with parameters.
4. Monitor run; verify updated metadata (validationStatus=SUCCESS or remains QUARANTINED).
5. Document action in ticket.

## 11. Runbook: Routing Publish Failure

| Step | Action |
|------|--------|
| 1 | Identify failed publish logs (RoutingEvent_CL where publishStatus == 'FAILED') |
| 2 | Confirm Service Bus namespace health (Azure Portal metrics: IncomingRequests, UserErrors) |
| 3 | Retry manually by invoking `func_router_dispatch` with original `ingestionId` |
| 4 | If repeated failure: disable further routing via feature flag (Key Vault) |
| 5 | Open incident ticket; attach correlation IDs |

## 12. Runbook: Routing DLQ Drain

| Step | Action |
|------|--------|
| 1 | Peek DLQ messages for subscription (Service Bus Explorer) |
| 2 | Classify failure cause (parsing, auth, transient) |
| 3 | For transient (timeout), resubmit to active queue; for parsing, escalate to subsystem owner |
| 4 | Log resolution notes; ensure metrics return to baseline |

## 13. Runbook: Outbound Assembly Failure

| Step | Action |
|------|--------|
| 1 | Query AckAssembly_CL where status == 'FAILED' |
| 2 | Review errorReason (controlNumberCollision, templateValidation, storageWrite) |
| 3 | If control number collision: pause orchestrator (feature flag) and inspect counter store values |
| 4 | Correct template or data issue; rerun assembly for affected batch |
| 5 | Validate published acknowledgment integrity (segment counts, checksum) |

## 14. Runbook: Control Number Counter Integrity

| Step | Action |
|------|--------|
| 1 | Export last 100 increments (Table query) |
| 2 | Verify monotonic sequence without gaps (expected +1) |
| 3 | If gap found: determine if file/ack associated missing; document gap or regenerate if safe |
| 4 | Backup current counter state (JSON) before any manual correction |
| 5 | Update counter only via Function with forced increment; never edit directly in Table UI |

## 11. Key Rotation Procedure (SFTP)

| Step | Action |
|------|--------|
| 1 | Notify partner T-15 days (automated email) |
| 2 | Receive new public key; validate format |
| 3 | Add new key to local user (keep old temporarily) |
| 4 | Partner confirms cutover |
| 5 | Remove old key; update key metadata timestamp |
| 6 | Log rotation completion |

## 12. Capacity Planning

| Dimension | Considerations | Metric Source |
|----------|---------------|---------------|
| Storage Growth | Raw + quarantine accumulation, lifecycle policies | Storage metrics + cost analysis |
| Pipeline Concurrency | Activity queue length, execution time | ADF run history |
| Event Throughput | Burst file arrivals per minute | Blob created events count |
| Function Scaling (optional) | Execution duration, cold start | Function App metrics |

## 13. Cost Management

| Area | Optimization Strategy |
|------|----------------------|
| Storage | Lifecycle policies (Cool/Archive), compression (zip), delete quarantine after retention |
| Compute (ADF) | Consolidate small activities, avoid unnecessary Data Flows, use copy concurrency tuning |
| Function | Use consumption plan unless sustained load justifies premium |
| Logging | Filter verbose debug logs; set retention per table |
| Purview | Scope scans to required collections |

## 14. Operational Metrics Targets

| Metric | Target |
|--------|--------|
| IngestionLatencySeconds p95 | < 300 |
| ValidationFailureRate | < 2% |
| QuarantineResolutionTime | < 24h |
| DuplicateRate | < 1% |
| MeanFileSizeMB | Tracked only |
| RoutingLatencyMs p95 | < 2000 |
| OutboundAssemblyLatencyMs p95 | < 10 min |
| RoutingDLQCount | 0 sustained |
| OutboundErrorRate | < 1% |
| ControlNumberRetries Avg | < 2 |

## 15. Business Continuity & Recovery

| Aspect | Strategy |
|--------|----------|
| Backup (metadata) | Raw zone + Log Analytics (export optional) |
| DR Region | Phase 2 (geo-paired region replication) |
| RPO | 15 minutes (log-based) |
| RTO | 2 hours (redeploy infra + config) |
| Immutable Raw Files | Optional WORM enabling ensures non-tampering |

## 16. Performance Tuning Guidelines

- Separate validation vs. copy steps to parallelize large file handling.
- Enable multi-threaded copy (ADF integration runtime auto-optimization) for > 25MB.
- Avoid unnecessary metadata lookups (cache partner config in memory of Function call).
- Use blob tags for quick partner/transaction filtering.

## 17. Tooling & Automation Enhancements (Future)

| Idea | Benefit |
|------|--------|
| Automated partner SLA dashboard | Proactive variance detection |
| ML-based anomaly detection on volume | Early detection of partner system issues |
| Self-service partner portal | Reduced ops load |
| Automated lineage drift detector | Governance confidence |
| Routing subscription rule drift checker | Ensures filters align with config |
| Control number anomaly detector | Early detection of gaps/collisions |
| Outbound response SLA tracker | Ensures ack generation within SLA |

## 18. Open Operational Issues

- Confirm AV scanning integration timeline
- Decide on immutable blob retention policy activation
- Evaluate cost of Purview scanning vs. business value

---
