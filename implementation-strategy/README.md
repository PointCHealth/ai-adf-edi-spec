# Implementation Strategy Prompts

This directory contains an ordered sequence of prompt playbooks to guide an AI-assisted implementation of the EDI Routing & Outbound Processing platform described in this specification repository.

Each numbered file can be used as a system / architect prompt to drive focused generation, review, and execution. Prompts are progressive: later prompts assume completion of earlier ones.

## Document Sequence

1. 01-tooling-and-credential-acquisition.md
2. 02-environment-naming-and-config-foundation.md
3. 03-security-and-secrets-bootstrap.md
4. 04-infrastructure-bicep-plan.md
5. 05-infrastructure-deployment-execution.md
6. 06-application-service-implementation.md
7. 07-testing-strategy-and-prompts.md
8. 08-observability-and-telemetry-setup.md
9. 09-ci-cd-pipeline-automation.md
10. 10-operations-and-handover.md

## How To Use

For each phase:
- Copy the prompt body into your AI assistant (or chain it with previous context)
- Provide any variable values requested in the PLACEHOLDER sections
- Iterate until the acceptance criteria in the prompt are satisfied

## Conventions
- Prompts use MUST / SHOULD language to clarify required vs recommended outputs
- All infrastructure artifacts should align with existing `infra/bicep/modules` where possible
- Security controls map to the security & compliance spec in `docs/03-security-compliance-spec.md`
- Observability queries must reference KQL samples under `queries/kusto`

## Extension
Feel free to add additional numbered prompts (e.g. `11-advanced-partner-onboarding.md`) as scope evolves.
