@description('The name of the Function App')
param name string

@description('The location where the Function App will be deployed')
param location string

@description('Tags to apply to the Function App')
param tags object = {}

@description('The resource ID of the App Service Plan')
param appServicePlanId string

@description('The resource ID of the storage account for Function App')
param storageAccountName string

@description('The Application Insights instrumentation key')
param appInsightsInstrumentationKey string

@description('The Application Insights connection string')
param appInsightsConnectionString string

@description('The resource ID of the subnet for VNet integration')
param subnetId string

@description('The runtime stack for the Function App')
@allowed([
  'dotnet-isolated'
  'dotnet'
  'node'
  'python'
  'java'
])
param runtime string = 'dotnet-isolated'

@description('The runtime version')
param runtimeVersion string = '8.0'

@description('App settings for the Function App')
param appSettings object = {}

@description('Enable always on')
param alwaysOn bool = true

@description('Enable HTTPS only')
param httpsOnly bool = true

@description('Minimum TLS version')
@allowed([
  '1.0'
  '1.1'
  '1.2'
  '1.3'
])
param minTlsVersion string = '1.2'

@description('Enable VNet route all')
param vnetRouteAllEnabled bool = true

@description('Enable public network access')
param publicNetworkAccess string = 'Enabled'

@description('Create staging slot')
param createStagingSlot bool = true

resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: name
  location: location
  tags: tags
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: httpsOnly
    publicNetworkAccess: publicNetworkAccess
    virtualNetworkSubnetId: subnetId
    vnetRouteAllEnabled: vnetRouteAllEnabled
    siteConfig: {
      alwaysOn: alwaysOn
      http20Enabled: true
      minTlsVersion: minTlsVersion
      ftpsState: 'Disabled'
      netFrameworkVersion: runtime == 'dotnet-isolated' || runtime == 'dotnet' ? 'v${runtimeVersion}' : null
      use32BitWorkerProcess: false
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
        supportCredentials: false
      }
      appSettings: union([
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), '2023-01-01').keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), '2023-01-01').keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(name)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: runtime == 'dotnet-isolated' ? 'dotnet-isolated' : runtime
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'WEBSITE_CONTENTOVERVNET'
          value: '1'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ], items(appSettings))
    }
  }
}

// Staging slot
resource stagingSlot 'Microsoft.Web/sites/slots@2023-01-01' = if (createStagingSlot) {
  parent: functionApp
  name: 'staging'
  location: location
  tags: tags
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: httpsOnly
    publicNetworkAccess: publicNetworkAccess
    virtualNetworkSubnetId: subnetId
    vnetRouteAllEnabled: vnetRouteAllEnabled
    siteConfig: {
      alwaysOn: alwaysOn
      http20Enabled: true
      minTlsVersion: minTlsVersion
      ftpsState: 'Disabled'
      netFrameworkVersion: runtime == 'dotnet-isolated' || runtime == 'dotnet' ? 'v${runtimeVersion}' : null
      use32BitWorkerProcess: false
      appSettings: union([
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), '2023-01-01').keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(resourceId('Microsoft.Storage/storageAccounts', storageAccountName), '2023-01-01').keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower('${name}-staging')
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: runtime == 'dotnet-isolated' ? 'dotnet-isolated' : runtime
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'WEBSITE_CONTENTOVERVNET'
          value: '1'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ], items(appSettings))
    }
  }
}

@description('The resource ID of the Function App')
output functionAppId string = functionApp.id

@description('The name of the Function App')
output functionAppName string = functionApp.name

@description('The default hostname of the Function App')
output functionAppHostName string = functionApp.properties.defaultHostName

@description('The principal ID of the Function App managed identity')
output principalId string = functionApp.identity.principalId

@description('The principal ID of the staging slot managed identity')
output stagingSlotPrincipalId string = createStagingSlot ? stagingSlot.identity.principalId : ''
