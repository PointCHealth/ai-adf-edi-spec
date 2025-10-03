@description('Service Bus namespace and routing topics')
param name string
param location string
param tags object = {}
param routingTopicName string = 'edi-routing'
param outboundReadyTopicName string = 'edi-outbound-ready'
param sku string = 'Standard'
param enableOutboundReady bool = true
param enablePartitioning bool = true
param supportOrdering bool = true

resource sb 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: name
  location: location
  sku: {
    name: sku
    tier: sku
  }
  properties: {
    disableLocalAuth: true
  }
  tags: tags
}

resource routingTopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  name: routingTopicName
  parent: sb
  properties: {
    enablePartitioning: enablePartitioning
    supportOrdering: supportOrdering
    defaultMessageTimeToLive: 'P7D'
  }
}

resource outboundReadyTopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = if (enableOutboundReady) {
  name: outboundReadyTopicName
  parent: sb
  properties: {
    enablePartitioning: false
    defaultMessageTimeToLive: 'P3D'
  }
}

output routingTopicId string = routingTopic.id
output outboundReadyTopicId string = enableOutboundReady ? outboundReadyTopic.id : ''
output namespaceId string = sb.id
