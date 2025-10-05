// ============================================================================
// Main Orchestration Template - Healthcare EDI Platform
// ============================================================================
// This template deploys the complete EDI platform infrastructure including:
// - Networking (VNet, Subnets, NSGs)
// - Monitoring (Log Analytics, Application Insights)
// - Security (Key Vault with private endpoint)
// - Storage (3 storage accounts with private endpoints)
// - Messaging (Service Bus with queues and topics)
// - Data Platform (SQL Database with elastic pool)
// - Integration (Azure Data Factory)
// - Compute (7 Function Apps with VNet integration)
// - RBAC (Role assignments for managed identities)
//
// Compliance: HIPAA-compliant with encryption, audit logging, private endpoints
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Environment name (dev, test, prod)')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Project identifier used in resource naming')
param projectName string = 'edi'

@description('Cost center for billing attribution')
param costCenter string

@description('Deployment timestamp')
param deployedAt string = utcNow('yyyy-MM-dd HH:mm:ss')

@description('Tags to apply to all resources')
param tags object = {
  Environment: environment
  Project: 'Healthcare-EDI-Platform'
  ManagedBy: 'Bicep'
  CostCenter: costCenter
  DeployedAt: deployedAt
}

// Virtual Network Configuration
@description('Virtual network address prefix')
param vnetAddressPrefix string

@description('Function Apps subnet address prefix')
param functionAppsSubnetPrefix string

@description('Private endpoints subnet address prefix')
param privateEndpointsSubnetPrefix string

@description('ADF managed subnet address prefix')
param adfManagedSubnetPrefix string

@description('App Gateway subnet address prefix (reserved for future)')
param appGatewaySubnetPrefix string

// Storage Configuration
@description('Storage account SKU')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageAccountSku string

@description('Storage soft delete retention days')
param storageSoftDeleteDays int

// SQL Database Configuration
@description('SQL Server admin username')
param sqlAdminUsername string

@description('SQL Server admin password')
@secure()
param sqlAdminPassword string

@description('SQL elastic pool SKU')
param sqlElasticPoolSku string

@description('SQL elastic pool capacity (eDTUs)')
param sqlElasticPoolCapacity int

// Service Bus Configuration
@description('Service Bus SKU (Basic, Standard, Premium)')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param serviceBusSku string

@description('Enable zone redundancy for Service Bus (Premium only)')
param serviceBusZoneRedundant bool = false

// Function App Configuration
@description('Function App hosting plan SKU')
@allowed([
  'EP1'
  'EP2'
  'EP3'
])
param functionAppSku string

@description('Function App minimum instances')
param functionAppMinInstances int = 1

@description('Function App maximum instances')
param functionAppMaxInstances int = 10

// Key Vault Configuration
@description('Key Vault SKU')
@allowed([
  'standard'
  'premium'
])
param keyVaultSku string

@description('Enable purge protection for Key Vault (prod only)')
param keyVaultEnablePurgeProtection bool

// Security Configuration
@description('Enable private endpoints for all resources')
param enablePrivateEndpoints bool

@description('Enable DDoS protection (prod only)')
param enableDdosProtection bool = false

@description('Allowed IP addresses for resource access (dev/test only)')
param allowedIpAddresses array = []

// ============================================================================
// Variables
// ============================================================================

var locationAbbr = {
  eastus: 'eus'
  eastus2: 'eus2'
  westus: 'wus'
  westus2: 'wus2'
  centralus: 'cus'
}

var locationShort = contains(locationAbbr, location) ? locationAbbr[location] : 'eus2'

// Resource naming convention: <type>-<project>-<env>-<location>
var namingPrefix = '${projectName}-${environment}-${locationShort}'

var resourceNames = {
  logAnalytics: 'log-${namingPrefix}'
  appInsights: 'appi-${namingPrefix}'
  vnet: 'vnet-${namingPrefix}'
  nsgFunctionApps: 'nsg-functions-${namingPrefix}'
  nsgPrivateEndpoints: 'nsg-private-${namingPrefix}'
  nsgAdf: 'nsg-adf-${namingPrefix}'
  keyVault: 'kv-${projectName}-${environment}-${uniqueString(resourceGroup().id)}'
  storageRaw: 'st${projectName}raw${environment}${uniqueString(resourceGroup().id)}'
  storageProcessed: 'st${projectName}proc${environment}${uniqueString(resourceGroup().id)}'
  storageArchive: 'st${projectName}arch${environment}${uniqueString(resourceGroup().id)}'
  serviceBus: 'sb-${namingPrefix}'
  sqlServer: 'sql-${namingPrefix}'
  elasticPool: 'pool-${namingPrefix}'
  dataFactory: 'adf-${namingPrefix}'
  functionAppPlan: 'asp-${namingPrefix}'
}

var functionApps = [
  {
    name: 'func-inbound-router-${namingPrefix}'
    displayName: 'Inbound Router'
    purpose: 'Routes incoming EDI files to appropriate processing queues'
  }
  {
    name: 'func-outbound-orch-${namingPrefix}'
    displayName: 'Outbound Orchestrator'
    purpose: 'Orchestrates outbound EDI file assembly and delivery'
  }
  {
    name: 'func-x12-parser-${namingPrefix}'
    displayName: 'X12 Parser'
    purpose: 'Parses X12 EDI transactions into structured data'
  }
  {
    name: 'func-mapper-engine-${namingPrefix}'
    displayName: 'Mapper Engine'
    purpose: 'Transforms data between internal and partner formats'
  }
  {
    name: 'func-control-num-${namingPrefix}'
    displayName: 'Control Number Generator'
    purpose: 'Generates and tracks EDI control numbers'
  }
  {
    name: 'func-file-archiver-${namingPrefix}'
    displayName: 'File Archiver'
    purpose: 'Archives processed files for compliance'
  }
  {
    name: 'func-notification-${namingPrefix}'
    displayName: 'Notification Service'
    purpose: 'Sends notifications for transaction events'
  }
]

var sqlDatabases = [
  {
    name: 'EDI_ControlNumbers'
    purpose: 'Stores EDI control numbers and sequences'
  }
  {
    name: 'EDI_EventStore'
    purpose: 'Event sourcing database for transaction history'
  }
  {
    name: 'EDI_Configuration'
    purpose: 'Runtime configuration and partner metadata'
  }
]

var serviceBusQueues = [
  {
    name: 'inbound-router-queue'
    maxDeliveryCount: 10
    lockDuration: 'PT5M'
    requiresDuplicateDetection: true
  }
  {
    name: 'outbound-assembly-queue'
    maxDeliveryCount: 10
    lockDuration: 'PT5M'
    requiresDuplicateDetection: true
  }
  {
    name: 'parser-queue'
    maxDeliveryCount: 10
    lockDuration: 'PT5M'
    requiresDuplicateDetection: false
  }
  {
    name: 'mapper-queue'
    maxDeliveryCount: 10
    lockDuration: 'PT5M'
    requiresDuplicateDetection: false
  }
  {
    name: 'notification-queue'
    maxDeliveryCount: 5
    lockDuration: 'PT2M'
    requiresDuplicateDetection: false
  }
]

var serviceBusTopics = [
  {
    name: 'transaction-events'
    subscriptions: [
      {
        name: 'audit-subscription'
        requiresSession: false
        maxDeliveryCount: 10
      }
      {
        name: 'analytics-subscription'
        requiresSession: false
        maxDeliveryCount: 10
      }
    ]
  }
]

var storageContainers = [
  'inbound'
  'outbound'
  'archive'
  'rejected'
  'audit-logs'
  'temp'
]

// ============================================================================
// Module: Log Analytics Workspace
// ============================================================================

module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'deploy-log-analytics'
  params: {
    name: resourceNames.logAnalytics
    location: location
    tags: tags
    retentionInDays: environment == 'prod' ? 90 : 30
  }
}

// ============================================================================
// Module: Application Insights
// ============================================================================

module appInsights 'modules/app-insights.bicep' = {
  name: 'deploy-app-insights'
  params: {
    name: resourceNames.appInsights
    location: location
    tags: tags
    workspaceResourceId: logAnalytics.outputs.workspaceId
  }
}

// ============================================================================
// Module: Virtual Network with Subnets and NSGs
// ============================================================================

module vnet 'modules/vnet.bicep' = {
  name: 'deploy-vnet'
  params: {
    vnetName: resourceNames.vnet
    location: location
    tags: tags
    addressPrefix: vnetAddressPrefix
    functionAppsSubnetPrefix: functionAppsSubnetPrefix
    privateEndpointsSubnetPrefix: privateEndpointsSubnetPrefix
    adfManagedSubnetPrefix: adfManagedSubnetPrefix
    appGatewaySubnetPrefix: appGatewaySubnetPrefix
    nsgFunctionAppsName: resourceNames.nsgFunctionApps
    nsgPrivateEndpointsName: resourceNames.nsgPrivateEndpoints
    nsgAdfName: resourceNames.nsgAdf
    enableDdosProtection: enableDdosProtection
  }
}

// ============================================================================
// Module: Key Vault
// ============================================================================

module keyVault 'modules/key-vault.bicep' = {
  name: 'deploy-key-vault'
  params: {
    name: resourceNames.keyVault
    location: location
    tags: tags
    sku: keyVaultSku
    enablePurgeProtection: keyVaultEnablePurgeProtection
    enablePrivateEndpoint: enablePrivateEndpoints
    vnetId: vnet.outputs.vnetId
    privateEndpointSubnetId: vnet.outputs.privateEndpointsSubnetId
    workspaceId: logAnalytics.outputs.workspaceId
    allowedIpAddresses: allowedIpAddresses
  }
}

// ============================================================================
// Module: Storage Accounts (Raw, Processed, Archive)
// ============================================================================

module storageRaw 'modules/storage-account.bicep' = {
  name: 'deploy-storage-raw'
  params: {
    name: resourceNames.storageRaw
    location: location
    tags: union(tags, { Purpose: 'Raw inbound files' })
    sku: storageAccountSku
    containers: storageContainers
    softDeleteDays: storageSoftDeleteDays
    enablePrivateEndpoint: enablePrivateEndpoints
    vnetId: vnet.outputs.vnetId
    privateEndpointSubnetId: vnet.outputs.privateEndpointsSubnetId
    allowedSubnetIds: [vnet.outputs.functionAppsSubnetId, vnet.outputs.adfManagedSubnetId]
    allowedIpAddresses: allowedIpAddresses
    workspaceId: logAnalytics.outputs.workspaceId
    enableSftp: environment == 'prod'
  }
}

module storageProcessed 'modules/storage-account.bicep' = {
  name: 'deploy-storage-processed'
  params: {
    name: resourceNames.storageProcessed
    location: location
    tags: union(tags, { Purpose: 'Processed files' })
    sku: storageAccountSku
    containers: storageContainers
    softDeleteDays: storageSoftDeleteDays
    enablePrivateEndpoint: enablePrivateEndpoints
    vnetId: vnet.outputs.vnetId
    privateEndpointSubnetId: vnet.outputs.privateEndpointsSubnetId
    allowedSubnetIds: [vnet.outputs.functionAppsSubnetId, vnet.outputs.adfManagedSubnetId]
    allowedIpAddresses: allowedIpAddresses
    workspaceId: logAnalytics.outputs.workspaceId
    enableSftp: false
  }
}

module storageArchive 'modules/storage-account.bicep' = {
  name: 'deploy-storage-archive'
  params: {
    name: resourceNames.storageArchive
    location: location
    tags: union(tags, { Purpose: 'Long-term archive' })
    sku: storageAccountSku
    containers: storageContainers
    softDeleteDays: storageSoftDeleteDays
    enablePrivateEndpoint: enablePrivateEndpoints
    vnetId: vnet.outputs.vnetId
    privateEndpointSubnetId: vnet.outputs.privateEndpointsSubnetId
    allowedSubnetIds: [vnet.outputs.functionAppsSubnetId, vnet.outputs.adfManagedSubnetId]
    allowedIpAddresses: allowedIpAddresses
    workspaceId: logAnalytics.outputs.workspaceId
    enableSftp: false
  }
}

// ============================================================================
// Module: Service Bus
// ============================================================================

module serviceBus 'modules/service-bus.bicep' = {
  name: 'deploy-service-bus'
  params: {
    name: resourceNames.serviceBus
    location: location
    tags: tags
    sku: serviceBusSku
    zoneRedundant: serviceBusZoneRedundant
    queues: serviceBusQueues
    topics: serviceBusTopics
    enablePrivateEndpoint: enablePrivateEndpoints && serviceBusSku == 'Premium'
    vnetId: vnet.outputs.vnetId
    privateEndpointSubnetId: vnet.outputs.privateEndpointsSubnetId
    workspaceId: logAnalytics.outputs.workspaceId
    allowedIpAddresses: allowedIpAddresses
  }
}

// ============================================================================
// Module: SQL Server and Databases
// ============================================================================

module sqlServer 'modules/sql-database.bicep' = {
  name: 'deploy-sql-server'
  params: {
    serverName: resourceNames.sqlServer
    location: location
    tags: tags
    adminUsername: sqlAdminUsername
    adminPassword: sqlAdminPassword
    elasticPoolName: resourceNames.elasticPool
    elasticPoolSku: sqlElasticPoolSku
    elasticPoolCapacity: sqlElasticPoolCapacity
    databases: sqlDatabases
    enablePrivateEndpoint: enablePrivateEndpoints
    vnetId: vnet.outputs.vnetId
    privateEndpointSubnetId: vnet.outputs.privateEndpointsSubnetId
    workspaceId: logAnalytics.outputs.workspaceId
    allowedIpAddresses: allowedIpAddresses
    keyVaultName: keyVault.outputs.keyVaultName
  }
}

// ============================================================================
// Module: Azure Data Factory
// ============================================================================

module dataFactory 'modules/data-factory.bicep' = {
  name: 'deploy-data-factory'
  params: {
    name: resourceNames.dataFactory
    location: location
    tags: tags
    managedVnetEnabled: true
    workspaceId: logAnalytics.outputs.workspaceId
  }
}

// ============================================================================
// Module: Function App Hosting Plan
// ============================================================================

resource functionAppPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: resourceNames.functionAppPlan
  location: location
  tags: tags
  sku: {
    name: functionAppSku
    tier: 'ElasticPremium'
  }
  kind: 'elastic'
  properties: {
    reserved: false // Windows
    maximumElasticWorkerCount: functionAppMaxInstances
  }
}

// ============================================================================
// Module: Function Apps (7 instances)
// ============================================================================

module functionAppsDeployment 'modules/function-app.bicep' = [for (func, i) in functionApps: {
  name: 'deploy-${func.name}'
  params: {
    name: func.name
    location: location
    tags: union(tags, {
      DisplayName: func.displayName
      Purpose: func.purpose
    })
    appServicePlanId: functionAppPlan.id
    vnetSubnetId: vnet.outputs.functionAppsSubnetId
    appInsightsConnectionString: appInsights.outputs.connectionString
    appInsightsInstrumentationKey: appInsights.outputs.instrumentationKey
    keyVaultName: keyVault.outputs.keyVaultName
    storageAccountName: storageRaw.outputs.storageAccountName
    serviceBusNamespace: serviceBus.outputs.serviceBusNamespace
    environment: environment
    minInstances: functionAppMinInstances
    maxInstances: functionAppMaxInstances
    enableDeploymentSlot: environment != 'dev'
  }
  dependsOn: [
    storageRaw
    storageProcessed
    storageArchive
    serviceBus
    sqlServer
  ]
}]

// ============================================================================
// Module: RBAC Role Assignments
// ============================================================================

module rbacAssignments 'modules/rbac.bicep' = {
  name: 'deploy-rbac-assignments'
  params: {
    functionAppPrincipalIds: [for (func, i) in functionApps: functionAppsDeployment[i].outputs.principalId]
    dataFactoryPrincipalId: dataFactory.outputs.principalId
    storageAccountIds: [
      storageRaw.outputs.storageAccountId
      storageProcessed.outputs.storageAccountId
      storageArchive.outputs.storageAccountId
    ]
    serviceBusId: serviceBus.outputs.serviceBusId
    keyVaultId: keyVault.outputs.keyVaultId
    sqlServerResourceId: sqlServer.outputs.sqlServerResourceId
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Resource Group ID')
output resourceGroupId string = resourceGroup().id

@description('Log Analytics Workspace ID')
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId

@description('Application Insights Connection String')
output appInsightsConnectionString string = appInsights.outputs.connectionString

@description('Application Insights Instrumentation Key')
output appInsightsInstrumentationKey string = appInsights.outputs.instrumentationKey

@description('Virtual Network ID')
output vnetId string = vnet.outputs.vnetId

@description('Key Vault Name')
output keyVaultName string = keyVault.outputs.keyVaultName

@description('Key Vault URI')
output keyVaultUri string = keyVault.outputs.keyVaultUri

@description('Storage Account Names')
output storageAccountNames object = {
  raw: storageRaw.outputs.storageAccountName
  processed: storageProcessed.outputs.storageAccountName
  archive: storageArchive.outputs.storageAccountName
}

@description('Storage Account IDs')
output storageAccountIds object = {
  raw: storageRaw.outputs.storageAccountId
  processed: storageProcessed.outputs.storageAccountId
  archive: storageArchive.outputs.storageAccountId
}

@description('Service Bus Namespace')
output serviceBusNamespace string = serviceBus.outputs.serviceBusNamespace

@description('Service Bus ID')
output serviceBusId string = serviceBus.outputs.serviceBusId

@description('SQL Server Name')
output sqlServerName string = sqlServer.outputs.sqlServerName

@description('SQL Server FQDN')
output sqlServerFqdn string = sqlServer.outputs.sqlServerFqdn

@description('SQL Database Names')
output sqlDatabaseNames array = [for db in sqlDatabases: db.name]

@description('Data Factory Name')
output dataFactoryName string = dataFactory.outputs.dataFactoryName

@description('Data Factory ID')
output dataFactoryId string = dataFactory.outputs.dataFactoryId

@description('Function App Names')
output functionAppNames array = [for (func, i) in functionApps: func.name]

@description('Function App IDs')
output functionAppIds array = [for (func, i) in functionApps: functionAppsDeployment[i].outputs.functionAppId]

@description('Function App Principal IDs (for RBAC)')
output functionAppPrincipalIds array = [for (func, i) in functionApps: functionAppsDeployment[i].outputs.principalId]

@description('Deployment Summary')
output deploymentSummary object = {
  environment: environment
  location: location
  resourceCount: {
    functionApps: length(functionApps)
    storageAccounts: 3
    databases: length(sqlDatabases)
    serviceBusQueues: length(serviceBusQueues)
    serviceBusTopics: length(serviceBusTopics)
  }
  namingPrefix: namingPrefix
  deploymentTimestamp: deployedAt
}
