# EDI Acknowledgment & Response SLA Quick Reference

Authoritative source sections: `docs/08-transaction-routing-outbound-spec.md` (Section 16), `docs/01-architecture-spec.md` Appendix A.

## 1. Scope

Fast operational reference for timing targets, trigger points, and key monitoring queries for technical (TA1, 999) and business (271, 277/277CA, 278 Response, 835) acknowledgments/responses.

## 2. SLA / Target Matrix

| Type | Target (Illustrative) | Start Clock | End Clock | Critical Metrics | Primary KQL Source |
|------|-----------------------|-------------|-----------|------------------|--------------------|
| TA1 | < 5 min | Ingestion event time | TA1 file persisted | TA1LatencyP95, TA1FailureRate | InterchangeValidation_CL |
| 999 | < 15 min | Ingestion event time | 999 file persisted | AckLatencyP95 (ackType=999), SyntaxRejectRate | AckAssembly_CL |
| 271 | < 5 min | 270 ingestion event | 271 file persisted | AckLatencyP95 (ackType=271), AAARejectSpike | AckAssembly_CL |
| 277CA | < 4 hrs | 837 routing publish | 277CA file persisted | AckLatencyP95 (ackType=277CA), ClaimValidationRejectRate | AckAssembly_CL + RoutingEvent_CL |
| 278 Response | < 15 min | 278 request ingestion | 278 response persisted | AckLatencyP95 (ackType=278R), PendingAuthCount | AckAssembly_CL |
| 277 (Status) | Batch (configurable) | Claim adjudication stage event | 277 file persisted | StatusLatencyDistribution | AckAssembly_CL |
| 835 | Payer SLA (e.g., weekly) | Payment cycle start event | 835 file persisted | RemitTimeliness, ControlTotalMismatch | AckAssembly_CL |

## 3. Operational Thresholds (Alert Triggers)

| Condition | Warning | Critical | Action |
|-----------|---------|----------|--------|
| 999LatencyP95 | > 900s 30m window | > 1200s 30m | Check pipeline backlog / function cold starts |
| TA1FailureRate | > 0.3% daily | > 0.5% daily | Inspect partner envelope formatting; validate ISA separators |
| SyntaxRejectRate (999 AK9=R) | > 2% daily | > 5% daily | Investigate recent deployment / partner batch anomalies |
| 277CA missing (claims) | > 3h for 95% | > 4h for 90% | Review claims intake queue & DLQ messages |
| 271LatencyP95 | > 180s | > 300s | Scale eligibility processing; check Service Bus latency |
| ControlNumberGapDetected | Single occurrence | Repeat within 24h | Audit counter store concurrency & reissue policy |

## 4. Key KQL Snippets

See `queries/kusto` added samples for implementation details.

### 4.1 Ack Latency (Generic)

```kusto
AckAssembly_CL
| where TimeGenerated > ago(24h)
| extend latencySeconds = datetime_diff('second', filePersistedTime, triggerStartTime) * -1
| summarize p95(latencySeconds), avg(latencySeconds) by ackType
```

### 4.2 999 Syntax Reject Rate

```kusto
AckAssembly_CL
| where TimeGenerated > ago(7d) and ackType == '999'
| summarize total=count(), rejects=countif(ak9Status == 'R') by bin(TimeGenerated, 1d)
| extend rejectRate = rejects * 100.0 / total
```

### 4.3 TA1 Failure Rate

```kusto
InterchangeValidation_CL
| where TimeGenerated > ago(7d)
| summarize total=count(), failures=countif(status == 'REJECT') by bin(TimeGenerated, 1d)
| extend failureRate = failures * 100.0 / total
```

### 4.4 277CA Timeliness

```kusto
AckAssembly_CL
| where ackType == '277CA' and TimeGenerated > ago(7d)
| extend latencyHours = datetime_diff('minute', filePersistedTime, related837RoutingTime) / 60.0 * -1
| summarize p50=percentile(latencyHours,50), p95=percentile(latencyHours,95) by bin(TimeGenerated,1d)
```

### 4.5 Control Number Gap Detection

```kusto
AckAssembly_CL
| where TimeGenerated > ago(30d)
| summarize makeset(interchangeControlNumber) by ackType, partnerCode, day=bin(TimeGenerated,1d)
| extend sorted = array_sort_asc(todynamic(set_interchangeControlNumber))
// Compare sequential increments (pseudo: custom plugin or mv-apply to detect non+1 deltas)
```

## 5. Runbook Crosslinks

| Scenario | Runbook Reference |
|----------|-------------------|
| Elevated TA1 rejects | Interchange Validation Runbook |
| 999 spike | Syntax Error Investigation Runbook |
| Missing 277CA | Claims Intake Backlog Runbook |
| Control number gap | Counter Store Integrity Runbook |
| Slow 271 | Eligibility Performance Runbook |

## 6. Governance Notes

- All SLAs are internal targets until contractually committed; changes require Architecture + Compliance approval.
- Metric field names must remain stable; any schema drift triggers update to this reference.

---
