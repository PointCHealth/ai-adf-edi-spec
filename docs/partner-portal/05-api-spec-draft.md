# API Specification Draft (v0.1)

## 1. Purpose

Define initial REST API surface (v1) for Partner Portal.

## 2. Conventions

- Base URL: `/api/v1`.
- JSON only; UTF-8.
- Standard error envelope: `{ traceId, code, message, details? }`.
- Pagination: `?page=<n>&pageSize=<m>` (default page=1, pageSize=50, max 200) OR cursor variant `?cursor=` (future).
- Filtering: ISO 8601 UTC times (`from`, `to`).

## 3. Authentication & Authorization

- JWT Bearer tokens issued by Azure AD B2C; required `partnerId` and `roles` claims.
- Server enforces partner scope; ignore any partnerId in path not matching claim (return 403 if mismatch).

## 4. Resource Endpoints

### 4.1 Health

`GET /api/health` -> 200 simple status (no auth if used for probe; TBD) .

### 4.2 Users

`GET /api/v1/partner/users` (Admin) – list users.
`POST /api/v1/partner/users/invite` (Admin) – body `{ email, role }` -> 202 with inviteId.
`POST /api/v1/partner/users/invite/{inviteId}/accept` (Public callback?) – Completed via identity sign-up (MVP may stub).
`PATCH /api/v1/partner/users/{userId}` (Admin) – change role/status.
`GET /api/v1/partner/users/me` – self profile.

### 4.3 PGP Keys

`GET /api/v1/partner/pgp-keys` – list (include active + history).
`POST /api/v1/partner/pgp-keys` (Admin) – multipart or JSON with ASCII armored key `{ publicKeyArmored }`.
`POST /api/v1/partner/pgp-keys/{keyId}/deprecate` (Admin) – mark deprecated.
`POST /api/v1/partner/pgp-keys/{keyId}/revoke` (Admin) – mark revoked (cannot undo).

### 4.4 SFTP Credentials

`GET /api/v1/partner/sftp/credentials` (Admin) – list current + last rotated.
`POST /api/v1/partner/sftp/credentials/rotation-request` (Admin) – body `{ note? }` -> 202.

### 4.5 Alert Preferences

`GET /api/v1/partner/alerts/preferences` – list user preferences.
`PUT /api/v1/partner/alerts/preferences` – replace entire set `[ { category, enabled } ]`.

### 4.6 Metrics & Dashboards

`GET /api/v1/partner/metrics/summary?from=&to=` – returns ingestion counts, latency percentiles, reject percentages.
`GET /api/v1/partner/metrics/control-numbers/gaps?from=&to=` – summary of detected gaps (if integrated).

### 4.7 File Status

`GET /api/v1/partner/files?from=&to=&page=&pageSize=` – paginated file status list (sort desc receivedAt).
`GET /api/v1/partner/files/{fileId}` – detailed status (if id resolvable) else 404.

### 4.8 Audit Events

`GET /api/v1/partner/audit?from=&to=&actionType=&page=&pageSize=` (Admin) – list.

## 5. Data Models (Representative)

### UserSummary
```json
{
  "id": "guid",
  "email": "user@example.com",
  "role": "Admin",
  "status": "active",
  "mfaEnabled": true,
  "createdAt": "2025-09-22T12:34:56Z"
}
```

### PgpKey
```json
{
  "id": "guid",
  "fingerprint": "ABCD1234...",
  "uploadedAt": "2025-09-22T12:34:56Z",
  "expiresAt": null,
  "status": "active",
  "version": 2
}
```

### FileStatus
```json
{
  "fileName": "837_20250922_120000.txt",
  "receivedAt": "2025-09-22T12:00:00Z",
  "validationStatus": "accepted",
  "routingStatus": "completed",
  "ack": { "ta1": "accepted", "ack999": "accepted", "ack277ca": "pending" },
  "interchangeControlNumber": 123456789,
  "transactionSetCount": 10,
  "latency": { "ack999Seconds": 320 }
}
```

### MetricsSummary
```json
{
  "window": { "from": "2025-09-21T00:00:00Z", "to": "2025-09-22T00:00:00Z" },
  "ingestionCounts": { "total": 2050, "accepted": 2000, "rejected": 50 },
  "latency": { "ack999": { "p50": 120, "p95": 450, "p99": 900 } },
  "rejectMix": [ { "category": "syntax", "count": 30 }, { "category": "envelope", "count": 20 } ]
}
```

### Error Envelope
```json
{
  "traceId": "abcd-efgh",
  "code": "VALIDATION_ERROR",
  "message": "Key exceeds max size",
  "details": { "maxBytes": 10240 }
}
```

## 6. Status Codes (Representative)

- 200 OK: Successful retrieval / mutation (or 204 for no body operations future)
- 201 Created: Resource creation (e.g., key upload) with Location header
- 202 Accepted: Asynchronous processing (invite, rotation request)
- 400 Validation error
- 401 Missing/invalid token
- 403 Role or partner scope violation
- 404 Resource not found
- 409 Conflict (duplicate key fingerprint, concurrent update)
- 413 Payload too large (key upload)
- 429 Rate limit (future)
- 500 Internal error

## 7. Error Codes Mapping

| Code | Scenario |
|------|----------|
| VALIDATION_ERROR | Input fails schema/constraints |
| UNAUTHORIZED | Missing or invalid token |
| FORBIDDEN | Role insufficient / partner mismatch |
| NOT_FOUND | Resource not located |
| CONFLICT | Version mismatch, duplication |
| PAYLOAD_TOO_LARGE | Exceeds size limit |
| RATE_LIMIT | Too many requests (future) |
| INTERNAL_ERROR | Unhandled exception |

## 8. Versioning Strategy

- Only additive changes (new optional fields) within v1.
- Breaking changes trigger v2 path.

## 9. OpenAPI Generation

- Use Swashbuckle; group endpoints by feature tags (Users, Keys, Metrics, Files, Audit, Alerts).
- Include example schemas as shown.

## 10. Open Questions

- OPEN: Should file status retrieval support `continuationToken` instead of page number now?
- OPEN: Need endpoint to fetch active PGP key only (`/pgp-keys/active`) for lightweight client?
- OPEN: Should rotation requests have their own endpoint for status polling?

## 11. References

- `04-domain-model.md`
