@description('Outbound Orchestrator Function (timer / queue / durable)')
param name string
param location string
param storageAccountName string
param tags object = {}
param enableDurable bool = true

resource plan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${name}-plan'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  tags: tags
}

resource app 'Microsoft.Web/sites@2022-09-01' = {
  name: name
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};'
        }
        {
          name: 'ENABLE_DURABLE'
          value: string(enableDurable)
        }
      ]
    }
  }
  tags: tags
}

output functionAppName string = app.name
