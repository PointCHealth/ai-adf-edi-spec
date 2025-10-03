# Observability (Draft v0.1)

## 1. Purpose

Define telemetry strategy, log taxonomy, and initial KQL queries enabling partner-scoped dashboards.

## 2. Log Tables

| Table | Purpose | Key Fields |
|-------|---------|-----------|
| PartnerPortalAudit_CL | Configuration & security-relevant changes | PartnerId, ActorUserId, ActionType, TargetType, TargetId, Timestamp, CorrelationId |
| PartnerPortalUsage_CL | Request metrics & UI usage events | PartnerId, UserId, Route, DurationMs, StatusCode, Timestamp, CorrelationId |

## 3. Event/Log Field Standards

- All records include `PartnerId`, `Timestamp` (UTC), `CorrelationId` (GUID), `Environment` tag.
- Audit events immutable; only appended.
- Usage events may include `LatencyBucket` derived dimension (future).

## 4. Metrics Derived

- Request latency percentiles per route.
- PGP key lifecycle counts (active vs deprecated vs revoked).
- Alert subscription enablement rate.
- Admin vs Standard user action distribution.

## 5. KQL Queries (Initial)

### 5.1 Request Latency Distribution

```kql
PartnerPortalUsage_CL
| where Timestamp > ago(24h)
| summarize p50=percentile(DurationMs,50), p95=percentile(DurationMs,95), p99=percentile(DurationMs,99) by Route
| order by p95 desc
```

### 5.2 High Error Rate Routes

```kql
PartnerPortalUsage_CL
| where Timestamp > ago(1h)
| summarize total=count(), failures=countif(StatusCode >= 500) by Route
| extend failureRate=failures * 1.0 / total
| where failureRate > 0.05
| order by failureRate desc
```

### 5.3 Recent Audit Events (Partner Scoped)

```kql
PartnerPortalAudit_CL
| where PartnerId == "<PartnerId>" and Timestamp > ago(7d)
| project Timestamp, ActionType, TargetType, TargetId, ActorUserId
| order by Timestamp desc
```

### 5.4 PGP Key Expiration Horizon

```kql
PgpKeyInventory_CL // future derived ingestion
| extend daysToExpiry = datetime_diff('day', ExpiresAt, now())
| where daysToExpiry between (0 .. 45)
| project PartnerId, Fingerprint, ExpiresAt, daysToExpiry
```

### 5.5 Alert Preference Adoption

```kql
PartnerPortalAudit_CL
| where ActionType == "AlertPrefChanged" and Timestamp > ago(30d)
| summarize changes=count() by PartnerId
| order by changes desc
```

## 6. Correlation Strategy

- Frontend generates GUID per browser session (Session-Correlation) + per request (X-Correlation-ID).
- Backend returns `TraceId` header (if different) for linking to distributed traces (future Application Insights integration).

## 7. Alerting Concepts

- High error rate (failureRate > threshold for consecutive 3 intervals) -> Ops channel.
- Elevated latency p95 > SLA threshold for 3 consecutive intervals.
- Key expiry within 30 days triggers partner email.

## 8. Open Questions

- OPEN: Should we unify portal logs into existing workspace tables vs separate new ones?
- OPEN: Need sampling for high-volume usage events or retain all initially?

## 9. References

- `AI_PROJECT_OVERVIEW.md`
