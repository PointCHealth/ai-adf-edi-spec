@description('The name of the Data Factory')
param name string

@description('The location where the Data Factory will be deployed')
param location string

@description('Tags to apply to the Data Factory')
param tags object = {}

@description('Enable managed virtual network')
param enableManagedVirtualNetwork bool = true

@description('Public network access setting')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Resource ID of the Log Analytics workspace for diagnostics')
param workspaceId string

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess
  }
}

// Managed Virtual Network (if enabled)
resource managedVirtualNetwork 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = if (enableManagedVirtualNetwork) {
  parent: dataFactory
  name: 'default'
  properties: {}
}

// Integration Runtime with Managed VNet
resource integrationRuntime 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = if (enableManagedVirtualNetwork) {
  parent: dataFactory
  name: 'AutoResolveIntegrationRuntime'
  properties: {
    type: 'Managed'
    managedVirtualNetwork: {
      referenceName: 'default'
      type: 'ManagedVirtualNetworkReference'
    }
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
        dataFlowProperties: {
          computeType: 'General'
          coreCount: 8
          timeToLive: 10
        }
      }
    }
  }
  dependsOn: [
    managedVirtualNetwork
  ]
}

// Diagnostic settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: dataFactory
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

@description('The resource ID of the Data Factory')
output dataFactoryId string = dataFactory.id

@description('The name of the Data Factory')
output dataFactoryName string = dataFactory.name

@description('The principal ID of the Data Factory managed identity')
output principalId string = dataFactory.identity.principalId
