# Azure Resource Inventory

## Azure Subscription & Tenant Information

| Environment | Subscription Name | Subscription ID | Tenant ID |
|-------------|-------------------|-----------------|------------|
| Development | EDI-DEV | `0f02cf19-be55-4aab-983b-951e84910121` | `76888a14-162d-4764-8e6f-c5a34addbd87` |
| Production | EDI-PROD | `85aa9a59-7b1c-49d2-84ba-0640040bc097` | `76888a14-162d-4764-8e6f-c5a34addbd87` |

## Resource Naming Convention

All resource names use the `{component}-edi-{env}` convention unless noted. Replace `{env}` with `dev`, `test`, `prod`, etc. SKU values reflect recommended starting tiers for the initial rollout; adjust per capacity planning.

## Storage & Data Platforms

| Resource Type | Instance Name Pattern | SKU / Tier | Notes |
|---------------|-----------------------|------------|-------|
| Microsoft.Storage/storageAccounts (Data Lake + SFTP landing) | `stedi{env}001` | Standard_GZRS (hierarchical namespace + SFTP enabled) | Hosts SFTP landing paths, raw, quarantine, metadata, and lifecycle policies. |
| Microsoft.Storage/storageAccounts (Outbound delivery, optional separation) | `stoutbound{env}001` | Standard_LRS (hierarchical namespace) | Use if outbound staging/delivery requires isolation from inbound account. |
| Microsoft.Sql/servers | `sql-edi-{env}` | n/a (control plane) | Server for control number database (private endpoint enabled). |
| Microsoft.Sql/servers/databases | `sqldb-edi-control-{env}` | GeneralPurpose Gen5 (2 vCores, serverless, 32 GB max) | Stores control number counters and audit history. |
| Microsoft.Purview/accounts | `pvw-edi-{env}` | Standard | Catalogs data assets, lineage, and governance metadata. |
| Microsoft.AppConfiguration/configurationStores | `appcfg-edi-{env}` | Standard | Centralized feature flags (e.g., AV scan toggle) and dynamic config. |

## Orchestration & Compute

| Resource Type | Instance Name Pattern | SKU / Tier | Notes |
|---------------|-----------------------|------------|-------|
| Microsoft.DataFactory/factories | `adf-edi-{env}` | Data Factory V2 (consumption) | Primary orchestration for ingestion, validation, outbound batching. |
| Microsoft.Web/serverfarms | `plan-edi-functions-{env}` | ElasticPremium EP1 | Premium Functions plan for warm instances, VNET integration, and scaling. |
| Microsoft.Web/sites (validation Function App) | `func-edi-validate-{env}` | Functions on ElasticPremium EP1 | Hosts custom validators (checksum, AV hook, structural peek). |
| Microsoft.Web/sites (routing Function App) | `func-edi-router-{env}` | Functions on ElasticPremium EP1 | Publishes routing messages to Service Bus after header peek. |
| Microsoft.Web/sites (outbound orchestrator) | `func-edi-outbound-{env}` | Functions on ElasticPremium EP1 | Assembles acknowledgments/responses and manages control numbers. |

## Messaging & Integration

| Resource Type | Instance Name Pattern | SKU / Tier | Notes |
|---------------|-----------------------|------------|-------|
| Microsoft.EventGrid/systemTopics | `evgt-edi-storage-{env}` | Basic | Captures blob created events from the landing account. |
| Microsoft.EventGrid/eventSubscriptions | `es-edi-adf-{env}` | Basic | Subscription forwarding storage events to Data Factory trigger. |
| Microsoft.ServiceBus/namespaces | `sbn-edi-{env}` | Premium P1 | Routing topic (`edi-routing`), DLQ rules, outbound-ready signaling with zone redundancy. |
| Microsoft.ServiceBus/namespaces/topics | `edi-routing` / `edi-outbound-ready` | Premium (inherits namespace tier) | Logical messaging entities for transaction fan-out and outbound notifications. |
| Microsoft.ServiceBus/namespaces/queues (optional DLQ monitor) | `edi-deadletter` | Premium | Central DLQ for poisoned routing messages if auto-forward used. |

## Security & Secrets

| Resource Type | Instance Name Pattern | SKU / Tier | Notes |
|---------------|-----------------------|------------|-------|
| Microsoft.KeyVault/vaults | `kv-edi-{env}` | Standard | Stores secrets, SFTP SSH keys, optional customer-managed storage keys. |
| System-assigned managed identities (per resource) | n/a | n/a | Enable on each Function App, Data Factory, and downstream processor to grant scoped access; no standalone identity resources required. |
| Microsoft.Security/defenderForStorageSettings | `stedi{env}001/default` | Plan: DefenderForStorage | Enables threat protection on landing/raw containers. |

## Monitoring & Operations

| Resource Type | Instance Name Pattern | SKU / Tier | Notes |
|---------------|-----------------------|------------|-------|
| Microsoft.OperationalInsights/workspaces | `log-edi-{env}` | PerGB2018 | Central Log Analytics workspace for ingestion, routing, and security logs. |
| Microsoft.Insights/components | `appi-edi-{env}` | Basic (Workspace-based) | Application Insights instance linked to Log Analytics for Functions telemetry. |
| Microsoft.Insights/actionGroups | `ag-edi-ops-{env}` | n/a | Notification targets for ingestion failures, DLQ spikes, control number alerts. |
| Microsoft.Dashboard/containers (optional) | `dash-edi-operations-{env}` | n/a | Azure Monitor workbook container for SLA dashboards. |

## Networking & Access Control

| Resource Type | Instance Name Pattern | SKU / Tier | Notes |
|---------------|-----------------------|------------|-------|
| Microsoft.Network/virtualNetworks | `vnet-edi-{env}` | n/a | Provides subnets for integration runtime, private endpoints, and secure egress. |
| Microsoft.Network/virtualNetworks/subnets | `snet-ir-{env}`, `snet-pep-{env}` | n/a | Dedicated subnets for self-hosted IR (if required) and private endpoints. |
| Microsoft.Network/privateEndpoints (Storage) | `pep-edi-storage-{env}` | n/a | Private endpoint to landing/raw storage account. |
| Microsoft.Network/privateEndpoints (Service Bus) | `pep-edi-sbus-{env}` | n/a | Private endpoint for Service Bus namespace. |
| Microsoft.Network/privateEndpoints (Key Vault) | `pep-edi-kv-{env}` | n/a | Private endpoint for Key Vault. |
| Microsoft.Network/privateEndpoints (SQL) | `pep-edi-sql-{env}` | n/a | Private endpoint for control number database access. |
| Microsoft.Network/privateDnsZones | `privatelink.blob.core.windows.net`, `privatelink.servicebus.windows.net`, `privatelink.vaultcore.azure.net`, `privatelink.database.windows.net` | n/a | DNS zones resolving private endpoints inside the VNET. |
| Microsoft.Network/privateDnsZones/virtualNetworkLinks | `pdzlink-edi-{zone}-{env}` | n/a | VNET links for each private DNS zone. |

## Optional / Environment-Specific

| Resource Type | Instance Name Pattern | SKU / Tier | Notes |
|---------------|-----------------------|------------|-------|
| Microsoft.Storage/storageAccounts (Analytics/Sandbox) | `stedi-analytics-{env}` | Standard_LRS | Separate account for downstream analytics or data science sandboxes. |
| Microsoft.Synapse/workspaces (Phase 2 analytics) | `syn-edi-{env}` | Data Warehouse Unit: DW300c | Enable when curated zone transformations begin. |
| Microsoft.Kusto/clusters (Observability) | `adx-edi-{env}` | Standard_D11_v2 (2 instances) | Optional Kusto cluster for advanced observability dashboards beyond Log Analytics. |
| Microsoft.Automation/automationAccounts | `aa-edi-{env}` | Basic | Used for key rotation runbooks or partner onboarding scripts if not handled via GitHub Actions. |

Ensure diagnostic settings route all resource logs to `log-edi-{env}`, enforce Azure Policy for private endpoints, and tag every resource with `env`, `application=edi-platform`, `dataSensitivity=PHI`, and `costCenter` metadata.
