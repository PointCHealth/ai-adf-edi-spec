# Anthem Integration Use Case

## Purpose

Point C Health is onboarding Anthem as a trading partner for X12-based data exchanges. This document captures the end-to-end integration scope, stakeholders, system touchpoints, and next steps needed to enable production-grade connectivity between Anthem and Point C Health.

## Objectives

- Establish secure, reliable interchange of required X12 transaction sets with Anthem.
- Align Anthem onboarding activities with Point C Health EDI governance, routing, and exception handling standards.
- Coordinate internal claim system integrations so Anthem-related transactions flow through the appropriate downstream processes.

## Transaction Sets

| Transaction | Description | Direction |
|-------------|-------------|-----------|
| 837 | Healthcare Claim | Anthem → Point C Health |
| 835 (remittance) | Healthcare Claim Payment/Advice | Anthem → Point C Health |
| 835 (internal redistribution) | Payment/Advice handoff to internal claim systems | Point C Health → Internal systems |
| 834 | Benefit Enrollment and Maintenance | Point C Health → Anthem |
| 999 | Implementation Acknowledgment | Bidirectional |

## Internal Claim Systems Impacted

- QicLink (core commercial claims)
- VBA (value-based administration)

> Note: Confirm the current system inventory and add/remove systems as discovery progresses.

## Integration Scope Outline

1. **Connectivity & Certificates**: Route all inbound/outbound files through the Titan MFT (Point C Health's centralized SFTP), complete certificate exchange, and confirm network allowlists for Anthem endpoints.
2. **Routing & Translation**: Map Anthem sender/receiver IDs to routing rules; configure translator mappings for each transaction set.
3. **Acknowledgments**: Determine 999 generation rules, timing SLAs, and error-handling procedures.
4. **Internal Distribution**: Design message splitting/duplication to route Anthem transactions to the correct internal claim systems. For outbound 834 enrollment files, Point C Health must split consolidated membership feeds into the following regional files prior to transmission:

    | Region | States |
    |--------|--------|
    | Northeast | Connecticut, Maine, New Hampshire |
    | Central | Ohio, Indiana, Kentucky, Missouri, Wisconsin |
    | West | California |
    | Colorado/Nevada | Colorado, Nevada |
    | Georgia/Virginia | Georgia, Virginia |
    | New York | New York |

5. **Testing Strategy**: Plan unit, integration, and end-to-end testing cycles with Anthem, including parallel runs and rollback criteria.

## Confirmed Decisions

- Anthem requires SFTP with PGP encryption managed via the Titan (Ittan) MFT platform for all inbound/outbound file exchanges.

## Outstanding Questions

- Are there unique Anthem segment/element variations that must be incorporated into mapping specifications?
- Which internal claim systems will act as systems of record for Anthem-sourced data?
- What SLAs apply to acknowledgments and remittance delivery?

## Next Steps

1. Gather Anthem technical onboarding guides and certification requirements.
2. Validate Point C Health internal claim system capabilities for the listed transaction sets.
3. Draft detailed mapping specifications per transaction (reference existing assets in `docs/` as needed).
4. Define monitoring, alerting, and reconciliation requirements for Anthem transactions.
5. Schedule joint working sessions with Anthem onboarding team and internal stakeholders.
