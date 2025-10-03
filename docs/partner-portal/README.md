# Partner Self-Service Portal Documentation Index

This index links all portal-related specifications introducing the external Trading Partner Self-Service Portal that complements the core EDI ingestion & acknowledgment platform.

## Spec Files

| File | Description |
|------|-------------|
| [00-overview.md](00-overview.md) | Purpose, scope, glossary additions, assumptions |
| [01-requirements-functional.md](01-requirements-functional.md) | User roles, feature matrix, user stories, functional acceptance criteria |
| [02-requirements-nonfunctional.md](02-requirements-nonfunctional.md) | Performance, availability, security, scalability, reliability, DR |
| [03-architecture.md](03-architecture.md) | Logical / application architecture, module decomposition, sequencing |
| [04-domain-model.md](04-domain-model.md) | Entities, relationships, invariants, ER diagram |
| [05-api-spec-draft.md](05-api-spec-draft.md) | REST endpoints (v1), models, error codes, versioning strategy |
| [06-data-schema.sql](06-data-schema.sql) | Azure SQL schema draft (DDL) & constraints |
| [07-security-authz.md](07-security-authz.md) | Authn/z model, roles, mitigations, audit logging |
| [08-observability.md](08-observability.md) | Log taxonomy, KQL queries, alert concepts, correlation strategy |
| [09-operations-runbook.md](09-operations-runbook.md) | Runbook procedures, incident handling, rotation workflows |
| [10-future-roadmap.md](10-future-roadmap.md) | Deferred features, strategic roadmap, risk mitigations |

## Diagrams

| File | Purpose |
|------|---------|
| diagrams/[architecture-overview.mmd](diagrams/architecture-overview.mmd) | High-level portal architecture (client → API → data & logs) |
| diagrams/[user-invite-sequence.mmd](diagrams/user-invite-sequence.mmd) | User invitation and acceptance flow |
| diagrams/[pgp-key-lifecycle.mmd](diagrams/pgp-key-lifecycle.mmd) | PGP key lifecycle states (active, deprecated, revoked) |

## Cross-Reference to Core Platform

- Platform invariants & glossary: `AI_PROJECT_OVERVIEW.md`
- Tagging & governance: `docs/09-tagging-governance-spec.md`
- Control numbers, acknowledgments: `docs/08-transaction-routing-outbound-spec.md` & related KQL queries.

## Key Assumptions (Highlighted)

- Identity: Azure AD B2C with `partnerId` claim.
- Hosting: Angular on Static Web Apps; API on App Service.
- Single active PGP key & SFTP credential (per type) per partner.
- No PHI stored in portal domain data.

## Open Question Consolidation (Snapshot)

(See individual files for details.)

- API Management adoption timeline.
- MFA mandatory at launch confirmation.
- Retention policy for audit & usage events.
- Materialization strategy for file status vs query-on-demand.

## Next Potential Actions

- Lint/correct Markdown spacing (MD022/MD032/MD058) in all portal docs.
- Add CI pipeline step to validate SQL & run markdownlint.
- Generate OpenAPI YAML from `05-api-spec-draft.md` as canonical contract.
- Scaffold Angular & .NET solution per architecture spec.

---
End of Partner Portal Documentation Index.
