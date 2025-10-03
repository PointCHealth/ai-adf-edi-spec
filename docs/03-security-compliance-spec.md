# Healthcare EDI Ingestion – Security & Compliance Specification

## 1. Purpose

Defines mandatory security, privacy, and compliance controls (HIPAA-aligned) for the Azure-based EDI ingestion platform.

## 2. Regulatory Context

- HIPAA (Privacy & Security Rules) – PHI safeguards
- HITECH – Breach notification requirements
- SOC 2 (Type II) alignment (if enterprise standard)
- Internal Data Classification: PHI / Sensitive

## 3. Threat Model (High Level)

| Asset | Threat Vector | Impact | Mitigation |
|-------|---------------|--------|-----------|
| SFTP credentials | Credential theft | Data exfiltration | Per-partner isolated account, strong key-only auth (preferred), rotation policy |
| Ingestion storage (landing) | Unauthorized access | PHI disclosure | Private endpoints, RBAC, ACL scoping, firewall, Defender for Storage |
| Data at rest | Improper encryption | Compliance violation | Default encryption (Microsoft-managed) or CMK with Key Vault + rotation |
| Pipeline runtime | Lateral movement | Expanded compromise | Managed Identities with least privilege |
| Metadata logs | Tampering | Loss of auditability | Append-only design + Log Analytics immutability retention policies |
| Quarantine files | Malicious payload | Spread of malware | AV scanning, isolation container, no automatic downstream processing |
| Service Bus routing topic | Unauthorized publish or subscribe | Poisoned routing events, data leakage | RBAC (Send/Listen separation), topic-level access via Managed Identity, private endpoints, namespace firewall |
| Routing messages | Sensitive data inclusion | PHI leakage via events | Strict schema (envelope only), validation rejecting disallowed fields, code review guardrails |
| Outbound staging container | Unauthorized modification | Altered acknowledgments / repudiation risk | Separate container + ACL, write restricted to orchestrator identity, checksum & hash logging |
| Control number store | Tampering / replay | Incorrect acknowledgments & audit gaps | Optimistic concurrency, restricted RW access, integrity monitoring (hash of counter state), logging of increments |

## 4. Security Principles

1. Least Privilege & Segregation of Duties
2. Defense in Depth (network + identity + data)
3. Zero Trust (explicit verification every layer)
4. Secure by Default (no public endpoints unless justified)
5. Immutable Audit Trails
6. Secrets Never in Code / Pipelines

## 5. Identity & Access Management

### 5.1 Managed Identities

| Component | Identity Type | Key Permissions |
|-----------|--------------|-----------------|
| Data Factory | System-assigned | Storage data contributor (scoped to specific containers), Key Vault get/list secrets |
| Azure Function (validation) | System-assigned | Storage blob read (landing), write (raw/quarantine), Key Vault get secret |
| Purview Scanner | Managed identity | Storage data reader |
| Azure Function (router) | System-assigned | Storage blob read (raw header peek), Service Bus send (routing topic) |
| Subsystem Processor (each) | System-assigned MI | Service Bus listen (filtered subscription), Storage read (raw) limited, optional staging write |
| Outbound Orchestrator | System-assigned | Read subsystem staging, write outbound container, Service Bus send (outbound-ready), control number store RW |

### 5.2 RBAC & ACL Strategy

- Storage Account: Limit Data Factory to container-level (landing/raw/quarantine/metadata) not full account contributor.
- Access tiers: Use Storage RBAC roles (Storage Blob Data Reader/Contributor) rather than shared keys.
- Disallow Shared Key and SAS URL generation for service identities (policy enforcement).
- ACLs: Directory-level ACLs for partner landing folders if required (though SFTP per-user root scoping preferred).
- Service Bus: Distinct roles: router identity granted `Azure Service Bus Data Sender` on topic; subsystem identities granted `Data Receiver` on respective subscriptions only; no management plane rights in production.
- Outbound staging: Only outbound orchestrator identity has write; partners have no direct access (delivery path separated).

### 5.3 Partner SFTP Accounts

- Use Storage SFTP local users with SSH public key auth (password disabled).
- Each user mapped to home directory `/inbound/<partnerCode>/`.
- Enforce IP allowlist where feasible.
- Key rotation: 90-day cadence (policy) – require partner new key submission. Automate reminder notifications.

## 6. Network Security

| Control | Implementation |
|---------|----------------|
| Private Endpoints | Storage (blob, dfs), Key Vault, optionally Function and ADF managed VNET integration |
| Firewall Rules | Deny by default; allow required Azure services + approved partner IP ranges (SFTP may need public if dynamic) |
| VNET Integration | ADF Managed VNET (or self-hosted IR if needed for isolation) |
| No Public Access | Disallow public network access on Key Vault and Storage (except SFTP TCP 22 scenario if required) |
| DDoS Protection | Standard (via Azure Front Door not required here; rely on platform) |
| Service Bus Namespace | Private endpoint + IP firewall restricting corporate ranges; disable public network access |
| Outbound Container | Separate storage path; private endpoint; no cross-origin exposure |

## 7. Data Protection

### 7.1 Encryption

- At rest: Azure Storage default encryption (AES-256); optional CMK with Key Vault-managed key `kv-edi-${env}/key-edi-atrest`.
- In transit: SFTP (SSH), HTTPS/TLS 1.2+ for control plane.

### 7.2 Immutability & Retention

| Feature | Usage |
|---------|-------|
| Immutable Blob Policies | Optional for raw zone (legal/team decision). Policy: time-based retention (e.g., 7 years) |
| Legal Hold | Apply for litigation events only |
| Lifecycle Management | Transition raw > 1 year to Cool, > 7 years Archive/delete |

### 7.3 Data Minimization

- Only store raw required EDI payload + technical metadata.
- Avoid parsing PHI fields into metadata tables (store only envelope identifiers).
- Routing messages exclude claim/member PHI; enforce via unit tests and code review checklist.
- Outbound acknowledgments contain only standard X12 required segments; any enriched PHI returned must follow downstream governance (future scope).

## 8. Secrets & Key Management

| Secret Type | Location | Rotation |
|------------|----------|----------|
| SFTP user public keys | Storage (user config) / internal secret store | Partner-driven (90 days) |
| Function config (feature flags) | Key Vault / App Config | As needed |
| CMK (if enabled) | Key Vault | Annual rotation (automatic versioning) |
| Diagnostic workspace shared keys | Not stored (MI-based) | N/A |

## 9. Logging, Monitoring & Audit

| Log Type | Source | Sink | Retention |
|---------|--------|------|-----------|
| Storage access logs | Diagnostic settings | Log Analytics | 400+ days (per policy) |
| ADF pipeline runs | ADF | Log Analytics | 120 days (extend if needed) |
| Function logs | App Service | Log Analytics | 90 days |
| Purview lineage | Purview | Purview catalog | Managed |
| Key Vault access | Key Vault | Log Analytics | 365 days |
| Security alerts | Defender for Cloud | Sentinel/SIEM | Per SOC standard |
| Routing events audit | Router Function | Log Analytics (RoutingEvent_CL) | 120 days |
| Outbound assembly audit | Orchestrator | Log Analytics (AckAssembly_CL) | 120 days |
| Service Bus operational metrics | Namespace diagnostics | Log Analytics / Metrics | 30–90 days |

Dashboards: ingestion latency, failure reasons, quarantine counts, security alerts correlated.

## 10. Alerting Matrix

| Condition | Threshold | Channel | Priority |
|-----------|----------|---------|----------|
| Pipeline failure | Any critical pipeline fails 3 times consecutively | Teams + Email + Ticket | High |
| Quarantine spike | > 5% of daily files | Teams + Ticket | Medium |
| Duplicate anomaly | Duplicate rate > 2% | Teams | Low |
| Key near expiry | 15 days before SFTP key rotation due | Email partner & Ops | Medium |
| Unauthorized access attempt | Any denied requests to Storage | SIEM alert | High |
| Routing publish failures | >5 failed publishes in 10m | Teams + Ticket | High |
| Routing DLQ growth | >0 messages over 15 min sustained | Teams | High |
| Outbound assembly failures | >2 failed assemblies in 30m | Teams + Ticket | High |
| Control number retries high | Avg retries >3 per 15m window | Teams | Medium |

## 11. Hardening & Policy

- Azure Policy assignments:
  - Disallow public network access on Key Vault
  - Enforce HTTPS on Storage
  - Enforce private endpoint usage for Storage/Key Vault
  - Audit use of shared access keys
  - Tag inheritance policy (env, dataSensitivity)
- Enforce no public network access for Service Bus namespaces
- Audit Service Bus topic authorization rule creation (should be none; MI only)
- Deny storage shared key access (already above) reinforced for outbound containers
- Defender for Storage: Enable advanced threat protection, configure alert forwarding.
- Defender for Key Vault: Enable.

## 12. Vulnerability & Patch Management

- PaaS services auto-managed; review monthly for platform advisories.
- Custom Function code: integrate dependency scanning (Dependabot or equivalent) and SAST.

## 13. Incident Response

| Phase | Action |
|-------|--------|
| Detection | Alert fired (Monitor / SIEM) |
| Triage | Confirm scope (query by ingestionId range) |
| Containment | Disable affected SFTP user, block IP, isolate container |
| Eradication | Remove malicious files (retain hash & metadata) |
| Recovery | Re-enable user with rotated key |
| Post-Incident | RCA documented, playbook update |

RPO: <= 15 minutes (raw zone resilience). RTO: <= 2 hours for ingestion path restart.

## 14. Data Residency & Sovereignty

- Deploy in region approved for PHI (e.g., East US 2). Multi-region DR optional Phase 2.

## 15. Privacy Considerations

- Limit accessible metadata dashboards to authorized roles.
- No direct PHI indexing into queryable logs beyond envelope IDs.

## 16. Testing & Validation of Controls

| Control | Test Method | Frequency |
|---------|-------------|-----------|
| RBAC least privilege | Access review (AAD) | Quarterly |
| Key rotation | Drill / automated report | Quarterly |
| Immutability policy | Attempt delete within retention | Annually |
| Alerting coverage | Synthetic pipeline failure injection | Monthly |
| Duplicate detection | Inject controlled duplicate | Quarterly |
| Routing publish auth | Attempt unauthorized send from non-router MI (should fail) | Quarterly |
| Subscription isolation | Attempt listen with unrelated MI | Quarterly |
| Outbound staging write | Attempt write from non-orchestrator identity | Quarterly |

## 17. Open Items

- Final decision on CMK vs. Microsoft-managed keys
- Confirm retention duration (regulatory vs. corporate)
- Whether to enable Microsoft Defender for Storage Malware Scanning (preview/GA status)

---
