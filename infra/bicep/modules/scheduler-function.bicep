@description('Deploy scheduler function resources when true.')
param schedulerEnabled bool = true

@description('Azure region for the scheduler function.')
param location string

@description('Function app name.')
param functionAppName string

@description('Storage account name used by the function runtime.')
param storageAccountName string

@description('App Service plan name (consumption plan).')
param hostingPlanName string

@description('Optional Application Insights name. Leave blank to skip creation.')
param applicationInsightsName string = ''

@description('Tags applied to all resources in this module.')
param tags object = {}

@description('Runtime stack for the scheduler function (e.g., dotnet, node, python).')
@allowed([
  'dotnet'
  'dotnet-isolated'
  'node'
  'python'
  'powershell'
])
param workerRuntime string = 'dotnet-isolated'

@description('Optional extra app settings supplied as name/value pairs.')
param additionalAppSettings array = []

resource storage 'Microsoft.Storage/storageAccounts@2023-04-01' = if (schedulerEnabled) {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: true
  }
}

resource plan 'Microsoft.Web/serverfarms@2022-03-01' = if (schedulerEnabled) {
  name: hostingPlanName
  location: location
  kind: 'functionapp'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  tags: tags
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (schedulerEnabled && !empty(applicationInsightsName)) {
  name: applicationInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
  }
}

var baseAppSettings = [
  {
    name: 'FUNCTIONS_EXTENSION_VERSION'
    value: '~4'
  }
  {
    name: 'FUNCTIONS_WORKER_RUNTIME'
    value: workerRuntime
  }
  {
    name: 'WEBSITE_RUN_FROM_PACKAGE'
    value: '1'
  }
]

var aiInstrumentationKeySetting = !empty(applicationInsightsName) ? [
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: appInsights.properties.InstrumentationKey
  }
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsights.properties.ConnectionString
  }
] : []

var combinedAppSettings = arrayConcat(baseAppSettings, aiInstrumentationKeySetting, additionalAppSettings)

var storageKeys = schedulerEnabled ? listKeys(storage.id, '2023-04-01') : null
var storageConnectionString = schedulerEnabled ? format('DefaultEndpointsProtocol=https;AccountName={0};AccountKey={1};EndpointSuffix={2}', storage.name, storageKeys.keys[0].value, environment().suffixes.storage) : ''

resource functionApp 'Microsoft.Web/sites@2022-03-01' = if (schedulerEnabled) {
  name: functionAppName
  location: location
  kind: 'functionapp'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      appSettings: arrayConcat(combinedAppSettings, [
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
      ])
      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
    }
    httpsOnly: true
  }
  dependsOn: [
    storage
  ]
}

resource storageAccountDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (schedulerEnabled && !empty(applicationInsightsName)) {
  name: 'diag-${storageAccountName}'
  scope: storage
  properties: {
    workspaceId: appInsights.id
    logs: []
    metrics: [
      {
        category: 'Transaction'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

output functionAppId string = schedulerEnabled ? functionApp.id : ''
output functionAppPrincipalId string = schedulerEnabled ? functionApp.identity.principalId : ''
output storageAccountId string = schedulerEnabled ? storage.id : ''
output appServicePlanId string = schedulerEnabled ? plan.id : ''
