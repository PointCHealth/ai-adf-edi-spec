@description('The name of the SQL Server')
param serverName string

@description('The location where the SQL Server will be deployed')
param location string

@description('Tags to apply to the SQL Server')
param tags object = {}

@description('The administrator username for the SQL Server')
param administratorLogin string

@description('The administrator password for the SQL Server')
@secure()
param administratorLoginPassword string

@description('Enable Azure AD authentication only')
param azureAdOnlyAuthentication bool = false

@description('Enable public network access')
param publicNetworkAccess string = 'Enabled'

@description('Array of database definitions')
param databases array = []

@description('Elastic pool name')
param elasticPoolName string

@description('Elastic pool SKU name')
@allowed([
  'BasicPool'
  'StandardPool'
  'PremiumPool'
  'GP_Gen5'
  'BC_Gen5'
])
param elasticPoolSku string = 'GP_Gen5'

@description('Elastic pool capacity (DTU or vCores)')
param elasticPoolCapacity int = 2

@description('Maximum size of the elastic pool in bytes')
param elasticPoolMaxSizeBytes int = 34359738368 // 32 GB

@description('Enable zone redundancy for the elastic pool')
param zoneRedundant bool = false

@description('Per database settings - min capacity')
param perDatabaseMinCapacity int = 0

@description('Per database settings - max capacity')
param perDatabaseMaxCapacity int = 2

@description('Resource ID of the Log Analytics workspace for diagnostics')
param workspaceId string

resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: serverName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: publicNetworkAccess
    administrators: azureAdOnlyAuthentication ? {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: administratorLogin
      sid: ''
      tenantId: tenant().tenantId
      azureADOnlyAuthentication: azureAdOnlyAuthentication
    } : null
  }
}

// Firewall rule to allow Azure services
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Transparent Data Encryption
resource tde 'Microsoft.Sql/servers/encryptionProtector@2023-05-01-preview' = {
  parent: sqlServer
  name: 'current'
  properties: {
    serverKeyType: 'ServiceManaged'
    serverKeyName: 'ServiceManaged'
  }
}

// Auditing settings
resource auditingSettings 'Microsoft.Sql/servers/auditingSettings@2023-05-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    retentionDays: 90
    auditActionsAndGroups: [
      'BATCH_COMPLETED_GROUP'
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
    ]
  }
}

// Security alert policies
resource securityAlertPolicy 'Microsoft.Sql/servers/securityAlertPolicies@2023-05-01-preview' = {
  parent: sqlServer
  name: 'Default'
  properties: {
    state: 'Enabled'
    emailAccountAdmins: true
    retentionDays: 90
  }
}

// Vulnerability assessment
resource vulnerabilityAssessment 'Microsoft.Sql/servers/vulnerabilityAssessments@2023-05-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    recurringScans: {
      isEnabled: true
      emailSubscriptionAdmins: true
    }
  }
  dependsOn: [
    securityAlertPolicy
  ]
}

// Elastic pool
resource elasticPool 'Microsoft.Sql/servers/elasticPools@2023-05-01-preview' = {
  parent: sqlServer
  name: elasticPoolName
  location: location
  tags: tags
  sku: {
    name: elasticPoolSku
    tier: elasticPoolSku == 'GP_Gen5' ? 'GeneralPurpose' : (elasticPoolSku == 'BC_Gen5' ? 'BusinessCritical' : elasticPoolSku)
    capacity: elasticPoolCapacity
  }
  properties: {
    maxSizeBytes: elasticPoolMaxSizeBytes
    zoneRedundant: zoneRedundant
    perDatabaseSettings: {
      minCapacity: perDatabaseMinCapacity
      maxCapacity: perDatabaseMaxCapacity
    }
    licenseType: 'LicenseIncluded'
  }
}

// Databases
resource sqlDatabases 'Microsoft.Sql/servers/databases@2023-05-01-preview' = [for db in databases: {
  parent: sqlServer
  name: db.name
  location: location
  tags: tags
  sku: {
    name: 'ElasticPool'
    tier: elasticPoolSku == 'GP_Gen5' ? 'GeneralPurpose' : (elasticPoolSku == 'BC_Gen5' ? 'BusinessCritical' : elasticPoolSku)
  }
  properties: {
    elasticPoolId: elasticPool.id
    collation: db.?collation ?? 'SQL_Latin1_General_CP1_CI_AS'
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: db.?maxSizeBytes ?? null
    readScale: elasticPoolSku == 'BC_Gen5' ? 'Enabled' : 'Disabled'
    requestedBackupStorageRedundancy: db.?backupStorageRedundancy ?? 'Geo'
  }
}]

// Diagnostic settings for SQL Server
resource serverDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: sqlServer
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Diagnostic settings for Elastic Pool
resource elasticPoolDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'elasticpool-diagnostics'
  scope: elasticPool
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Diagnostic settings for each database
resource databaseDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = [for (db, i) in databases: {
  name: 'db-${db.name}-diagnostics'
  scope: sqlDatabases[i]
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}]

@description('The resource ID of the SQL Server')
output sqlServerId string = sqlServer.id

@description('The name of the SQL Server')
output sqlServerName string = sqlServer.name

@description('The fully qualified domain name of the SQL Server')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('The resource ID of the elastic pool')
output elasticPoolId string = elasticPool.id

@description('The name of the elastic pool')
output elasticPoolName string = elasticPool.name

@description('Array of database names')
output databaseNames array = [for (db, i) in databases: sqlDatabases[i].name]

@description('The principal ID of the SQL Server managed identity')
output principalId string = sqlServer.identity.principalId
