# Partner Self-Service Portal Overview (Draft v0.1)

## 1. Purpose

Introduce the Trading Partner Self-Service Portal extending the Healthcare EDI Ingestion & Acknowledgment Platform. Enables external trading partner users to manage secure exchange credentials and observe processing health for their own data only.

## 2. Scope (MVP)

In-Scope:

- SFTP credential visibility + rotation request workflow (no automated rotation yet)
- PGP public key upload / replace / deactivate
- Partner-scoped dashboards (ingestion volume, latency vs SLA, reject mix, control number continuity summary)
- File status timeline (received → validated → routed → ack statuses)
- User & role management (Partner Admin invites/removes Standard users)
- Alert preference management
- Audit log viewing (partner-local)

Out-of-Scope (MVP, deferred):

- Automated credential rotation execution
- Webhook / push notifications (email only initially)
- SLA customization per partner
- Web-based file upload (ingestion remains SFTP)
- PHI payload rendering

## 3. Stakeholders

- Trading Partner Admin Users
- Trading Partner Standard Users
- Internal Operations / Support (indirect consumers via logs / escalations)
- Security & Compliance Reviewers

## 4. Alignment with Platform Principles

- Reuses existing observability & control number invariants (AI_PROJECT_OVERVIEW sections 2, 5, 17)
- Maintains least privilege (partnerId claim scoping) and immutable event lineage
- Adds auditability for all configuration changes (new `PartnerPortalAudit_CL`)

## 5. Glossary Additions

- Partner Portal: External-facing application for partner self-service.
- Partner Admin: Role authorized to manage users, keys, credentials.
- Standard User: Role limited to read dashboards and manage own alert preferences.
- Credential Rotation Request: Logged intent to rotate SFTP credentials pending manual ops fulfillment.

## 6. Assumptions

- Identity provider: Azure AD B2C (external) with custom attribute `partnerId` and role claims.
- Angular frontend hosted via Azure Static Web Apps; .NET Core API on Azure App Service.
- Partner count moderate (< 5k) initial; scale considerations captured in Nonfunctional spec.
- Only partner public PGP keys stored (no private keys).

## 7. Constraints

- No PHI displayed or retained in portal DB.
- All API responses scoped to caller's partnerId (server enforcement; client cannot override).
- Latency metrics definitions mirror existing platform definitions.

## 8. Success Metrics (MVP)

- < 10 minutes average turnaround for partner key update visibility post upload.
- 100% of partner configuration changes audited.
- < 3 second p95 dashboard API latency for partner datasets under 10k file records.

## 9. Open Questions

- OPEN: Should rate limiting be introduced immediately (API Management) or deferred?
- OPEN: MFA enforcement at identity layer mandatory at launch?
- OPEN: Maximum retention period for audit events in Azure SQL vs Log Analytics?

## 10. References

- `AI_PROJECT_OVERVIEW.md`
- `ACK_SLA.md`
- Observability KQL under `queries/kusto/`
