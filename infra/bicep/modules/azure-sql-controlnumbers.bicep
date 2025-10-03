@description('Azure region for SQL resources.')
param location string

@description('Tag map applied to all resources in this module.')
param tags object = {}

@description('Azure SQL logical server name.')
param sqlServerName string

@description('Azure SQL database name for control numbers.')
param sqlDatabaseName string

@description('Azure SQL SKU (for example GP_S_Gen5_2).')
param sqlSkuName string = 'GP_S_Gen5_2'

@description('Server admin login. Use deployment-time secret delivery (e.g., GitHub env secret).')
param administratorLogin string

@secure()
@description('Server admin password. Do not hard-code in parameter files; supply via secure pipeline secret.')
param administratorPassword string

@description('Optional AAD administrator settings. Leave blank to skip.')
param aadAdministrator object = {
  login: ''
  sid: ''
  tenantId: ''
}

@description('Log Analytics workspace resource ID for SQL diagnostics. Leave empty to skip diagnostics wiring.')
param logAnalyticsWorkspaceId string = ''

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
  tags: tags
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  name: '${sqlServer.name}/${sqlDatabaseName}'
  location: location
  sku: {
    name: sqlSkuName
  }
  properties: {
    autoPauseDelay: -1
    zoneRedundant: false
    readScale: 'Disabled'
  }
  tags: tags
}

@description('Allow Azure services for management plane access while private endpoints are configured elsewhere.')
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  name: '${sqlServer.name}/AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

@description('Optional AAD administrator assignment for SQL logical server.')
resource sqlAadAdmin 'Microsoft.Sql/servers/administrators@2022-05-01-preview' = if (!empty(aadAdministrator.login) && !empty(aadAdministrator.sid)) {
  name: '${sqlServer.name}/activeDirectory'
  properties: {
    administratorType: 'ActiveDirectory'
    login: aadAdministrator.login
    sid: aadAdministrator.sid
    tenantId: empty(aadAdministrator.tenantId) ? tenant().tenantId : aadAdministrator.tenantId
  }
}

var diagnosticCategories = [
  'DevOpsOperations'
  'SQLInsights'
  'AutomaticTuning'
  'QueryStoreRuntimeStatistics'
  'QueryStoreWaitStatistics'
  'Errors'
  'DatabaseWaitStatistics'
  'Blocks'
  'Timeouts'
]

resource sqlDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'sql-${sqlDatabaseName}-diag'
  scope: sqlDatabase
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [for category in diagnosticCategories: {
      category: category
      enabled: true
      retentionPolicy: {
        enabled: false
        days: 0
      }
    }]
    metrics: [
      {
        category: 'Basic'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

output sqlServerResourceId string = sqlServer.id
output sqlDatabaseResourceId string = sqlDatabase.id
output sqlServerFullyQualifiedDomainName string = sqlServer.properties.fullyQualifiedDomainName
