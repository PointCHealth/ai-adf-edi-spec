# Architecture (Draft v0.1)

## 1. Purpose

Describe logical, application, and integration architecture for the Partner Portal.

## 2. High-Level Logical View

Components:

- Angular SPA (Static Web Apps) – UI, auth token acquisition, role-based routing guards.
- .NET Core Web API – REST endpoints, domain orchestration, EF Core data access.
- Azure SQL Database – Portal relational data (users, keys, credentials, alert prefs).
- Key Vault – Secure storage of SFTP credential secrets (if necessary) & encryption keys.
- Log Analytics – Audit & usage telemetry ingestion (`PartnerPortalAudit_CL`, `PartnerPortalUsage_CL`).
- Identity (Azure AD B2C) – External user authentication and JWT issuance with partnerId claim.

## 3. Request Flow (Typical Dashboard Data Fetch)

1. User authenticates via B2C; obtains ID & access token.
2. Angular calls `/api/v1/metrics/summary` with bearer token & generated `X-Correlation-ID`.
3. API validates token, extracts `partnerId`, queries SQL & (future) aggregated cache.
4. API logs usage event with correlationId.
5. Response returned; Angular renders charts.

## 4. Module Decomposition

- Web (Controllers) – Minimal logic; maps DTOs.
- Application Services – Use cases (UploadKey, RequestRotation, FetchFileStatus).
- Domain – Entities, value objects (KeyFingerprint), domain events (KeyUploadedEvent).
- Infrastructure – EF repositories, Key Vault adapters, logging providers.
- Shared – Correlation, result wrappers, error codes.

## 5. Sequence Diagrams

See `diagrams/` for Mermaid sources.

- `architecture-overview.mmd` (this portal context)
- `user-invite-sequence.mmd`
- `pgp-key-lifecycle.mmd`

## 6. Data Access Patterns

- All queries filtered by `partnerId` at repository layer (append predicate guard).
- Write operations wrapped in transaction when multiple tables affected.
- Optimistic concurrency for key deactivation (rowversion column).

## 7. Caching Strategy (MVP)

- Client-side ephemeral caching (per page) only; server caching deferred until scale demands.
- Potential future: Azure Cache for Redis for metrics aggregates.

## 8. Error Handling Strategy

- Standard error envelope: `{ traceId, code, message, details? }`.
- Codes (initial): `VALIDATION_ERROR`, `UNAUTHORIZED`, `FORBIDDEN`, `NOT_FOUND`, `CONFLICT`, `RATE_LIMIT` (future), `INTERNAL_ERROR`.

## 9. API Versioning

- Base path `/api/v1`; breaking changes create `/api/v2` with side-by-side deployment window.

## 10. Security Architecture

- Zero trust boundary at API; partnerId entirely claim-driven.
- Angular never stores tokens in localStorage (session storage or in-memory + silent renew).
- Strict Content Security Policy (CSP) to limit script sources.

## 11. Logging & Telemetry

- Correlation ID from header or generated.
- Audit events = domain event handlers publishing structured JSON.
- Usage events = per-request middleware capturing latency, route template.

## 12. Deployment Topology (MVP)

- Static Web Apps (Free/Standard) for Angular.
- App Service (B1/S1) for API with staging slots (blue/green capability).
- Single SQL instance (zone redundant not required MVP).
- Single region (future multi-region DR).

## 13. Open Questions

- OPEN: Introduce API Management gateway before production? (Policy injection & WAF)
- OPEN: Shared vs dedicated Key Vault instance for portal secrets?

## 14. References

- `AI_PROJECT_OVERVIEW.md`
