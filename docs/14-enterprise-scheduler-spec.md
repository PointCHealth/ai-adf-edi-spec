# Enterprise Scheduler Specification for EDI Transaction Generation

**Document Version:** 0.9 Draft  
**Last Updated:** October 3, 2025  
**Status:** Draft (awaiting architecture review)  
**Related Documents:**
- [01-architecture-spec.md](./01-architecture-spec.md)
- [02-data-flow-spec.md](./02-data-flow-spec.md)
- [08-transaction-routing-outbound-spec.md](./08-transaction-routing-outbound-spec.md)
- [06-operations-spec.md](./06-operations-spec.md)
- [13-mapper-connector-spec.md](./13-mapper-connector-spec.md)

---

## 1. Purpose & Background

Event-driven ingestion covers partner-delivered files, but several enterprise workflows must **proactively generate or refresh EDI transactions on a defined cadence** (e.g., nightly enrollment deltas, weekly 277CA compliance runs, month-end financial extracts). This specification defines the **Enterprise Scheduler** capability that complements the event triggers by offering deterministic, policy-aware scheduling of EDI generation jobs across internal and partner-facing systems.

Goals:
- Provide a governed, auditable scheduling layer for outbound and internally-sourced EDI transactions.
- Ensure alignment with HIPAA, corporate change control, and operational resiliency requirements.
- Reuse existing platform primitives (Azure Data Factory, Service Bus, Key Vault, Log Analytics) while minimizing bespoke infrastructure.

## 2. Scope

### 2.1 In-Scope (Phase 1)
- Time-based triggering of EDI generation pipelines (hourly, daily, weekly, monthly) including business calendars.
- Configuration-driven schedule definitions stored alongside partner metadata (`config/schedules`).
- Dependency chaining (e.g., run 834 snapshot after data warehouse refresh completes).
- Blackout windows, maintenance overrides, and manual trigger support.
- Observability (execution history, SLA adherence, alerting on late/missed runs).
- Integration with outbound assembly and routing services via Service Bus topics/queues.

### 2.2 Out-of-Scope (Phase 1)
- Real-time API-trigger scheduling (handled by existing event triggers).
- Complex workload orchestration requiring more than 10 sequential dependencies (Phase 2: consider Azure Data Factory tumbling window or Azure Logic Apps).
- Predictive scheduling or adaptive load balancing based on historical durations.
- Partner portal self-service scheduling (manual change requests through operations in Phase 1).

## 3. Business Drivers
- **Regulatory Reporting:** CMS, state, and payer contracts require periodic outbound 271/277/835 files independent of inbound activity.
- **Operational SLAs:** Internal systems (claims adjudication, enrollment, finance) need deterministic delivery windows to align with batch jobs and staffing.
- **Data Reconciliation:** Scheduled reconciliations (daily control number audits, duplicate detection sweeps) reduce disputes.
- **Disaster Recovery Preparedness:** Ability to replay scheduled runs during DR failover scenarios.

## 4. Scheduling Scenarios

| Scenario | Description | Cadence | Success Metric |
|----------|-------------|---------|----------------|
| Nightly Enrollment Snapshot | Generate outbound 834 deltas for downstream partners based on core enrollment system updates. | Daily 01:00 UTC | File delivered before 02:00 UTC, ack posted within 30 min |
| Weekly 277CA Compliance | Aggregate claim responses and generate consolidated 277CA file. | Weekly Monday 04:00 UTC | SLA: 277CA posted before business hours |
| Monthly Financial 835 | Produce 835 remittance advice after finance close. | Monthly Last Day 06:00 UTC | Finance sign-off before 09:00 UTC |
| Control Number Sync | Publish control number inventory & detect gaps. | Hourly | Latency < 10 min for discrepancy alerts |
| Duplicate Sweep | Run dedup logic on prior 24h ingestion. | Daily 03:00 UTC | Zero unresolved duplicates >24h |

## 5. Functional Requirements

1. **Centralized Configuration**
   - JSON or YAML schedule artifacts stored in repo under `config/schedules/`.
   - Define job metadata: `jobId`, `description`, `cadence`, `timeZone`, `calendar`, `dependencies`, `maxRetries`, `slaMinutes`, `targetPipeline`, `parameters`.
2. **Calendar & Window Management**
   - Support business calendars (bank holidays) via ICS import or static JSON list.
   - Blackout windows (planned maintenance) with skip or defer options.
3. **Dependency Graph**
   - DAG-level dependencies (e.g., job B waits for completion of job A same day).
   - External dependency hooks via webhook/poll (Phase 1: simple status check API returning `READY`/`WAIT`).
4. **Execution Engine**
   - Trigger Azure Data Factory pipeline `pl_schedule_dispatch` which evaluates due jobs.
   - Individual runs dispatched to downstream orchestrators (ADF pipelines or Azure Functions) via Service Bus `scheduler-dispatch` topic.
5. **Manual Control**
   - `RunNow` capability via Azure Portal-managed Logic App HTTP endpoint requiring authenticated caller and change ticket reference.
   - Pause/resume of schedules with reason logged.
6. **Observability**
   - Log Analytics custom table `SchedulerRun_CL` capturing scheduled time, start, completion, status, duration, dependency outcomes, run identifiers.
   - Alerts when job start delay > SLA or failure count > threshold.
7. **Security & Compliance**
   - Managed Identity for scheduler pipeline with least privilege (read `config/schedules`, send to Service Bus, start dependent pipelines).
   - Changes to schedules require PR review (Code Owners: platform team + business owner).
8. **Failover & Retry**
   - Automatic retry policy (default 3 attempts with exponential backoff 5/15/30 minutes).
   - Dead-letter queue `scheduler-dlq` for manual intervention.
9. **Audit & Reporting**
   - Daily summary exported to storage `metadata/scheduler/YYYY/MM/DD/` for immutable audit.
   - Integration with Operations dashboards (existing workbook) to display on-call run status.

## 6. Non-Functional Requirements

| Attribute | Requirement |
|-----------|-------------|
| Availability | 99.5% (aligned with core platform). |
| Time Accuracy | Trigger start accuracy ±1 minute relative to scheduled time. |
| Throughput | Support 200 concurrent scheduled jobs per hour across environments. |
| Latency | Dispatch to downstream pipeline within 30 seconds of readiness. |
| Security | No shared keys; all secrets managed via Key Vault; scheduler artifacts tagged per governance spec. |
| Compliance | Maintain 7-year audit logs of job execution outcomes. |
| Observability | 100% of runs produce structured log entry and metrics. |

## 7. Architecture Overview

### 7.1 Logical Components

| Component | Description |
|-----------|-------------|
| **Schedule Registry** | Repo folder (`config/schedules/*.json`) templated per environment; validated via CI (JSON schema). |
| **Scheduler Trigger** | Azure Data Factory time-based (tumpling window) trigger per environment driving `pl_schedule_dispatch`. |
| **Dispatch Pipeline (`pl_schedule_dispatch`)** | Reads due jobs, applies calendar/dependency logic, publishes `SchedulerDispatch` messages to Service Bus topic. |
| **Scheduler Function (`fn_scheduler_router`)** | Azure Function with Service Bus trigger; resolves target pipeline/function, applies parameter templates, starts execution. |
| **Execution Targets** | ADF pipelines (e.g., `pl_generate_834_snapshot`), Durable Functions (outbound aggregator), Data Lake scripts. |
| **State Store** | Azure Table Storage / Cosmos DB container `SchedulerState` storing last run timestamp, retries, overrides. |
| **Monitoring & Alerts** | Log Analytics queries + Azure Monitor alert rules; integrates with `#edi-operations` Teams channel. |

### 7.2 Sequence Flow (Happy Path)

1. At scheduled time, ADF Trigger fires `pl_schedule_dispatch`.
2. Pipeline reads schedule registry (via `Get Metadata` + `ForEach` over JSON).
3. For each job:
   - Validate calendar (skip or defer) and dependencies (call REST API or check state store).
   - If due, emit message to Service Bus `scheduler-dispatch` with payload containing job metadata and parameters.
   - Update `SchedulerState` with `lastAttemptUtc`.
4. `fn_scheduler_router` receives message, acquires distributed lock (Azure Blob lease) per `jobId` to prevent duplicate start.
5. Function invokes target pipeline/function with parameters; records `runId` in state store.
6. Downstream process posts completion callback (ADF Web activity or Function HTTP) to `fn_scheduler_router` completion endpoint or writes success event to Service Bus `scheduler-complete` queue.
7. Completion updates `SchedulerState`, writes log entry to `SchedulerRun_CL`, and assesses SLA compliance.

### 7.3 Failure Handling

- If target execution fails, the Function re-queues message with incremented retry count until `maxRetries` reached.
- After final failure, message routed to `scheduler-dlq`; Logic App notifies on-call with run context and remediation steps.
- Manual replay uses `RunNow` endpoint referencing original `jobId` and `scheduleDate`.

## 8. Configuration Model

Sample schedule definition (`config/schedules/edi-outbound.json`):

```json
{
  "$schema": "../schemas/schedule.schema.json",
  "jobs": [
    {
      "jobId": "834-nightly",
      "description": "Generate nightly enrollment delta 834",
      "enabled": true,
      "cadence": "0 1 * * *",
      "timeZone": "UTC",
      "calendar": "standard-business",
      "dependencies": [
        { "type": "pipeline", "name": "dw_refresh", "maxDelayMinutes": 30 }
      ],
      "target": {
        "type": "adf-pipeline",
        "name": "pl_generate_834_snapshot",
        "parameters": {
          "RunDate": "${scheduledDate}",
          "PartnerList": "all"
        }
      },
      "slaMinutes": 60,
      "maxRetries": 3,
      "alerts": {
        "onFailure": ["ops-oncall"],
        "onMissedSla": ["edi-lead"]
      }
    }
  ]
}
```

Key validation rules:
- Cron syntax validated via schema + unit tests.
- `calendar` must be defined in `config/schedules/calendars/*.json`.
- Parameter templating limited to `${...}` tokens from allowed variables (scheduledDate, scheduledDateTime, environment).
- Each `jobId` unique per environment; Code Owners enforce review.

## 9. Security & Compliance

- Scheduler resources deployed via `infra/bicep` with tags defined by [09-tagging-governance-spec.md](./09-tagging-governance-spec.md).
- Managed Identity `mi-scheduler-{env}` granted:
  - Storage Blob Data Reader (for `config` container).
  - Azure Service Bus Data Sender/Receiver (scheduler topics/queues).
  - Data Factory Pipeline Contributor (specific pipelines only).
- All manual overrides require change ticket ID logged in `SchedulerRun_CL`.
- Access to `RunNow` endpoint protected by Azure AD App registration with RBAC group `EDI Scheduler Operators`.
- Scheduler logs classified as `PHI=false` but still retained with HIPAA safeguards.

## 10. Operations & Support

| Responsibility | Task | Frequency |
|----------------|------|-----------|
| Platform Team | Review upcoming calendar changes (holidays) and update `calendars` config. | Quarterly |
| Operations | Monitor `SchedulerRun_CL` workbook for failures/slips; respond to alerts. | Daily |
| Security | Review access logs to `RunNow` endpoint. | Monthly |
| Compliance | Audit schedule change history via Git commits and Log Analytics. | Semi-annual |

Playbooks (appendix to [06-operations-spec.md](./06-operations-spec.md)):
- `OP-SCH-001`: Responding to scheduler failure alerts.
- `OP-SCH-002`: Performing manual `RunNow` execution.
- `OP-SCH-003`: Applying emergency blackout window.

## 11. Testing Strategy

- **Unit Tests:** Validate schedule JSON schema using CI pipeline (`config-validation.yml`).
- **Integration Tests:** Non-prod environment runs that simulate calendars, dependency delays, and failure retries.
- **Performance Tests:** Burst test by loading 200 schedules to confirm Service Bus and Function scaling.
- **Failover Tests:** Quarterly chaos test forcing Function failure to validate DLQ handling.

## 12. Implementation Roadmap

1. **Sprint 1**
   - Define JSON schema and sample schedules.
   - Provision Service Bus topics/queues and state store resources.
   - Implement `pl_schedule_dispatch` and `fn_scheduler_router` (baseline functionality).
2. **Sprint 2**
   - Add calendar/blackout processing and dependency hooks.
   - Build Log Analytics workbook & alerts.
   - Update CI (`config-validation.yml`) for schedule validation.
3. **Sprint 3**
   - Integrate manual `RunNow` Logic App and AAD App registration.
   - Document operational playbooks.
   - Conduct performance & failover testing.
4. **Go-Live**
   - Migrate initial production schedules (nightly 834, weekly 277CA).
   - Establish monitoring and operations handoff.

## 13. Future Enhancements (Backlog)

- Partner Portal scheduling self-service with approval workflows.
- Predictive SLA risk scoring using historical durations.
- Support for cron expressions with seconds/interval granularity <1 minute (potential use of Azure Logic Apps Standard).
- Integration with enterprise change-calendar APIs for automatic blackout import.
- Unified runbook automation with ServiceNow change ticket linkage.

---

_End of Document_
