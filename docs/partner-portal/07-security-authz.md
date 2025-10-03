# Security & Authorization (Draft v0.1)

## 1. Purpose

Describe authentication, authorization, and security controls for Partner Portal.

## 2. Identity & Authentication

- Azure AD B2C chosen (assumption) for external partner identities.
- JWT access tokens include: `sub`, `partnerId`, `roles`, `iat`, `exp`.
- MFA enforced at B2C policy layer (OPEN: confirm mandatory at launch).

## 3. Authorization Model

| Action | Standard | Admin | Enforcement |
|--------|----------|-------|-------------|
| View dashboards | ✓ | ✓ | Controller policy + partner scope |
| View file status | ✓ | ✓ | Controller policy + partner scope |
| Upload PGP key | ✗ | ✓ | Role check |
| Deprecate/Revoke PGP key | ✗ | ✓ | Role check |
| Request credential rotation | ✗ | ✓ | Role check |
| Manage users | ✗ | ✓ | Role check |
| Update alert preferences (self) | ✓ | ✓ | Ownership check |
| View audit events | ✗ | ✓ | Role check |

## 4. Partner Scope Enforcement

- Server obtains `partnerId` from token; rejects requests if path/body indicates different partner.
- Repository layer automatically injects `partnerId` predicate.

## 5. Data Protection

- No storage of partner private keys.
- PGP public keys stored raw only for distribution; fingerprint used for integrity verification.
- SFTP password values never shown once stored (display masked + last rotated date only).

## 6. Secrets Management

- Key Vault stores encryption-at-rest keys for any confidential credential material.
- App Service uses system-managed identity to access Key Vault via least-privilege access policy.

## 7. Input Validation

- PGP key size <= 10 KB; ASCII-armored format check.
- Rotation request note length <= 500.
- Email normalized to lowercase; regex basic validation prior to invite issuance.

## 8. Threat Mitigations

| Threat | Mitigation |
|--------|------------|
| Token replay | Short token lifetime + refresh flow; correlation logging |
| Horizontal privilege escalation | Strict partnerId claim filtering server-side |
| Key upload malware embedding | Reject non-text / enforce ASCII; (future) antivirus scan |
| Brute force invite acceptance | Expiring invite tokens (72h) + single-use flag |
| Sensitive data exfiltration | No PHI stored; principle of minimal metadata exposure |
| SQL injection | Parameterized EF Core; static queries prepared |

## 9. Audit Logging

- Each privileged action emits `AuditEvent` + `PartnerPortalAudit_CL` entry.
- Fields: `PartnerId`, `ActorUserId`, `ActionType`, `TargetType`, `TargetId`, `Timestamp`, `CorrelationId`.

## 10. Session & Token Handling

- Angular stores tokens in memory (fallback to sessionStorage if needed) to reduce XSS risk.
- CSP, X-Frame-Options DENY, SameSite cookies for any refresh tokens.

## 11. Open Questions

- OPEN: Adopt API Management + WAF for IP allow/deny lists MVP or later?
- OPEN: RotationRequest status update authentication path (internal ops) requires separate trust boundary—how modeled?

## 12. References

- `05-api-spec-draft.md`
