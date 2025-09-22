# Operations Runbook (Draft v0.1)

## 1. Purpose
Provide operational procedures for key partner portal tasks and incident response.

## 2. PGP Key Upload Review
1. Admin uploads key; system logs `KeyUploaded` audit event.
2. Verify fingerprint matches partner ticket if provided.
3. Ensure only one active key remains (deprecate previous).
4. Communicate success to partner if manual confirmation process exists.

## 3. SFTP Credential Rotation Request Handling (Manual MVP)
1. Monitor rotation request queue (placeholder: RotationRequest table status = 'Requested').
2. Generate new credential (off-platform) per internal SOP.
3. Update SFTP server configuration.
4. Update portal DB: insert new SftpCredential row (Status=active), set old credential Status=superseded.
5. Mark RotationRequest.Status='Completed'; emit audit event.

## 4. User Invitation Lifecycle
1. Admin issues invite; rotation token stored hashed.
2. If invite not accepted within 72h, expire and audit.
3. On acceptance, ensure partnerId claim matches invite partner.

## 5. Alert Preference Change Verification
- Confirm `AlertPrefChanged` events appear in `PartnerPortalAudit_CL` within 5 minutes.

## 6. Incident: High Reject Rate Alert
1. Validate alert (check query `syntax_reject_rate_999.kql` output for partner).
2. Determine scope (single partner vs global).
3. If isolated, contact partner admin with last successful file timestamp.
4. If widespread, escalate to validation pipeline incident.
5. Document in incident log referencing correlationId samples.

## 7. Incident: Latency SLA Breach
1. Retrieve metrics summary for affected timeframe.
2. Correlate with platform events (Service Bus delays, function scaling) via central logs.
3. If partner-specific, inspect their file volume spike.

## 8. Audit Log Forensics
- Query AuditEvent by partner and time range.
- Export results (CSV) ensuring no PHI included.

## 9. Key Revocation Procedure
1. Admin requests revocation citing reason.
2. Confirm key not currently sole active key (upload replacement first if needed).
3. Set status=revoked; audit event logged.
4. Ensure downstream encryption pipeline no longer uses revoked fingerprint.

## 10. Access Revocation (User Disable)
1. Admin disables user; status set disabled.
2. Verify no active sessions (token TTL minimal; optional immediate revoke via B2C API).
3. Audit event `UserDisabled` present.

## 11. Monitoring Checklist
Daily:
- Review error rate query (< 5% failure target).
- Check pending rotation requests older than 7 days.
Weekly:
- Key expiry horizon (< 30 days) follow-up.
- Audit event anomaly scan (# events vs baseline).

## 12. Open Questions
- OPEN: Automate rotation workflow state transitions via background job?
- OPEN: Need on-call roster integration for partner-specific incidents?

## 13. References
- `08-observability.md`
