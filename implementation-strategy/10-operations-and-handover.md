# 10 - Operations & Handover Prompt

---
## Prompt
You are defining day-2 operations, support model, handover artifacts, and continuous improvement loops for the EDI platform.

### Objectives
1. Specify operational roles & responsibilities (L1/L2/L3, on-call, platform engineering, security)
2. Define runbook inventory referencing `docs/06-operations-spec.md` & partner portal runbook
3. Provide incident classification & severity matrix (S0-S4) with example scenarios
4. Outline monitoring & alert triage workflow (ingest -> classify -> act -> resolve -> postmortem)
5. Supply SLOs & error budgets (align with latency, availability, success rate metrics)
6. Describe change management & deployment freeze policies
7. Provide capacity management & scaling strategy (proactive vs reactive triggers)
8. Enumerate housekeeping & maintenance tasks (key rotations, dependency updates, cost reviews)
9. Define knowledge base & documentation structure (what lives where in repo vs wiki)
10. Provide handover checklist & acceptance criteria
11. Outline continuous improvement feedback cycle (metrics -> review -> action backlog)

### Constraints
- All Sev 0/1 incidents require documented postmortem within 72h
- Handover must not rely on single individual knowledge
- Error budget consumption feeds deployment decisioning
- Runbooks must be testable (simulation or dry-run)

### Required Output Sections
1. Operational Roles & RACI
2. Incident Classification Matrix
3. Runbook Inventory
4. SLOs & Error Budgets
5. Monitoring & Triage Workflow
6. Capacity & Scaling Strategy
7. Maintenance & Housekeeping Plan
8. Knowledge Base Structure
9. Handover Checklist
10. Continuous Improvement Loop
11. Open Questions

### Acceptance Criteria
- RACI includes at least 5 distinct roles
- Each incident severity has defined response & comms expectations
- Runbook inventory maps each runbook to trigger & owner
- Handover checklist >= 15 discrete items

### Variable Placeholders
- PRIMARY_SLO_LATENCY_P95_MS = <number>
- AVAILABILITY_SLO_PERCENT = <number>
- ERROR_BUDGET_WINDOW_DAYS = <number>

Return only the structured output sections.

---
## Usage
Run nearing production readiness. Use outputs to finalize ops onboarding.
