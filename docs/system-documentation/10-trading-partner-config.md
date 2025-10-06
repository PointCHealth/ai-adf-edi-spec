# Trading Partner Configuration & Onboarding

## Overview

The Healthcare EDI Platform uses a **unified trading partner model** that treats all data sources and destinations—whether external payers/clearinghouses or internal systems—as trading partners with standardized configuration,

 routing, and monitoring. Partner configurations are managed as versioned JSON files stored in the `config/partners/` directory, validated by JSON Schema, and deployed through CI/CD pipelines to ensure governance and auditability.

### Purpose

- Standardize partner onboarding with consistent configuration schema
- Enable self-service partner configuration through Git-based workflow
- Support both external partners (SFTP, AS2, API) and internal partners (Service Bus, database, REST API)
- Provide dynamic routing, acknowledgment, and SLA management per partner
- Maintain configuration as code with version control and change history

### Key Capabilities

| Capability | Description |
|------------|-------------|
| **Unified Partner Model** | Treat external and internal systems identically for routing and processing |
| **Schema Validation** | JSON Schema-validated configurations prevent misconfigurations |
| **Multi-Protocol Support** | SFTP, Service Bus, REST API, Database endpoints |
| **Granular SLA Tracking** | Per-partner ingestion, acknowledgment, and response latency targets |
| **Priority Overrides** | Transaction-specific routing priority (standard, high) |
| **Integration Patterns** | Event sourcing, CRUD, custom adapters for internal partners |
| **CI/CD Deployment** | GitHub Actions validate and deploy configuration changes |
| **Configuration as Code** | Git-based change tracking, PR reviews, rollback capability |

---

## Trading Partner Abstraction

### Partner Types

#### EXTERNAL Partners

Traditional healthcare trading partners outside the organization:
- **Payers**: Insurance companies, health plans sending eligibility/remittance
- **Providers**: Hospitals, physician groups submitting claims
- **Clearinghouses**: Third-party intermediaries for transaction routing
- **Brokers**: Enrollment brokers sending 834 files

**Characteristics**:
- Connect via SFTP, AS2, or REST API (external-facing endpoints)
- Require secure credential management (SSH keys, OAuth2)
- Subject to trading partner agreements (TPAs) with SLA commitments
- May require PGP encryption or digital signatures
- Receive acknowledgments (TA1, 999, 271, 277CA, 835) via outbound delivery

#### INTERNAL Partners

Internal systems configured as partners within the platform ecosystem:
- **Eligibility Service**: Processes 270 inquiries, generates 271 responses
- **Claims Processing**: Receives 837 claims, sends 277/277CA/835 outcomes
- **Enrollment Management**: Consumes 834 transactions with event sourcing
- **Remittance Processing**: Processes 835/820 remittance advice

**Characteristics**:
- Connect via Azure Service Bus topics/subscriptions (internal messaging)
- Use managed identities for authentication (no credentials)
- May implement domain-specific patterns (event sourcing, CRUD, custom)
- Faster SLA targets (seconds vs. minutes)
- Send outcome signals back to platform for acknowledgment generation

### Why Unified Model?

1. **Loose Coupling**: Internal systems decouple from ingestion throughput via asynchronous messaging
2. **Consistent Routing**: Same routing metadata contract (no PHI in messages)
3. **Independent Scaling**: Each partner scales independently via Service Bus DLQs and retry policies
4. **Simplified Configuration**: Single schema for all partners reduces operational complexity
5. **Flexible Architecture**: Partners implement their own patterns (event sourcing, CRUD) without impacting platform

---

## Configuration Schema

### Schema Location

**File**: `config/partners/partners.schema.json`  
**Validation**: Enforced by CI/CD pipeline on every PR

### Schema Definition

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Trading Partner Configuration",
  "description": "Unified configuration schema for all trading partners (external and internal)",
  "type": "array",
  "items": {
    "type": "object",
    "required": [
      "partnerCode",
      "name",
      "partnerType",
      "status",
      "expectedTransactions",
      "dataFlow",
      "acknowledgments",
      "sla"
    ],
    "properties": {
      "partnerCode": {
        "type": "string",
        "pattern": "^[A-Z0-9\\-]{2,20}$",
        "description": "Unique partner identifier (e.g., PARTNERA, INTERNAL-CLAIMS)"
      },
      "name": {
        "type": "string",
        "description": "Human-readable partner name"
      },
      "partnerType": {
        "type": "string",
        "enum": ["EXTERNAL", "INTERNAL"],
        "description": "Partner classification"
      },
      "status": {
        "type": "string",
        "enum": ["draft", "active", "inactive"],
        "description": "Partner lifecycle status"
      },
      "expectedTransactions": {
        "type": "array",
        "items": {"type": "string", "pattern": "^\\d{3}[A-Za-z]?$"},
        "minItems": 1,
        "description": "Transaction set codes (e.g., 270, 271, 834, 837P)"
      },
      "dataFlow": {
        "type": "object",
        "required": ["direction"],
        "properties": {
          "direction": {
            "type": "string",
            "enum": ["INBOUND", "OUTBOUND", "BIDIRECTIONAL"]
          }
        }
      },
      "routingPriorityOverrides": {
        "type": "object",
        "additionalProperties": {"type": "string", "enum": ["standard", "high"]},
        "description": "Transaction-specific routing priority overrides"
      },
      "endpoint": {
        "type": "object",
        "description": "Partner endpoint configuration (protocol-specific)",
        "oneOf": [
          {
            "required": ["type", "sftp"],
            "properties": {
              "type": {"const": "SFTP"},
              "sftp": {
                "type": "object",
                "required": ["homePath", "pgpRequired"],
                "properties": {
                  "homePath": {"type": "string"},
                  "pgpRequired": {"type": "boolean"}
                }
              }
            }
          },
          {
            "required": ["type", "serviceBus"],
            "properties": {
              "type": {"const": "SERVICE_BUS"},
              "serviceBus": {
                "type": "object",
                "required": ["subscriptionName"],
                "properties": {
                  "subscriptionName": {"type": "string"},
                  "topicName": {"type": "string", "default": "edi-routing"}
                }
              }
            }
          },
          {
            "required": ["type", "api"],
            "properties": {
              "type": {"const": "REST_API"},
              "api": {
                "type": "object",
                "required": ["baseUrl"],
                "properties": {
                  "baseUrl": {"type": "string", "format": "uri"},
                  "authType": {"type": "string", "enum": ["OAUTH2", "API_KEY", "BASIC"]},
                  "healthCheckPath": {"type": "string"}
                }
              }
            }
          },
          {
            "required": ["type", "database"],
            "properties": {
              "type": {"const": "DATABASE"},
              "database": {
                "type": "object",
                "required": ["connectionStringSecretName"],
                "properties": {
                  "connectionStringSecretName": {"type": "string"},
                  "stagingTable": {"type": "string"}
                }
              }
            }
          }
        ]
      },
      "acknowledgments": {
        "type": "object",
        "required": ["expectsTA1", "expects999"],
        "properties": {
          "expectsTA1": {"type": "boolean"},
          "expects999": {"type": "boolean"}
        }
      },
      "sla": {
        "type": "object",
        "required": ["ingestionLatencySecondsP95", "ack999Minutes"],
        "properties": {
          "ingestionLatencySecondsP95": {"type": "integer", "minimum": 1},
          "ack999Minutes": {"type": "integer", "minimum": 1},
          "responseLatencyMinutes": {
            "type": "integer",
            "minimum": 1,
            "description": "Expected business response latency (e.g., 271 for 270)"
          }
        }
      },
      "integration": {
        "type": "object",
        "description": "Integration adapter configuration (for internal partners)",
        "properties": {
          "adapterType": {
            "type": "string",
            "enum": ["EVENT_SOURCING", "CRUD", "CUSTOM"]
          },
          "customAdapterConfig": {
            "type": "object",
            "description": "Adapter-specific configuration"
          }
        }
      }
    },
    "additionalProperties": false
  }
}
```

### Property Descriptions

#### Core Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `partnerCode` | string | ✅ | Unique identifier (2-20 chars, uppercase alphanumeric + hyphens) |
| `name` | string | ✅ | Human-readable name (displayed in monitoring dashboards) |
| `partnerType` | enum | ✅ | `EXTERNAL` or `INTERNAL` |
| `status` | enum | ✅ | `draft`, `active`, or `inactive` (only `active` partners route messages) |
| `expectedTransactions` | array | ✅ | Transaction codes (e.g., `["270", "271", "834"]`) |
| `dataFlow.direction` | enum | ✅ | `INBOUND`, `OUTBOUND`, or `BIDIRECTIONAL` |

#### Routing & Priority

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `routingPriorityOverrides` | object | ❌ | Transaction-specific priorities (`{"270": "high", "834": "standard"}`) |

**Priority Levels**:
- `standard`: Default priority, 30-second message TTL
- `high`: Elevated priority, 10-second message TTL, monitored for latency

#### Endpoint Configuration

One of the following endpoint types must be configured:

##### SFTP Endpoint

```json
{
  "endpoint": {
    "type": "SFTP",
    "sftp": {
      "homePath": "/inbound/PARTNERA/",
      "pgpRequired": true
    }
  }
}
```

| Property | Description |
|----------|-------------|
| `homePath` | Partner's home directory in SFTP container (landing zone) |
| `pgpRequired` | Whether partner encrypts files with PGP (platform must decrypt) |

##### Service Bus Endpoint

```json
{
  "endpoint": {
    "type": "SERVICE_BUS",
    "serviceBus": {
      "subscriptionName": "sub-eligibility-partner",
      "topicName": "edi-routing"
    }
  }
}
```

| Property | Description |
|----------|-------------|
| `subscriptionName` | Service Bus subscription name (must match Bicep deployment) |
| `topicName` | Service Bus topic (default: `edi-routing`) |

##### REST API Endpoint

```json
{
  "endpoint": {
    "type": "REST_API",
    "api": {
      "baseUrl": "https://partner-api.example.com/edi",
      "authType": "OAUTH2",
      "healthCheckPath": "/health"
    }
  }
}
```

| Property | Description |
|----------|-------------|
| `baseUrl` | Partner API base URL |
| `authType` | Authentication method (`OAUTH2`, `API_KEY`, `BASIC`) |
| `healthCheckPath` | Health check endpoint (relative to baseUrl) |

##### Database Endpoint

```json
{
  "endpoint": {
    "type": "DATABASE",
    "database": {
      "connectionStringSecretName": "partner-db-connection",
      "stagingTable": "dbo.EDI_Staging"
    }
  }
}
```

| Property | Description |
|----------|-------------|
| `connectionStringSecretName` | Key Vault secret name for connection string |
| `stagingTable` | Database table for staging partner data |

#### Acknowledgments

```json
{
  "acknowledgments": {
    "expectsTA1": true,
    "expects999": true
  }
}
```

| Property | Description |
|----------|-------------|
| `expectsTA1` | Partner expects TA1 interchange acknowledgment |
| `expects999` | Partner expects 999 functional acknowledgment |

#### SLA Configuration

```json
{
  "sla": {
    "ingestionLatencySecondsP95": 300,
    "ack999Minutes": 15,
    "responseLatencyMinutes": 5
  }
}
```

| Property | Description |
|----------|-------------|
| `ingestionLatencySecondsP95` | Target p95 ingestion latency (file arrival → raw storage) |
| `ack999Minutes` | Target 999 acknowledgment generation time |
| `responseLatencyMinutes` | Target business response latency (e.g., 271 for 270 inquiry) |

#### Integration Adapter (Internal Partners Only)

```json
{
  "integration": {
    "adapterType": "EVENT_SOURCING",
    "customAdapterConfig": {
      "eventStoreConnectionSecretName": "enrollment-db-connection",
      "snapshotIntervalEvents": 100
    }
  }
}
```

| Property | Description |
|----------|-------------|
| `adapterType` | Integration pattern: `EVENT_SOURCING`, `CRUD`, `CUSTOM` |
| `customAdapterConfig` | Adapter-specific configuration (free-form object) |

**Adapter Types**:
- **EVENT_SOURCING**: Partner implements event sourcing (e.g., Enrollment Management with 834)
- **CRUD**: Partner uses traditional CRUD operations (e.g., Claims Processing)
- **CUSTOM**: Partner has custom integration logic

---

## Configuration Examples

### Example 1: External Payer (SFTP, Bidirectional)

```json
{
  "partnerCode": "PARTNERA",
  "name": "Partner A Health (External Payer)",
  "partnerType": "EXTERNAL",
  "status": "active",
  "expectedTransactions": ["270", "271", "999"],
  "dataFlow": {
    "direction": "BIDIRECTIONAL"
  },
  "routingPriorityOverrides": {
    "270": "standard"
  },
  "endpoint": {
    "type": "SFTP",
    "sftp": {
      "homePath": "/inbound/PARTNERA/",
      "pgpRequired": false
    }
  },
  "acknowledgments": {
    "expectsTA1": true,
    "expects999": true
  },
  "sla": {
    "ingestionLatencySecondsP95": 300,
    "ack999Minutes": 15,
    "responseLatencyMinutes": 5
  }
}
```

**Use Case**: External payer sends 270 eligibility inquiries via SFTP, receives 271 responses + 999 acknowledgments.

### Example 2: External Clearinghouse (SFTP, PGP Required)

```json
{
  "partnerCode": "PARTNERB",
  "name": "Partner B Claims (External Clearinghouse)",
  "partnerType": "EXTERNAL",
  "status": "draft",
  "expectedTransactions": ["276", "277", "835"],
  "dataFlow": {
    "direction": "BIDIRECTIONAL"
  },
  "routingPriorityOverrides": {
    "276": "high"
  },
  "endpoint": {
    "type": "SFTP",
    "sftp": {
      "homePath": "/inbound/PARTNERB/",
      "pgpRequired": true
    }
  },
  "acknowledgments": {
    "expectsTA1": true,
    "expects999": false
  },
  "sla": {
    "ingestionLatencySecondsP95": 300,
    "ack999Minutes": 30,
    "responseLatencyMinutes": 120
  }
}
```

**Use Case**: Clearinghouse requires PGP encryption, sends 276 claim status inquiries (high priority), receives 277/835 responses.

### Example 3: Internal Eligibility Service (Service Bus)

```json
{
  "partnerCode": "INTERNAL-ELIGIBILITY",
  "name": "Eligibility Service (Internal Partner)",
  "partnerType": "INTERNAL",
  "status": "active",
  "expectedTransactions": ["270", "271"],
  "dataFlow": {
    "direction": "BIDIRECTIONAL"
  },
  "routingPriorityOverrides": {
    "270": "high"
  },
  "endpoint": {
    "type": "SERVICE_BUS",
    "serviceBus": {
      "subscriptionName": "sub-eligibility-partner",
      "topicName": "edi-routing"
    }
  },
  "acknowledgments": {
    "expectsTA1": false,
    "expects999": true
  },
  "sla": {
    "ingestionLatencySecondsP95": 120,
    "ack999Minutes": 10,
    "responseLatencyMinutes": 2
  },
  "integration": {
    "adapterType": "CRUD",
    "customAdapterConfig": {
      "databaseConnectionSecretName": "eligibility-db-connection"
    }
  }
}
```

**Use Case**: Internal eligibility service subscribes to 270 inquiries, generates 271 responses via CRUD pattern.

### Example 4: Internal Enrollment Management (Event Sourcing)

```json
{
  "partnerCode": "INTERNAL-ENROLLMENT",
  "name": "Enrollment Management (Internal Partner)",
  "partnerType": "INTERNAL",
  "status": "active",
  "expectedTransactions": ["834"],
  "dataFlow": {
    "direction": "INBOUND"
  },
  "routingPriorityOverrides": {
    "834": "standard"
  },
  "endpoint": {
    "type": "SERVICE_BUS",
    "serviceBus": {
      "subscriptionName": "sub-enrollment-partner",
      "topicName": "edi-routing"
    }
  },
  "acknowledgments": {
    "expectsTA1": false,
    "expects999": true
  },
  "sla": {
    "ingestionLatencySecondsP95": 300,
    "ack999Minutes": 15
  },
  "integration": {
    "adapterType": "EVENT_SOURCING",
    "customAdapterConfig": {
      "eventStoreConnectionSecretName": "enrollment-db-connection",
      "snapshotIntervalEvents": 100
    }
  }
}
```

**Use Case**: Enrollment management system uses event sourcing to process 834 transactions with full audit trail.

### Example 5: Internal Claims Processing (REST API)

```json
{
  "partnerCode": "INTERNAL-CLAIMS",
  "name": "Claims Processing (Internal Partner)",
  "partnerType": "INTERNAL",
  "status": "active",
  "expectedTransactions": ["837P", "837I", "837D", "276", "277", "277CA"],
  "dataFlow": {
    "direction": "BIDIRECTIONAL"
  },
  "routingPriorityOverrides": {
    "837P": "high",
    "837I": "high",
    "837D": "high"
  },
  "endpoint": {
    "type": "SERVICE_BUS",
    "serviceBus": {
      "subscriptionName": "sub-claims-partner",
      "topicName": "edi-routing"
    }
  },
  "acknowledgments": {
    "expectsTA1": false,
    "expects999": true
  },
  "sla": {
    "ingestionLatencySecondsP95": 180,
    "ack999Minutes": 15,
    "responseLatencyMinutes": 240
  },
  "integration": {
    "adapterType": "CRUD",
    "customAdapterConfig": {
      "apiBaseUrl": "https://claims-api-internal.example.com/v1"
    }
  }
}
```

**Use Case**: Claims processing system receives 837 claims via Service Bus, generates 277/835 responses via REST API.

---

## Partner Onboarding Workflow

### Phase 1: Partner Registration

```text
┌──────────────────────────────────────────────────────────────────────┐
│                    PARTNER ONBOARDING WORKFLOW                        │
└──────────────────────────────────────────────────────────────────────┘

Step 1: Initial Contact & Requirements Gathering
├── Business justification (trading partner agreement, internal system integration)
├── Expected transaction types (270, 271, 834, 837, etc.)
├── Data flow direction (inbound, outbound, bidirectional)
├── Volume estimates (files/day, avg file size, peak times)
├── SLA requirements (ingestion latency, acknowledgment timing)
├── Protocol preference (SFTP, Service Bus, REST API, database)
├── Security requirements (PGP encryption, OAuth2, managed identity)
└── Compliance obligations (HIPAA BAA, audit logging)

Step 2: Technical Design Session
├── Endpoint configuration (SFTP home path, Service Bus subscription, API base URL)
├── Authentication method (SSH keys, OAuth2 client credentials, managed identity)
├── Acknowledgment preferences (TA1, 999, business responses)
├── Priority overrides (high priority for real-time transactions)
├── Integration adapter selection (event sourcing, CRUD, custom)
├── Monitoring & alerting thresholds (latency, error rates)
└── Testing strategy (UAT environment, test files, success criteria)

Step 3: Configuration File Creation
├── Create partner JSON in config/partners/partner-{code}.json
├── Validate against partners.schema.json
├── Generate unique partnerCode (EXTERNAL: PARTNERA, INTERNAL: INTERNAL-ELIGIBILITY)
├── Configure endpoint (protocol-specific settings)
├── Set SLA targets (ingestionLatencySecondsP95, ack999Minutes, responseLatencyMinutes)
└── Document integration adapter config (for internal partners)
```

### Phase 2: Infrastructure Provisioning

```text
Step 4: Infrastructure Deployment (Bicep)

For EXTERNAL Partners (SFTP):
├── Create SFTP local user account (Azure Storage SFTP)
├── Generate SSH key pair (store public key in config, private key with partner)
├── Create partner home directory in landing container (/inbound/PARTNERA/)
├── Configure firewall rules (if IP allowlist required)
└── Enable PGP decryption (if pgpRequired: true)

For INTERNAL Partners (Service Bus):
├── Create Service Bus subscription (sub-eligibility-partner)
├── Configure SQL filter rules (transactionSet = '270' AND partnerCode = 'INTERNAL-ELIGIBILITY')
├── Set subscription properties (MaxDeliveryCount: 10, TTL: 30 seconds or 10 seconds for high priority)
├── Grant managed identity permissions (Service Bus Data Receiver role)
└── Deploy integration adapter (Azure Function, containerized app)

For INTERNAL Partners (REST API):
├── Provision API gateway or managed endpoint
├── Configure OAuth2 client credentials (Azure AD app registration)
├── Store client secret in Key Vault
├── Grant API permissions (custom RBAC roles)
└── Enable health check monitoring

For INTERNAL Partners (Database):
├── Provision staging table in target database (dbo.EDI_Staging)
├── Create connection string and store in Key Vault
├── Grant database permissions (INSERT, SELECT on staging table)
└── Configure change data capture (if needed)
```

### Phase 3: Configuration Deployment

```text
Step 5: Configuration Deployment via CI/CD

Local Development:
├── Create feature branch: git checkout -b feature/add-partner-{code}
├── Add partner JSON: config/partners/partner-{code}.json
├── Validate locally: scripts/validate_partner_config.py
└── Commit and push: git commit -am "Add Partner {Name} configuration"

Pull Request Review:
├── GitHub Actions: Validate JSON schema compliance
├── GitHub Actions: Check for duplicate partnerCodes
├── GitHub Actions: Verify endpoint configuration (no hardcoded secrets)
├── Peer review: Verify SLA targets, transaction mappings, acknowledgment settings
├── Approval: EDI Platform Lead or Partner Manager
└── Merge to main branch

Deployment (Automated via GitHub Actions):
├── Trigger: Merge to main or tag release
├── Deploy to dev environment: Upload to config/partners/ blob container
├── Run integration tests: Test file upload, routing, acknowledgment generation
├── Deploy to test environment: Promote after dev validation
├── Manual approval gate: Operations Lead
└── Deploy to prod environment: Final promotion with rollback plan
```

### Phase 4: Testing & Validation

```text
Step 6: User Acceptance Testing (UAT)

Test Scenarios:
├── File Upload Test (SFTP partners):
│   ├── Partner uploads test file to SFTP home directory
│   ├── Verify file lands in landing zone (landing/PARTNERA/)
│   ├── Verify ADF pipeline triggers ingestion
│   └── Confirm file moves to raw zone with metadata
│
├── Routing Test (All partners):
│   ├── Verify routing message published to Service Bus topic
│   ├── Check message properties (transactionSet, partnerCode, priority)
│   ├── Confirm partner subscription receives message
│   └── Validate message body (ingestionId, blob URI, correlation ID)
│
├── Acknowledgment Test (Partners expecting acks):
│   ├── Generate 999 functional acknowledgment
│   ├── Verify acknowledgment written to outbound-staging/
│   ├── Confirm delivery to partner (SFTP outbound, API callback)
│   └── Check acknowledgment latency against SLA target
│
├── Error Handling Test:
│   ├── Upload invalid file (bad naming, corrupted content)
│   ├── Verify quarantine routing (landing → quarantine/)
│   ├── Check quarantine metadata (reason, timestamp, remediation guidance)
│   └── Confirm alert sent to operations team
│
└── Performance Test (Volume testing):
    ├── Upload batch of files (10-100 files)
    ├── Measure end-to-end latency (upload → raw → routing → acknowledgment)
    ├── Verify parallel processing (multiple files routed concurrently)
    └── Validate SLA compliance (p95 ingestion latency)

Step 7: Go-Live Checklist
├── Configuration deployed to production ✅
├── Infrastructure provisioned (SFTP user, Service Bus subscription, API endpoint) ✅
├── Credentials distributed to partner (SSH keys, OAuth2 client ID) ✅
├── Monitoring dashboards configured (partner-specific KQL queries) ✅
├── Alerting rules enabled (latency, error rate, DLQ depth) ✅
├── Runbook created (troubleshooting, escalation contacts) ✅
├── UAT signoff obtained (partner confirms successful testing) ✅
└── Go-live date scheduled (coordinated with partner)
```

### Phase 5: Operations & Monitoring

```text
Step 8: Day 1 Operations

Monitoring:
├── Partner-specific dashboard (Azure Monitor workbook)
├── KQL queries: Ingestion latency, routing success rate, acknowledgment timing
├── Alerts: SLA breaches, error rate spikes, DLQ depth > threshold
└── Daily health report: Email summary to partner manager

Partner Support:
├── Dedicated Slack channel or email alias
├── Partner portal (optional): Self-service file upload, acknowledgment download, SLA dashboard
├── Incident response: < 1 hour response for production issues
└── Monthly business review: Volume trends, SLA compliance, upcoming changes

Configuration Changes:
├── Follow Git workflow for config updates (PR → review → deploy)
├── Change notification: Email partner 48 hours before prod deployment
├── Rollback plan: Revert to previous config version if issues arise
└── Post-change validation: Re-run UAT test scenarios
```

---

## Configuration Management

### File Organization

```text
config/
├── partners/
│   ├── partners.schema.json           # JSON Schema for validation
│   ├── partners.sample.json           # Sample configurations
│   ├── partner-PARTNERA.json          # External Partner A (SFTP)
│   ├── partner-PARTNERB.json          # External Partner B (SFTP, PGP)
│   ├── partner-INTERNAL-ELIGIBILITY.json  # Internal Eligibility Service
│   ├── partner-INTERNAL-CLAIMS.json       # Internal Claims Processing
│   ├── partner-INTERNAL-ENROLLMENT.json   # Internal Enrollment Management
│   └── partner-INTERNAL-REMITTANCE.json   # Internal Remittance Processing
│
├── routing/
│   ├── routing-rules.json             # Global routing rules
│   └── subscription-filters.json      # Service Bus subscription filters
│
└── schemas/
    ├── canonical-response-v1.json     # Canonical response schema
    └── routing-message-v1.json        # Routing message schema
```

### Version Control Strategy

**Branch Strategy**:
- `main`: Production-ready configurations
- `develop`: Integration branch for UAT
- `feature/add-partner-{code}`: New partner onboarding
- `fix/update-partner-{code}-sla`: Configuration updates

**Commit Message Format**:
```text
[PARTNER] Action: Description

Examples:
[PARTNER] Add: Partner A Health (PARTNERA) - External payer with SFTP endpoint
[PARTNER] Update: INTERNAL-ELIGIBILITY SLA targets (ingestion latency 120s → 90s)
[PARTNER] Remove: PARTNERB - Decommissioned clearinghouse
```

**Tagging Strategy**:
```text
v1.0.0-partners-20250106  # Production release with partner configs
v1.1.0-partners-20250120  # Minor update (new partner added)
v1.1.1-partners-20250125  # Patch update (SLA adjustment)
```

### CI/CD Pipeline

**GitHub Actions Workflow** (`.github/workflows/partner-config-deploy.yml`):

```yaml
name: Partner Configuration Deployment

on:
  push:
    branches: [main, develop]
    paths: ['config/partners/**']
  pull_request:
    branches: [main, develop]
    paths: ['config/partners/**']

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Validate JSON Schema
        run: |
          python scripts/validate_partner_config.py \
            --schema config/partners/partners.schema.json \
            --configs config/partners/partner-*.json
      
      - name: Check for duplicate partner codes
        run: |
          python scripts/check_duplicate_partners.py \
            --configs config/partners/partner-*.json
      
      - name: Verify no hardcoded secrets
        run: |
          grep -r "password\|secret\|key" config/partners/*.json && exit 1 || exit 0
  
  deploy-dev:
    runs-on: ubuntu-latest
    needs: validate
    if: github.ref == 'refs/heads/develop'
    steps:
      - name: Deploy to Dev Blob Storage
        run: |
          az storage blob upload-batch \
            --account-name edistgdev01 \
            --destination config/partners \
            --source config/partners \
            --pattern "partner-*.json" \
            --auth-mode login
  
  deploy-test:
    runs-on: ubuntu-latest
    needs: validate
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to Test Blob Storage
        run: |
          az storage blob upload-batch \
            --account-name edistgtest01 \
            --destination config/partners \
            --source config/partners \
            --pattern "partner-*.json" \
            --auth-mode login
  
  deploy-prod:
    runs-on: ubuntu-latest
    needs: deploy-test
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
      - name: Manual Approval Required
        uses: trstringer/manual-approval@v1
        with:
          approvers: edi-platform-lead
      
      - name: Deploy to Prod Blob Storage
        run: |
          az storage blob upload-batch \
            --account-name edistgprod01 \
            --destination config/partners \
            --source config/partners \
            --pattern "partner-*.json" \
            --auth-mode login
      
      - name: Notify Operations Team
        run: |
          echo "Partner configuration deployed to production" | \
            az functionapp function invoke \
              --name func-notifications-prod \
              --function-name SendTeamsNotification
```

---

## Monitoring & Operations

### Partner Health Dashboard (KQL)

#### 1. Partner Ingestion Latency (SLA Compliance)

```kusto
// Monitor partner-specific ingestion latency vs. SLA targets
let partnerSLAs = datatable(partnerCode: string, slaSeconds: int) [
    "PARTNERA", 300,
    "INTERNAL-ELIGIBILITY", 120,
    "INTERNAL-ENROLLMENT", 300
];
EDIIngestion_CL
| where TimeGenerated > ago(24h)
| extend LatencySeconds = datetime_diff('second', IngestionCompletedTime, FileReceivedTime)
| summarize 
    P50 = percentile(LatencySeconds, 50),
    P95 = percentile(LatencySeconds, 95),
    P99 = percentile(LatencySeconds, 99),
    Count = count()
    by PartnerCode = tostring(customDimensions.partnerCode)
| join kind=inner partnerSLAs on $left.PartnerCode == $right.partnerCode
| extend SLACompliance = iff(P95 <= slaSeconds, "✅ Compliant", "❌ Breach")
| project PartnerCode, P50, P95, P99, SLATarget = slaSeconds, SLACompliance, Count
| order by P95 desc
```

#### 2. Partner Acknowledgment Timeliness

```kusto
// Track 999 acknowledgment generation latency per partner
OutboundAcknowledgment_CL
| where TimeGenerated > ago(24h)
| where AckType == "999"
| extend LatencyMinutes = datetime_diff('minute', AckGeneratedTime, IngestionCompletedTime)
| summarize 
    P95LatencyMinutes = percentile(LatencyMinutes, 95),
    Count = count()
    by PartnerCode = tostring(customDimensions.partnerCode)
| extend SLATarget = 15  // Default 999 SLA: 15 minutes
| extend SLACompliance = iff(P95LatencyMinutes <= SLATarget, "✅ Compliant", "❌ Breach")
| project PartnerCode, P95LatencyMinutes, SLATarget, SLACompliance, Count
```

#### 3. Partner Routing Success Rate

```kusto
// Calculate routing success rate per partner
RoutingEvent_CL
| where TimeGenerated > ago(24h)
| summarize 
    TotalMessages = count(),
    SuccessCount = countif(Status == "SUCCESS"),
    FailureCount = countif(Status == "FAILED")
    by PartnerCode = tostring(customDimensions.partnerCode)
| extend SuccessRate = round(100.0 * SuccessCount / TotalMessages, 2)
| extend Health = case(
    SuccessRate >= 99.0, "✅ Healthy",
    SuccessRate >= 95.0, "⚠️ Degraded",
    "❌ Critical"
)
| project PartnerCode, TotalMessages, SuccessCount, FailureCount, SuccessRate, Health
| order by SuccessRate asc
```

#### 4. Partner Transaction Volume Trends

```kusto
// Visualize transaction volume trends by partner
EDIIngestion_CL
| where TimeGenerated > ago(7d)
| extend PartnerCode = tostring(customDimensions.partnerCode)
| summarize Count = count() by PartnerCode, bin(TimeGenerated, 1h)
| render timechart
```

#### 5. Partner Error Rate by Reason

```kusto
// Identify top error reasons per partner
QuarantineLog_CL
| where TimeGenerated > ago(7d)
| extend 
    PartnerCode = tostring(customDimensions.partnerCode),
    Reason = tostring(customDimensions.quarantineReason)
| summarize ErrorCount = count() by PartnerCode, Reason
| order by ErrorCount desc
| take 20
```

#### 6. Partner Endpoint Health (Service Bus DLQ)

```kusto
// Monitor Service Bus dead-letter queue depth per partner subscription
ServiceBusMetrics_CL
| where TimeGenerated > ago(1h)
| where SubscriptionName startswith "sub-"
| summarize DeadLetterCount = max(DeadLetterMessageCount) by SubscriptionName
| extend PartnerCode = extract(@"sub-(.+)-partner", 1, SubscriptionName)
| where DeadLetterCount > 0
| project PartnerCode, SubscriptionName, DeadLetterCount
| order by DeadLetterCount desc
```

### Troubleshooting Scenarios

#### Scenario 1: Partner Ingestion Latency SLA Breach

**Symptoms**:
- Partner-specific dashboard shows P95 ingestion latency > SLA target
- Partner complains files are not processed promptly

**Diagnosis**:

1. Check for ADF pipeline backlog:
   ```kusto
   ADFPipelineRun_CL
   | where TimeGenerated > ago(1h)
   | where PipelineName == "pl_ingest_edi"
   | summarize PendingRuns = countif(Status == "InProgress"), FailedRuns = countif(Status == "Failed")
   ```

2. Verify partner-specific ingestion activity:
   ```kusto
   EDIIngestion_CL
   | where TimeGenerated > ago(1h)
   | where customDimensions.partnerCode == "PARTNERA"
   | summarize Count = count(), AvgLatency = avg(LatencySeconds) by bin(TimeGenerated, 5m)
   | render timechart
   ```

**Resolution**:
- If pipeline backlog: Scale ADF integration runtime (increase vCores or parallelism)
- If partner-specific spike: Check for partner volume anomaly, coordinate with partner to smooth upload cadence
- If validation bottleneck: Optimize validation logic (cache partner config, parallelize activities)

#### Scenario 2: Partner Routing Failures (DLQ Build-Up)

**Symptoms**:
- Service Bus DLQ message count increasing for partner subscription
- Partner reports missing transactions

**Diagnosis**:

1. Inspect DLQ messages:
   ```powershell
   # Peek dead-letter messages
   $messages = Get-AzServiceBusMessage `
     -NamespaceName "sb-edi-prod" `
     -TopicName "edi-routing" `
     -SubscriptionName "sub-eligibility-partner" `
     -IsDeadLetterQueue $true `
     -MaxMessageCount 10
   
   $messages | ForEach-Object {
       Write-Host "DeadLetterReason: $($_.Properties['DeadLetterReason'])"
       Write-Host "DeadLetterErrorDescription: $($_.Properties['DeadLetterErrorDescription'])"
   }
   ```

2. Check partner adapter logs:
   ```kusto
   FunctionAppLogs
   | where FunctionName == "EligibilityPartnerAdapter"
   | where TimeGenerated > ago(1h)
   | where Level == "Error"
   | project TimeGenerated, Message, Exception
   ```

**Resolution**:
- If adapter down: Restart Azure Function, check for deployment issues
- If transient error: Resubmit DLQ messages using Azure Portal or PowerShell
- If poison message: Quarantine specific message, investigate root cause (malformed blob, missing metadata)

#### Scenario 3: Partner Acknowledgment Delays

**Symptoms**:
- 999 acknowledgments not generated within SLA window
- Partner complains about missing acknowledgments

**Diagnosis**:

1. Check outbound orchestrator function:
   ```kusto
   FunctionAppLogs
   | where FunctionName == "OutboundOrchestrator"
   | where TimeGenerated > ago(1h)
   | where Level in ("Error", "Warning")
   | project TimeGenerated, Message, Exception
   ```

2. Verify control number store availability:
   ```sql
   SELECT TOP 10 *
   FROM dbo.ControlNumberAudit
   WHERE CreatedDate > DATEADD(HOUR, -1, GETUTCDATE())
   ORDER BY CreatedDate DESC;
   ```

**Resolution**:
- If orchestrator error: Check logs for exception details, restart function if needed
- If control number conflict: Resolve lock contention (ROWVERSION mismatch), implement exponential backoff retry
- If outbound staging full: Clean up delivered acknowledgments, increase storage quota

#### Scenario 4: Partner Configuration Deployment Failed

**Symptoms**:
- GitHub Actions workflow fails on partner config deployment
- Partner configuration not visible in production

**Diagnosis**:

1. Check GitHub Actions logs:
   - Review failed step (validation, deployment, approval)
   - Identify error message (schema violation, duplicate partner code, permission issue)

2. Validate configuration locally:
   ```powershell
   python scripts/validate_partner_config.py `
     --schema config/partners/partners.schema.json `
     --configs config/partners/partner-PARTNERA.json
   ```

**Resolution**:
- If schema violation: Fix JSON syntax or property values, re-run validation
- If permission issue: Verify Azure service principal has Blob Data Contributor role
- If approval timeout: Re-trigger workflow with manual approval

---

## Security

### Access Control

**Partner Configuration Access**:

| Role | Permissions | Use Case |
|------|------------|----------|
| **Partner Manager** | Read/Write partner configs, PR review | Onboard new partners, update SLAs |
| **EDI Platform Lead** | Read/Write all configs, approve prod deployments | Architecture changes, prod deployment approval |
| **Operations Team** | Read-only partner configs | Troubleshooting, SLA monitoring |
| **Partner (External)** | No direct access | Receive credentials via secure channel |

**RBAC Assignments** (Bicep):

```bicep
// Partner Manager: Contributor on config/partners/ container
resource partnerManagerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, partnerManagerGroupId, 'BlobDataContributor')
  scope: storageAccount::blobService::configContainer
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe')  // Storage Blob Data Contributor
    principalId: partnerManagerGroupId
    principalType: 'Group'
  }
}

// Operations Team: Reader on config/partners/ container
resource opsTeamRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, opsTeamGroupId, 'BlobDataReader')
  scope: storageAccount::blobService::configContainer
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions',
      '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')  // Storage Blob Data Reader
    principalId: opsTeamGroupId
    principalType: 'Group'
  }
}
```

### Credential Management

| Credential Type | Storage Location | Rotation Policy |
|-----------------|------------------|-----------------|
| SFTP SSH Private Keys | Partner-managed | Partner responsibility |
| SFTP SSH Public Keys | Azure Storage (partner home directory) | 90 days (automated via Azure Key Vault) |
| OAuth2 Client Secrets | Azure Key Vault | 90 days (manual rotation, notification alert) |
| Database Connection Strings | Azure Key Vault | 180 days (manual rotation, coordinated with DBA) |
| API Keys | Azure Key Vault | 90 days (automated via Key Vault rotation policy) |

### Audit Logging

**Partner Configuration Changes**:

```kusto
// Track partner configuration modifications
StorageBlobLogs
| where OperationName in ("PutBlob", "DeleteBlob")
| where Uri contains "config/partners"
| extend 
    User = tostring(parse_json(AuthenticationInfo).identity),
    PartnerCode = extract(@"partner-([A-Z0-9\-]+)\.json", 1, Uri)
| project TimeGenerated, OperationName, PartnerCode, User, IPAddress = CallerIpAddress
| order by TimeGenerated desc
```

**Partner Access Attempts (SFTP)**:

```kusto
// Monitor SFTP login attempts per partner
SFTPLogs_CL
| where TimeGenerated > ago(24h)
| where EventType == "LoginAttempt"
| summarize 
    SuccessCount = countif(Status == "Success"),
    FailureCount = countif(Status == "Failed")
    by PartnerCode = tostring(customDimensions.partnerCode), IPAddress = tostring(customDimensions.clientIP)
| where FailureCount > 5
| project PartnerCode, IPAddress, SuccessCount, FailureCount
```

---

## Performance Optimization

### Configuration Loading

**C# Configuration Service** (cached in Azure Function):

```csharp
public class PartnerConfigService
{
    private readonly BlobServiceClient _blobServiceClient;
    private readonly IMemoryCache _cache;
    private readonly ILogger _logger;
    
    private static readonly string ConfigContainerName = "config";
    private static readonly string ConfigBlobPrefix = "partners/partner-";
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(15);
    
    public async Task<PartnerConfig> GetPartnerConfig(string partnerCode)
    {
        string cacheKey = $"partner-config-{partnerCode}";
        
        if (_cache.TryGetValue(cacheKey, out PartnerConfig cachedConfig))
        {
            _logger.LogInformation($"Cache hit for partner: {partnerCode}");
            return cachedConfig;
        }
        
        // Cache miss - fetch from Blob Storage
        BlobContainerClient container = _blobServiceClient.GetBlobContainerClient(ConfigContainerName);
        BlobClient blobClient = container.GetBlobClient($"{ConfigBlobPrefix}{partnerCode}.json");
        
        if (!await blobClient.ExistsAsync())
        {
            throw new PartnerNotFoundException($"Partner not found: {partnerCode}");
        }
        
        BlobDownloadResult download = await blobClient.DownloadContentAsync();
        string json = download.Content.ToString();
        PartnerConfig config = JsonSerializer.Deserialize<PartnerConfig>(json);
        
        // Validate partner status
        if (config.Status != "active")
        {
            throw new PartnerInactiveException($"Partner inactive: {partnerCode}");
        }
        
        // Cache for 15 minutes
        _cache.Set(cacheKey, config, CacheDuration);
        _logger.LogInformation($"Loaded and cached partner config: {partnerCode}");
        
        return config;
    }
    
    public async Task<List<PartnerConfig>> GetAllActivePartners()
    {
        string cacheKey = "all-active-partners";
        
        if (_cache.TryGetValue(cacheKey, out List<PartnerConfig> cachedConfigs))
        {
            return cachedConfigs;
        }
        
        BlobContainerClient container = _blobServiceClient.GetBlobContainerClient(ConfigContainerName);
        
        List<PartnerConfig> configs = new List<PartnerConfig>();
        
        await foreach (BlobItem blobItem in container.GetBlobsAsync(prefix: ConfigBlobPrefix))
        {
            BlobClient blobClient = container.GetBlobClient(blobItem.Name);
            BlobDownloadResult download = await blobClient.DownloadContentAsync();
            PartnerConfig config = JsonSerializer.Deserialize<PartnerConfig>(download.Content.ToString());
            
            if (config.Status == "active")
            {
                configs.Add(config);
            }
        }
        
        _cache.Set(cacheKey, configs, CacheDuration);
        return configs;
    }
}
```

### Best Practices

1. **Cache partner configurations**: 15-minute TTL in-memory cache reduces Blob Storage reads
2. **Lazy loading**: Load configurations only when needed (not on function startup)
3. **Batch loading**: Pre-load all active partners for routing scenarios
4. **Schema validation**: Validate configurations at deployment time (CI/CD), not at runtime
5. **Status filtering**: Exclude `draft` and `inactive` partners from active routing

---

## Cross-References

### Related Documentation

- **[01-data-ingestion-layer.md](01-data-ingestion-layer.md)**: SFTP landing zone configuration
- **[02-processing-pipeline.md](02-processing-pipeline.md)**: Partner authorization validation in ADF pipeline
- **[03-routing-messaging.md](03-routing-messaging.md)**: Service Bus subscription creation per partner
- **[04-mapper-transformation.md](04-mapper-transformation.md)**: Partner-specific mapping rule overrides

### Specification Documents

- **[01-architecture-spec.md](../01-architecture-spec.md)**: Trading partner abstraction design
- **[05-sdlc-devops-spec.md](../05-sdlc-devops-spec.md)**: Configuration change management and CI/CD

### Infrastructure Code

- **infra/bicep/modules/storage-account.bicep**: Config container creation
- **infra/bicep/modules/service-bus.bicep**: Partner subscription provisioning
- **.github/workflows/partner-config-deploy.yml**: CI/CD pipeline for partner configs

### Configuration Files

- **config/partners/partners.schema.json**: JSON Schema definition
- **config/partners/partners.sample.json**: Sample partner configurations
- **scripts/validate_partner_config.py**: Configuration validation script

---

**Document Version**: 1.0  
**Last Updated**: January 6, 2025  
**Status**: Complete  
**Next Review**: Q2 2025
