# Future Roadmap (Draft v0.1)

## 1. Purpose
Outline deferred features and strategic enhancements beyond MVP.

## 2. Near-Term Enhancements (Post-MVP)
- Automated SFTP credential rotation workflow integration.
- Webhook / Event Grid notifications for alerts.
- Active PGP key pre-expiration reminder emails (30, 7, 1 days).
- Metrics caching layer (Redis) to reduce SQL load.

## 3. Mid-Term
- SLA customization per partner (UI + enforcement integration).
- Multi-region deployment + traffic manager for higher availability.
- Partner-configurable webhooks for ack events.
- Self-service API key management for programmatic metrics access.

## 4. Long-Term / Strategic
- ML-driven anomaly detection for reject spikes & latency outliers.
- Partner billing / usage analytics integration.
- Custom granular roles (split admin functions: security vs observability).
- Support for additional acknowledgment types or real-time FHIR event bridging.

## 5. Technical Debt Candidates
- Introduce central domain event bus inside API service for decoupled audit publisher.
- Replace direct SQL queries with CQRS / read model projections if scale demands.
- Add integration tests harness with ephemeral SQL container in CI.

## 6. Risk Mitigations Planned
| Risk | Mitigation |
|------|-----------|
| Scaling read queries | Add caching + incremental materialized views |
| Key rotation delays | Automate workflow + alert aging requests |
| Invite token abuse | Implement short-lived tokens + captcha on acceptance |
| Dashboard latency growth | Pre-aggregate metrics in background job |

## 7. Open Questions
- OPEN: Offer GraphQL facade for flexible partner queries?
- OPEN: Integrate API Management & monetization model for premium analytics?
- OPEN: Adopt temporal tables for audit diff reconstruction?

## 8. References
- `00-overview.md`
