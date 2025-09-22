# Functional Requirements (Draft v0.1)

## 1. Purpose
Define partner-facing functional capabilities and user stories for the Partner Self-Service Portal MVP.

## 2. User Roles
- Partner Admin: Full partner management (users, keys, credentials) + read dashboards.
- Standard User: Read-only dashboards & file status + manage own alert preferences.

## 3. Feature Matrix
| Capability | Standard | Admin | Notes |
|------------|----------|-------|-------|
| View dashboards | ✓ | ✓ | Partner scoped |
| View file status timeline | ✓ | ✓ | Filter by date range |
| Download SFTP host key info | ✓ | ✓ | Public info only |
| Submit credential rotation request | ✗ | ✓ | Creates audit event |
| Upload/replace PGP public key | ✗ | ✓ | Validation & size limit |
| Deactivate PGP key | ✗ | ✓ | Soft deactivate (revocable) |
| View key history | ✓ | ✓ | Status + timestamps |
| Manage users (invite/remove/change role) | ✗ | ✓ | Email invite flow |
| Manage alert preferences | ✓ (own) | ✓ (own + defaults) | Categories enumerated |
| View audit log | ✗ | ✓ | Filter by actionType |

## 4. User Stories (Representative)
### 4.1 Credentials & Keys
- As a Partner Admin, I can upload a new PGP public key so future outbound encrypted acknowledgments use it.
- As a Partner Admin, I can request SFTP credential rotation so security best practices are followed.
- As a Standard User, I can view active PGP key fingerprint to verify encryption trust.

### 4.2 Observability & Files
- As a Standard User, I can view daily ingestion counts and success vs reject percentages to monitor health.
- As a Standard User, I can search files by date range to see processing status and ack timestamps.
- As a Partner Admin, I can export (CSV) a list of file status records for a support ticket.

### 4.3 Alerts
- As a Standard User, I can enable email alerts for high reject rate spikes to react quickly.
- As a Partner Admin, I can define default alert preferences new users inherit.

### 4.4 User Management
- As a Partner Admin, I can invite a new user by email to grant portal access.
- As a Partner Admin, I can disable a user to immediately revoke access.
- As a Partner Admin, I can promote a Standard User to Admin to delegate management.

### 4.5 Auditing
- As a Partner Admin, I can view a chronological list of configuration change events for forensics.

## 5. Detailed Functional Requirements
### 5.1 PGP Key Management
- Accept ASCII-armored public keys only.
- Enforce max size 10 KB.
- Validate key fingerprint server-side; store fingerprint + uploadedAt.
- Allow marking previous key deprecated while keeping for historical verification.

### 5.2 SFTP Credential Rotation Workflow
- Admin submits rotation request with optional note.
- System logs audit event with status "Requested".
- (Future) When ops fulfills off-platform, they mark completed via internal tool (not MVP scope) -> placeholder API accepted but disabled in production until process defined.

### 5.3 File Status Timeline
- Query parameters: `from` (UTC ISO 8601), `to`, pagination cursor or `page/size`.
- Each record includes processing milestones & ack statuses (null if pending).
- Sort descending by `receivedAt` default.

### 5.4 Dashboards
- Provide aggregated metrics endpoints returning precomputed partner-scoped stats (no client heavy joins).
- Latency metrics: p50, p95, p99 per ack type for selected window.
- Reject mix: counts by rejection category (syntax, envelope, routing).

### 5.5 Alert Preferences
- Categories: latency, rejects, anomalies, backlog, keyExpiry.
- Store enabled flag per category.
- Email channel only (MVP).

### 5.6 User Invitations
- Admin submits email; system generates invite token (time-limited 72h) stored hashed.
- Upon acceptance (identity sign-up), API finalizes user record linking B2C objectId.

### 5.7 Authorization Enforcement
- Server derives partnerId from token claim; ignores path attempts to change it.
- Role-based checks at controller/service layer.

### 5.8 Audit Logging
- Every mutation (key upload, user change, alert pref change, rotation request) emits an audit event with correlationId.

## 6. Non-MVP Deferred Functional Items
- Web-based file upload
- Webhooks for alerts
- SLA profile override per partner
- Fine-grained per-user custom roles
- Multi-factor preference management inside portal UI

## 7. Acceptance Criteria (Representative)
- PGP key upload rejects >10KB file with clear validation message.
- Unauthorized user (Standard) receives 403 when attempting key upload.
- File status endpoint returns only records for caller's partnerId even if other ID supplied.
- Audit log contains event after each successful credential rotation request.

## 8. Open Questions
- OPEN: Should deprecated PGP keys remain retrievable for how long? (Need retention policy)
- OPEN: CSV export size limit & throttling parameters?
- OPEN: Should metrics endpoints allow custom grouping intervals (e.g., 1h vs 24h)?

## 9. References
- `AI_PROJECT_OVERVIEW.md`
