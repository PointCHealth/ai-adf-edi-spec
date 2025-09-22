# 09. Azure Resource & Data Tagging Governance Specification

## 1. Purpose & Scope

This document defines the mandatory and conditional tagging standards for Azure resources, data assets (Data Lake folders / file zones), integration artifacts (Service Bus, Functions, ADF pipelines), and observability enrichment for the Healthcare EDI Ingestion Platform.

Objectives:

- Enable cost allocation, ownership clarity, lifecycle management, environment isolation, compliance reporting, operational triage, and data lineage.
- Provide a deterministic taxonomy consumed by: FinOps reports, policy enforcement, IaC modules, alert routing, Kusto queries, and automation.
- Govern both control-plane (Azure resource tags) and selected data-plane metadata (folder structure conventions + ADLS directory/file system properties where applicable).

## 2. Tagging Principles

1. **Deterministic & Automatable** – All required tags are emitted from Infrastructure-as-Code (Bicep) or provisioning pipelines; no manual portal edits.
2. **Minimal but Sufficient** – Avoid uncontrolled proliferation; each tag must have a consumer (report, policy, process, query).
3. **Immutable Keys, Managed Values** – Keys never change casing or spelling. Values may be updated via controlled change management.
4. **Environment Isolation** – Environment tag plus subscription scoping ensures unequivocal boundary.
5. **Compliance & PHI Boundaries** – Tags surface data classification and PHI exposure flags for auditing and DLP scopes.
6. **Traceability** – Correlate infra, data zones, pipelines, and logs using shared identifiers (e.g., `Workload`, `System`, `DataDomain`).

## 3. Standard Tag Set

| Tag Key | Required | Allowed Values / Pattern | Purpose / Consumer | Notes |
|--------|----------|--------------------------|--------------------|-------|
| `Environment` | Yes | `dev\|test\|stage\|prod` | Segmentation, RBAC scoping, policy targeting, cost slicing | Lowercase for consistency |
| `Workload` | Yes | `edi-platform` (primary) or future logical workloads | Aggregated cost & error dashboards | Keep stable |
| `System` | Yes | `ingestion`, `routing`, `outbound`, `observability`, `shared` | Layer-level filtering in monitoring & deployments | Maps to architecture spec domains |
| `Owner` | Yes | `team-distribution-list@domain` | Escalation & approval workflow | Must be a monitored DL |
| `CostCenter` | Yes | `CC[0-9]{4}` (e.g., `CC1234`) | Finance allocation | Validated by policy regex |
| `DataClassification` | Yes (data-bearing resources) | `PHI`, `PII`, `Confidential`, `Internal` | Compliance inventory & DLP scoping | Default to `PHI` for X12 payload storage |
| `PHI` | Conditional (if DataClassification=PHI) | `true` | Simplified flag for legacy tools | Mirror of classification |
| `Lifecycle` | Yes | `persistent`, `ephemeral` | Disposal strategy & DR tiering | Functions often `persistent` (code), ephemeral test artifacts can differ |
| `Tier` | Conditional | `control-plane`, `data-plane`, `compute`, `messaging`, `monitoring` | Architecture mapping & blast radius analysis | Optional if `System` already implies |
| `Sensitivity` | Conditional | `high`, `medium`, `low` | Alerting prioritization | Derived from risk register (07 doc) |
| `ComplianceScope` | Conditional | `hipaa`, `pci-excluded` | Audit scoping | Always `hipaa` for this platform |
| `DataDomain` | Conditional | `claims837`, `acknowledgments`, `control-numbers`, `routing-metadata` | Data lineage & query filtering | Applied to storage containers / lake zones |
| `Zone` | Conditional (Data Lake) | `raw`, `validated`, `enriched`, `analytics`, `quarantine` | Lakehouse governance & retention policy | Align with Data Flow spec |
| `RetentionPolicy` | Conditional | `min-7y`, `min-90d`, `transient` | Automated lifecycle mgmt (ADLS rules) | 7-year typical for PHI claims |
| `DeploymentPipeline` | Yes | CI/CD pipeline logical name | Trace infra to pipeline | Populated by release automation |
| `SourceRepo` | Yes | Git repo slug (e.g., `vincemic/ai-adf-edi-spec`) | Provenance link | Static per environment |
| `Version` | Yes | Semantic or release tag (e.g., `v1.3.0`) | Change correlation & rollback | Updated on deployment |
| `ApprovedChangeId` | Conditional (prod) | CAB / change ticket ID format | Audit trail | Enforced only in prod deployments |
| `CostModel` | Optional | `shared`, `dedicated` | Chargeback logic | Distinguish pooled vs isolated components |
| `BackupPolicy` | Conditional (stateful) | `daily-30d`, `none`, etc. | DR compliance | Applies to storage/stateful services |
| `EncryptionScope` | Conditional | Name of customer-managed key scope | Key rotation queries | Where CMK used |

## 4. Data Lake Path & Metadata Conventions

Physical folder structure acts as additional implicit tags:

```text
/adls-<env>-edi/
  raw/claims837/{yyyymmdd}/
  raw/acks/{yyyymmdd}/
  validated/claims837/{yyyymmdd}/
  enriched/claims837/{yyyymmdd}/
  quarantine/claims837/{yyyymmdd}/
```

Rules:

- Directory depth standardized: `<zone>/<domain>/YYYYMMDD/` for partitioning.
- Control number artifacts kept under `routing-metadata/` domain.
- ADLS directory/file system properties (where automation feasible) to include: `zone`, `datadomain`, `classification`, `retention` (lowercase keys to avoid collision with ARM tags).
- No PHI stored outside `raw`, `validated`, `enriched` zones; `analytics` zone only aggregated or de-identified extracts per Data Flow spec.

## 5. Enforcement & Governance

| Mechanism | Scope | Description |
|----------|-------|-------------|
| Azure Policy (DeployIfNotExists) | Resource Groups / Subscriptions | Auto-apply default tags (Environment, Workload, System) if missing; deny on missing mandatory tags at create. |
| Azure Policy (Regex) | All | Validate `CostCenter`, restrict `Environment` values. |
| Policy Initiative | Subscription | Bundles all tag policies + Data Classification mapping. |
| Bicep Modules | IaC | All modules accept standard tag object parameter; merge module-level additions. |
| PR Checks | Repo | Lint Bicep for required `param tags` usage; unit test tag object composition. |
| Deployment Gates | Prod Release | Validate `ApprovedChangeId` present before promotion. |
| Automation Script | Data Lake | Periodic scan to detect untagged / non-conforming directories & emit Log Analytics events. |

### 5.1 Policy Example (Bicep Snippet)

```bicep
param tags object
// Module usage
resource sb 'Microsoft.ServiceBus/namespaces@2023-01-01-preview' = {
  name: name
  location: location
  tags: union(tags, {
    System: 'routing'
    Tier: 'messaging'
  })
  sku: {
    name: 'Premium'
    tier: 'Premium'
  }
}
```

### 5.2 Azure Policy Example (Deny Missing Tags)

```json
{
  "properties": {
    "displayName": "Deny creation of resources without mandatory tags",
    "policyRule": {
      "if": {
        "anyOf": [
          {"field": "tags['Environment']", "exists": "false"},
          {"field": "tags['Workload']", "exists": "false"},
          {"field": "tags['Owner']", "exists": "false"},
          {"field": "tags['CostCenter']", "exists": "false"}
        ]
      },
      "then": {"effect": "deny"}
    },
    "mode": "All"
  }
}
```

### 5.3 DeployIfNotExists Example (Default System)

```json
{
  "properties": {
    "displayName": "Add default System tag if missing",
    "policyRule": {
      "if": {
        "allOf": [
          {"field": "type", "notEquals": "Microsoft.Resources/subscriptions/resourceGroups"},
          {"field": "tags['System']", "exists": "false"}
        ]
      },
      "then": {
        "effect": "modify",
        "details": {
          "operations": [
            {
              "operation": "add",
              "field": "tags['System']",
              "value": "shared"
            }
          ]
        }
      }
    },
    "mode": "Indexed"
  }
}
```

## 6. Integration with Other Specifications

| Related Spec | Dependency | Notes |
|--------------|-----------|-------|
| `03-security-compliance-spec.md` | DataClassification / PHI / EncryptionScope | Tags feed compliance inventory & key rotation schedule. |
| `04-iac-strategy-spec.md` | Tag parameter pattern | Standard `tags` object cascades across modules. |
| `05-sdlc-devops-spec.md` | DeploymentPipeline / Version / ApprovedChangeId | Release pipelines stamp runtime values. |
| `06-operations-spec.md` | Sensitivity / System | Drives alert routing and dashboards. |
| `07-nfr-risks-spec.md` | Sensitivity derivation | Risk ratings map to tag defaults. |
| `08-transaction-routing-outbound-spec.md` | System = routing/outbound | Routing artifacts classification and ownership. |

## 7. Observability & Kusto Usage

Sample queries to validate tag coverage and drive dashboards.

### 7.1 Tag Completeness Coverage

```kusto
AzureResources
| where subscriptionId == '<sub-id>'
| summarize total=count(), missingEnv=countif(isempty(tostring(tags.Environment)))
| extend pctMissingEnv = missingEnv * 100.0 / total
```

### 7.2 Cost by Workload & System

```kusto
Usage
| where TimeGenerated > ago(30d)
| summarize cost = sum(PreTaxCost) by Workload=tostring(tags.Workload), System=tostring(tags.System)
| order by cost desc
```

### 7.3 High Sensitivity Resources Without Backup Policy

```kusto
AzureResources
| where tostring(tags.Sensitivity) == 'high'
| where isempty(tostring(tags.BackupPolicy))
```

### 7.4 Data Lake Directory Classification Drift (Custom Log)

```kusto
DataLakeDirectoryScan_CL
| where TimeGenerated > ago(1d)
| where expectedClassification != actualClassification
```

## 8. CI/CD Implementation Pattern

1. Central `tags.standard.json` template stored under `infra/` (future) providing baseline keys & default values per environment.
2. Pipeline injects dynamic values: `Version`, `DeploymentPipeline`, `ApprovedChangeId` (prod only), `SourceRepo`.
3. Bicep root module parameter: `param baseTags object` merged with module-scope tags.
4. Tag unit test (e.g., using `what-if` output + script) verifies presence before `deploy` stage.
5. Drift detection job weekly compares live resource tag sets to canonical template.

## 9. Exceptions & Waivers

- Any request to omit or alter a mandatory tag requires Architecture + Security sign-off documented in an exception register (future location: `governance/exceptions.md`).
- Temporary waivers auto-expire (default 30 days) and appear in audit report.

## 10. Roadmap Enhancements

| Item | Description | Priority |
|------|-------------|----------|
| Tag Consistency Scanner | Azure Function enumerating resources + Data Lake scanning, publishing drift log | High |
| Automated Remediation | Logic App / Function to append missing non-critical tags | Medium |
| FinOps Dashboard | Power BI pinned workbook slicing cost by `Workload`, `System`, `DataClassification` | Medium |
| Data Zone Retention Policy Automation | Lifecycle management rules shaped from `RetentionPolicy` tag | High |
| Tag Value Dictionary Service | Central API for approved enumerations | Low |

## 11. Summary

This governance standard enforces a concise yet expressive taxonomy enabling cost transparency, operational traceability, compliance reporting, and lifecycle automation. Implementation is code-first (Bicep + Policy) with continuous validation and drift detection to ensure durability and auditability.
