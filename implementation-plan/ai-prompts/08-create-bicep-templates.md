# AI Prompt: Create Bicep Infrastructure Templates

## Objective
Create comprehensive Bicep templates for all Azure resources required by the EDI platform.

## Prerequisites
- Azure subscription active
- Resource groups created (or will be created by templates)
- Naming conventions approved
- Architecture specification reviewed

## Prompt

```
I need you to create comprehensive, production-ready Bicep templates for the Healthcare EDI Platform infrastructure.

Context:
- Project: Healthcare EDI transaction processing platform
- Compliance: HIPAA compliant - encryption at rest/transit, audit logging, private endpoints
- Architecture: Event-driven with Azure Data Factory, Function Apps, Service Bus, SQL Database
- Environments: dev, test, prod with appropriate sizing
- Region: East US 2
- Naming: <resource-type>-edi-<env>-<location>

Review the architecture specification first:
[Reference: docs/01-architecture-spec.md for complete requirements]

Please create a modular Bicep structure with these components:

---

## Directory Structure:
```
infra/
├── bicep/
│   ├── main.bicep                    # Main orchestration template
│   ├── modules/
│   │   ├── storage-account.bicep     # Storage with private endpoints
│   │   ├── function-app.bicep        # Function Apps with managed identity
│   │   ├── service-bus.bicep         # Service Bus with queues/topics
│   │   ├── data-factory.bicep        # ADF with managed VNet
│   │   ├── key-vault.bicep           # Key Vault with RBAC
│   │   ├── sql-database.bicep        # SQL DB with TDE
│   │   ├── app-insights.bicep        # Application Insights
│   │   ├── log-analytics.bicep       # Log Analytics workspace
│   │   ├── vnet.bicep                # Virtual Network
│   │   ├── private-endpoint.bicep    # Private Endpoint (reusable)
│   │   └── rbac.bicep                # Role assignments
env/
├── dev.parameters.json
├── test.parameters.json
└── prod.parameters.json
```

---

## 1. Main Orchestration Template (main.bicep)

Requirements:
- Takes environment parameter (dev/test/prod)
- Deploys all modules in correct dependency order
- Uses output from one module as input to another (e.g., VNet ID for private endpoints)
- Tags all resources with: Environment, Project, ManagedBy, CostCenter, DeployedAt
- Outputs important values for use in GitHub Actions (Function App names, connection strings, etc.)
- Includes comprehensive descriptions for all parameters

Modules to deploy:
1. Log Analytics Workspace
2. Application Insights
3. Virtual Network
4. Key Vault (with private endpoint)
5. Storage Accounts (3: raw files, processed files, archive)
6. Service Bus Namespace with queues and topics
7. SQL Database with elastic pool
8. Azure Data Factory with managed VNet
9. Function Apps (7 apps) with managed identity and VNet integration
10. RBAC role assignments

---

## 2. Storage Account Module (modules/storage-account.bicep)

Requirements:
- SKU: Standard_GRS for prod, Standard_LRS for dev/test
- Enable: Soft delete (7 days dev/test, 30 days prod)
- Enable: Versioning for blob storage
- Enable: Encryption at rest with customer-managed keys (from Key Vault)
- Configure: Lifecycle management to move to cool/archive tiers
- Create containers: inbound, outbound, archive, rejected, audit-logs
- Enable: Diagnostic logs to Log Analytics
- Configure: Private endpoint for blob service
- Enable: SFTP if needed for partner uploads
- Network: Deny public access, allow specific VNet subnets
- CORS: Configure for Partner Portal if applicable

---

## 3. Function App Module (modules/function-app.bicep)

Requirements:
- Runtime: .NET 9 Isolated
- Plan: Premium (EP1 for dev, EP2 for test/prod) - supports VNet integration
- Enable: Managed Identity (System-assigned)
- Enable: Application Insights integration
- Configure: VNet integration for private endpoint access
- Configure: Always On, HTTP/2, Minimum TLS 1.2
- Application Settings:
  - Connection strings (reference from Key Vault)
  - Service Bus connection
  - Storage account connection
  - Application Insights key
  - Environment-specific settings
- Enable: Deployment slots for test and prod (staging slot)
- Configure: Scale rules (min 1, max 10 for dev, max 30 for prod)
- Enable: Diagnostic logs

Function Apps to create (use module 7 times):
1. InboundRouter
2. OutboundOrchestrator
3. X12Parser
4. MapperEngine
5. ControlNumberGenerator
6. FileArchiver
7. NotificationService

---

## 4. Service Bus Module (modules/service-bus.bicep)

Requirements:
- SKU: Standard for dev/test, Premium for prod (supports VNet)
- Enable: Zone redundancy for prod
- Configure: Diagnostic logs to Log Analytics
- Create Queues:
  - inbound-router-queue (max delivery: 10, lock duration: 5 min)
  - outbound-assembly-queue
  - parser-queue
  - mapper-queue
  - notification-queue
  - dead-letter (auto-created but configure settings)
- Create Topics/Subscriptions:
  - transaction-events (topic)
    - audit-subscription (filter: all)
    - analytics-subscription (filter: completed transactions)
- Configure: Shared Access Policies for Function Apps (via managed identity preferred)
- Enable: Private endpoint for prod
- Network: Deny public access for prod, allow for dev/test

---

## 5. Azure Data Factory Module (modules/data-factory.bicep)

Requirements:
- Enable: Managed Virtual Network
- Enable: Git integration (configure after deployment)
- Configure: Linked Services via parameters
- Enable: Managed Identity for authentication
- Configure: Integration Runtime (Azure AutoResolve)
- Enable: Diagnostic logs
- Create: Triggers (will be configured via code)
- RBAC: Grant access to Storage, Key Vault, SQL Database

---

## 6. Key Vault Module (modules/key-vault.bicep)

Requirements:
- SKU: Standard for dev/test, Premium for prod (HSM-backed)
- Enable: RBAC authorization mode (not access policies)
- Enable: Soft delete (90 days) and purge protection (prod only)
- Enable: Private endpoint
- Network: Deny public access for prod, firewall for dev/test
- Configure: Diagnostic logs
- Create secrets (placeholders, values set post-deployment):
  - sql-connection-string
  - storage-account-key
  - service-bus-connection-string
  - sftp-credentials
  - partner-api-keys
- RBAC: Grant Key Vault Secrets Officer to deployment identity
- RBAC: Grant Key Vault Secrets User to Function App managed identities

---

## 7. SQL Database Module (modules/sql-database.bicep)

Requirements:
- Server: Enable Azure AD authentication
- Server: Enable Managed Identity
- Server: Deny public access, allow from VNet only
- Database: Use elastic pool (Basic for dev, Standard S2 for test, Premium P2 for prod)
- Enable: Transparent Data Encryption (TDE) with customer-managed key
- Enable: Advanced Data Security
- Enable: Auditing to storage account
- Enable: Diagnostic logs to Log Analytics
- Configure: Firewall rules for development (remove in prod)
- Configure: Private endpoint for prod
- Create databases:
  - EDI_ControlNumbers
  - EDI_EventStore
  - EDI_Configuration

---

## 8. Virtual Network Module (modules/vnet.bicep)

Requirements:
- Address space: 10.0.0.0/16 (dev), 10.1.0.0/16 (test), 10.2.0.0/16 (prod)
- Subnets:
  - function-apps-subnet (10.x.1.0/24) - delegated to Microsoft.Web/serverFarms
  - private-endpoints-subnet (10.x.2.0/24)
  - adf-managed-subnet (10.x.3.0/24) - delegated to Microsoft.DataFactory/factories
  - app-gateway-subnet (10.x.4.0/24) - for future API Management
- Configure: NSG on each subnet with appropriate rules
- Enable: Service endpoints for Storage, SQL, Key Vault
- Enable: DDoS protection for prod

---

## 9. Private Endpoint Module (modules/private-endpoint.bicep)

Requirements:
- Reusable module that accepts:
  - Resource ID to connect to
  - Subnet ID for endpoint
  - Private DNS zone for registration
- Configure: Automatic DNS registration
- Create for: Storage, Key Vault, SQL Server, Service Bus (prod)

---

## 10. RBAC Module (modules/rbac.bicep)

Requirements:
- Assign roles at appropriate scopes
- Use built-in roles where possible
- Assignments:
  - Function Apps → Storage Blob Data Contributor on storage accounts
  - Function Apps → Azure Service Bus Data Sender/Receiver
  - Function Apps → Key Vault Secrets User
  - ADF → Storage Blob Data Contributor
  - ADF → SQL DB Contributor
  - Deployment identity → Contributor on resource group

---

## Parameter Files:

Create parameter files for each environment with appropriate values:

### dev.parameters.json
- Smallest SKUs
- Public access allowed (with IP restrictions)
- Shorter retention periods
- Lower auto-scale limits

### test.parameters.json
- Medium SKUs
- Mix of public/private access
- Standard retention
- Medium auto-scale limits

### prod.parameters.json
- Largest SKUs with redundancy
- Private endpoints required
- Maximum retention (compliance)
- High auto-scale limits
- Zone redundancy enabled

---

Best practices to follow:
- Use @secure() decorator for sensitive parameters
- Use @description() for all parameters
- Use resource symbolic names and avoid hard-coded IDs
- Use existing resources with 'existing' keyword where needed
- Output important values for downstream use
- Use modules for reusability
- Include comprehensive comments
- Use variables for computed values
- Enable diagnostic logs on all resources
- Tag all resources consistently
- Use managed identities instead of keys/passwords
- Follow principle of least privilege for RBAC
- Use latest API versions
- Include metadata for documentation

Also provide:
1. Deployment commands for each environment
2. Validation commands
3. What-if analysis commands
4. How to update a single module
5. Troubleshooting guide for common deployment errors
```

## Expected Outcome

After running this prompt, you should have:
- ✅ Complete Bicep infrastructure as code
- ✅ Modular, reusable templates
- ✅ Environment-specific parameter files
- ✅ HIPAA-compliant configuration
- ✅ Production-ready with security best practices

## Validation Steps

1. Validate Bicep syntax locally:
   ```powershell
   cd infra/bicep
   
   # Validate main template
   az bicep build --file main.bicep
   
   # Validate each module
   Get-ChildItem -Path modules -Filter *.bicep | ForEach-Object {
       az bicep build --file $_.FullName
   }
   ```

2. Run what-if analysis (requires Azure):
   ```powershell
   # For dev environment
   az deployment group what-if `
     --resource-group rg-edi-dev-eastus2 `
     --template-file infra/bicep/main.bicep `
     --parameters @env/dev.parameters.json
   ```

3. Deploy to dev environment:
   ```powershell
   az deployment group create `
     --resource-group rg-edi-dev-eastus2 `
     --template-file infra/bicep/main.bicep `
     --parameters @env/dev.parameters.json `
     --name "initial-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
   ```

4. Verify deployment:
   ```powershell
   # Check deployment status
   az deployment group show `
     --resource-group rg-edi-dev-eastus2 `
     --name initial-deployment-<timestamp> `
     --query properties.provisioningState
   
   # List deployed resources
   az resource list --resource-group rg-edi-dev-eastus2 --output table
   ```

## Troubleshooting

**Error: Resource provider not registered**
```powershell
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.ServiceBus
az provider register --namespace Microsoft.DataFactory
# Wait 5-10 minutes for registration
```

**Error: Cannot create private endpoint**
- Verify VNet and subnet exist
- Check subnet delegation settings
- Ensure private DNS zone is configured

**Error: Key Vault access denied**
- Verify managed identity is enabled
- Check RBAC assignments
- Ensure deployment identity has Key Vault Secrets Officer role

**Error: SKU not available in region**
- Check available SKUs: `az vm list-skus --location eastus2 --output table`
- Update parameter file with available SKU

## Next Steps

After successful deployment:
- Configure Key Vault secrets manually or via script
- Deploy Azure Functions [09-create-function-projects.md](09-create-function-projects.md)
- Configure ADF pipelines [06-adf-pipeline-project.md](../06-adf-pipeline-project.md)
- Set up monitoring [16-create-monitoring-dashboards.md](16-create-monitoring-dashboards.md)
