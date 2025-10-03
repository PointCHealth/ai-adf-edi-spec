# Nonfunctional Requirements (Draft v0.1)

## 1. Purpose

Capture cross-cutting quality attributes for the Partner Portal MVP aligned with existing platform invariants.

## 2. Performance

- Dashboard aggregate API p95 latency: <= 3s for partners with <= 10k file records in 30-day window.
- File status pagination: each page retrieval p95 <= 2s (page size 50).
- Initial portal shell load (Angular, cached/CDN) under 2s p75 on broadband.

## 3. Scalability

- Design for linear scaling up to 5k partners, 100 concurrent sessions each (peak bursts) with horizontal App Service plan scaling.
- Partition large file status queries via indexed `partnerId + receivedAt`.

## 4. Availability

- Target 99.5% monthly for MVP (no multi-region yet); future stretch 99.9%.
- Degradation mode: If metrics API fails, portal still loads static UI and communicates partial outage.

## 5. Security

- Enforce HTTPS only; HSTS configured.
- All requests require valid JWT with partnerId claim; no anonymous endpoints (except health/probe).
- Input validation on key uploads (size, format) & rotation request notes (length <= 500 chars).
- Secrets stored only in Key Vault (SFTP password if needed, though ideally not surfaced to partner—only status).

## 6. Privacy & Data Handling

- No PHI retained; portal DB stores metadata only (fingerprints, timestamps, counts).
- Audit logs exclude file payload contents.

## 7. Compliance

- Align with HIPAA principles by avoiding PHI exposure and ensuring encryption in transit & at rest.
- Support future SOC2 evidence by maintaining immutable audit logs.

## 8. Observability

- Emit structured logs with correlationId (propagate from frontend request X-Correlation-ID or generate server-side).
- Metrics for: request duration, auth failures, key upload attempts, alert preference changes.
- Log tables: `PartnerPortalAudit_CL`, `PartnerPortalUsage_CL`.

## 9. Reliability & Resilience

- Retry transient DB operations (EF Core Polly policy: 3 attempts exponential backoff starting 200ms).
- Graceful handling of Log Analytics ingestion delays (UI surfaces "Data updating" badge if metrics older than threshold).

## 10. Maintainability

- Angular feature modules per domain (dashboard, files, keys, users, alerts).
- API layering: Controllers -> Application Services -> Domain -> Infrastructure.
- Clear separation for testability; domain logic unit test coverage target 70%+ (future pipeline addition).

## 11. Localization & Accessibility

- English only MVP; externalization of strings prepared.
- WCAG 2.1 AA targets for key pages (contrast, keyboard navigation, ARIA landmarks).

## 12. Capacity Planning Inputs

- Estimated file records per partner per day (assumption): 2k; retention in SQL 90 days (hot), older via Log Analytics queries.

## 13. Disaster Recovery

- Backup: Azure SQL automated backups, retention 7 days MVP; future geo-restore.
- Recovery Time Objective (RTO): < 4 hours MVP.
- Recovery Point Objective (RPO): < 1 hour (based on backup cadence + acceptable data reconstruction from logs).

## 14. Open Questions

- OPEN: Should we adopt APIM early for centralized rate limiting & WAF?
- OPEN: Retention of PartnerPortalUsage_CL beyond 90 days—cost vs value?
- OPEN: Need for soft-delete restore window for user accounts?

## 15. References

- `AI_PROJECT_OVERVIEW.md`
