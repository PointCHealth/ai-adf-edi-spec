@description('The name of the Service Bus namespace')
param name string

@description('The location where the Service Bus will be deployed')
param location string

@description('Tags to apply to the Service Bus')
param tags object = {}

@description('The SKU of the Service Bus')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Standard'

@description('The capacity for Premium SKU (1, 2, 4, 8, or 16 messaging units)')
@allowed([
  1
  2
  4
  8
  16
])
param capacity int = 1

@description('Enable zone redundancy (Premium SKU only)')
param zoneRedundant bool = false

@description('Public network access setting')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Array of queue definitions')
param queues array = []

@description('Array of topic definitions')
param topics array = []

@description('Resource ID of the Log Analytics workspace for diagnostics')
param workspaceId string

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
    tier: sku
    capacity: sku == 'Premium' ? capacity : null
  }
  properties: {
    zoneRedundant: sku == 'Premium' ? zoneRedundant : false
    publicNetworkAccess: publicNetworkAccess
    minimumTlsVersion: '1.2'
    disableLocalAuth: false
  }
}

// Queues
resource serviceBusQueues 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = [for queue in queues: {
  parent: serviceBusNamespace
  name: queue.name
  properties: {
    lockDuration: queue.?lockDuration ?? 'PT1M'
    maxSizeInMegabytes: queue.?maxSizeInMegabytes ?? 1024
    requiresDuplicateDetection: queue.?requiresDuplicateDetection ?? false
    requiresSession: queue.?requiresSession ?? false
    defaultMessageTimeToLive: queue.?defaultMessageTimeToLive ?? 'P14D'
    deadLetteringOnMessageExpiration: queue.?deadLetteringOnMessageExpiration ?? true
    duplicateDetectionHistoryTimeWindow: queue.?duplicateDetectionHistoryTimeWindow ?? 'PT10M'
    maxDeliveryCount: queue.?maxDeliveryCount ?? 10
    enableBatchedOperations: queue.?enableBatchedOperations ?? true
    autoDeleteOnIdle: queue.?autoDeleteOnIdle ?? 'P10675199DT2H48M5.4775807S'
    enablePartitioning: queue.?enablePartitioning ?? false
    enableExpress: queue.?enableExpress ?? false
  }
}]

// Topics
resource serviceBusTopics 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = [for topic in topics: {
  parent: serviceBusNamespace
  name: topic.name
  properties: {
    maxSizeInMegabytes: topic.?maxSizeInMegabytes ?? 1024
    requiresDuplicateDetection: topic.?requiresDuplicateDetection ?? false
    defaultMessageTimeToLive: topic.?defaultMessageTimeToLive ?? 'P14D'
    duplicateDetectionHistoryTimeWindow: topic.?duplicateDetectionHistoryTimeWindow ?? 'PT10M'
    enableBatchedOperations: topic.?enableBatchedOperations ?? true
    autoDeleteOnIdle: topic.?autoDeleteOnIdle ?? 'P10675199DT2H48M5.4775807S'
    enablePartitioning: topic.?enablePartitioning ?? false
    enableExpress: topic.?enableExpress ?? false
    supportOrdering: topic.?supportOrdering ?? true
  }
}]

// Topic Subscriptions
resource serviceBusSubscriptions 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = [for topic in topics: if (contains(topic, 'subscriptions')) {
  parent: serviceBusTopics[indexOf(topics, topic)]
  name: topic.subscriptions[0].name
  properties: {
    lockDuration: topic.subscriptions[0].?lockDuration ?? 'PT1M'
    requiresSession: topic.subscriptions[0].?requiresSession ?? false
    defaultMessageTimeToLive: topic.subscriptions[0].?defaultMessageTimeToLive ?? 'P14D'
    deadLetteringOnMessageExpiration: topic.subscriptions[0].?deadLetteringOnMessageExpiration ?? true
    maxDeliveryCount: topic.subscriptions[0].?maxDeliveryCount ?? 10
    enableBatchedOperations: topic.subscriptions[0].?enableBatchedOperations ?? true
    autoDeleteOnIdle: topic.subscriptions[0].?autoDeleteOnIdle ?? 'P10675199DT2H48M5.4775807S'
  }
}]

// Additional subscriptions (if more than one)
resource additionalSubscriptions 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = [for topic in topics: if (contains(topic, 'subscriptions') && length(topic.subscriptions) > 1) {
  parent: serviceBusTopics[indexOf(topics, topic)]
  name: topic.subscriptions[1].name
  properties: {
    lockDuration: topic.subscriptions[1].?lockDuration ?? 'PT1M'
    requiresSession: topic.subscriptions[1].?requiresSession ?? false
    defaultMessageTimeToLive: topic.subscriptions[1].?defaultMessageTimeToLive ?? 'P14D'
    deadLetteringOnMessageExpiration: topic.subscriptions[1].?deadLetteringOnMessageExpiration ?? true
    maxDeliveryCount: topic.subscriptions[1].?maxDeliveryCount ?? 10
    enableBatchedOperations: topic.subscriptions[1].?enableBatchedOperations ?? true
    autoDeleteOnIdle: topic.subscriptions[1].?autoDeleteOnIdle ?? 'P10675199DT2H48M5.4775807S'
  }
}]

// Diagnostic settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: serviceBusNamespace
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

@description('The resource ID of the Service Bus namespace')
output serviceBusId string = serviceBusNamespace.id

@description('The name of the Service Bus namespace')
output serviceBusName string = serviceBusNamespace.name

@description('The endpoint of the Service Bus namespace')
output serviceBusEndpoint string = serviceBusNamespace.properties.serviceBusEndpoint
