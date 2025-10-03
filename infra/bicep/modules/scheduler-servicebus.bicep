@description('Deploy scheduler Service Bus artifacts when true.')
param schedulerEnabled bool = true

@description('Azure region for Service Bus resources.')
param location string

@description('Name of the Service Bus namespace used for scheduler messaging.')
param namespaceName string

@description('Service Bus SKU (Basic/Standard/Premium).')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Standard'

@description('Dispatch topic name for scheduled jobs.')
param dispatchTopicName string = 'scheduler-dispatch'

@description('Dead-letter queue name for scheduler failures.')
param deadLetterQueueName string = 'scheduler-dlq'

@description('Completion queue name for downstream callbacks.')
param completeQueueName string = 'scheduler-complete'

@description('Tags applied to all resources in this module.')
param tags object = {}

@description('Optional Log Analytics workspace resource ID for diagnostics.')
param logAnalyticsWorkspaceId string = ''

var namespaceSkuCapacity = skuName == 'Premium' ? 1 : 0

resource sbNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = if (schedulerEnabled) {
  name: namespaceName
  location: location
  sku: {
    name: skuName
    tier: skuName
    capacity: namespaceSkuCapacity
  }
  tags: tags
  properties: {
    disableLocalAuth: true
    zoneRedundant: skuName == 'Premium'
  }
}

resource dispatchTopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = if (schedulerEnabled) {
  name: '${namespaceName}/${dispatchTopicName}'
  properties: {
    enablePartitioning: skuName != 'Basic'
    supportOrdering: true
    defaultMessageTimeToLive: 'P1D'
  }
  dependsOn: [ sbNamespace ]
}

resource deadLetterQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = if (schedulerEnabled) {
  name: '${namespaceName}/${deadLetterQueueName}'
  properties: {
    lockDuration: 'PT5M'
    maxDeliveryCount: 10
    defaultMessageTimeToLive: 'P14D'
  }
  dependsOn: [ sbNamespace ]
}

resource completeQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = if (schedulerEnabled) {
  name: '${namespaceName}/${completeQueueName}'
  properties: {
    lockDuration: 'PT1M'
    maxDeliveryCount: 5
    defaultMessageTimeToLive: 'P1D'
  }
  dependsOn: [ sbNamespace ]
}

resource namespaceDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (schedulerEnabled && !empty(logAnalyticsWorkspaceId)) {
  name: 'diag-${namespaceName}'
  scope: sbNamespace
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'OperationalLogs'
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

output namespaceId string = schedulerEnabled ? sbNamespace.id : ''
output dispatchTopicId string = schedulerEnabled ? dispatchTopic.id : ''
output deadLetterQueueId string = schedulerEnabled ? deadLetterQueue.id : ''
output completeQueueId string = schedulerEnabled ? completeQueue.id : ''
