targetScope = 'resourceGroup'

@description('Deployment environment code (dev/test/prod).')
param environment string

@description('Azure region for all resources.')
param location string

@description('Standard tag map applied to resources.')
param tags object = {}

@description('Routing Service Bus namespace name.')
param routingServiceBusNamespaceName string

@description('Routing topic name (X12 fan-out).')
param routingTopicName string = 'edi-routing'

@description('Outbound ready topic name.')
param outboundReadyTopicName string = 'edi-outbound-ready'

@description('Routing Service Bus SKU.')
param routingServiceBusSku string = 'Standard'

@description('Azure SQL logical server for control numbers.')
param controlNumberSqlServerName string

@description('Azure SQL database name for control numbers.')
param controlNumberDatabaseName string

@description('Azure SQL SKU.')
param controlNumberSku string = 'GP_S_Gen5_2'

@description('SQL administrator login (provided via pipeline secret).')
param controlNumberAdminLogin string

@secure()
@description('SQL administrator password (secure pipeline secret).')
param controlNumberAdminPassword string

@description('Optional Log Analytics workspace ID for SQL diagnostics.')
param controlNumberLogAnalyticsWorkspaceId string = ''

@description('Global Log Analytics workspace ID for diagnostic wiring (optional).')
param logAnalyticsWorkspaceId string = ''

@description('Enable enterprise scheduler resources.')
param schedulerEnabled bool = true

@description('Scheduler Service Bus namespace name.')
param schedulerNamespaceName string

@description('Scheduler Service Bus SKU.')
param schedulerSku string = 'Standard'

@description('Scheduler dispatch topic name.')
param schedulerDispatchTopicName string

@description('Scheduler dead-letter queue name.')
param schedulerDeadLetterQueueName string

@description('Scheduler completion queue name.')
param schedulerCompleteQueueName string

@description('Scheduler Function App name.')
param schedulerFunctionAppName string

@description('Storage account backing the scheduler Function runtime.')
param schedulerFunctionStorageAccountName string

@description('Consumption plan name for the scheduler Function.')
param schedulerFunctionPlanName string

@description('Optional Application Insights resource name for scheduler telemetry.')
param schedulerAppInsightsName string = ''

@description('Worker runtime for scheduler Function.')
param schedulerWorkerRuntime string = 'dotnet-isolated'

@description('Storage account name for scheduler state table.')
param schedulerStateStorageAccountName string

@description('Scheduler state table name.')
param schedulerStateTableName string

// Routing Service Bus namespace + topics
module routingServiceBus './modules/servicebus.bicep' = {
  name: 'routingServiceBus'
  params: {
    name: routingServiceBusNamespaceName
    location: location
    tags: union(tags, { component: 'routing' })
    routingTopicName: routingTopicName
    outboundReadyTopicName: outboundReadyTopicName
    sku: routingServiceBusSku
  }
}

// Control number Azure SQL database
module controlNumberSql './modules/azure-sql-controlnumbers.bicep' = {
  name: 'controlNumberSql'
  params: {
    location: location
    tags: union(tags, { component: 'control-numbers' })
    sqlServerName: controlNumberSqlServerName
    sqlDatabaseName: controlNumberDatabaseName
    sqlSkuName: controlNumberSku
    administratorLogin: controlNumberAdminLogin
    administratorPassword: controlNumberAdminPassword
    logAnalyticsWorkspaceId: empty(controlNumberLogAnalyticsWorkspaceId) ? logAnalyticsWorkspaceId : controlNumberLogAnalyticsWorkspaceId
  }
}

// Scheduler Service Bus resources
module schedulerServiceBus './modules/scheduler-servicebus.bicep' = {
  name: 'schedulerServiceBus'
  params: {
    schedulerEnabled: schedulerEnabled
    location: location
    namespaceName: schedulerNamespaceName
    skuName: schedulerSku
    dispatchTopicName: schedulerDispatchTopicName
    deadLetterQueueName: schedulerDeadLetterQueueName
    completeQueueName: schedulerCompleteQueueName
    tags: union(tags, { component: 'scheduler' })
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// Scheduler state store (Storage Table)
module schedulerStateStore './modules/scheduler-state-store.bicep' = {
  name: 'schedulerStateStore'
  params: {
    schedulerEnabled: schedulerEnabled
    location: location
    storageAccountName: schedulerStateStorageAccountName
    tableName: schedulerStateTableName
    tags: union(tags, { component: 'scheduler' })
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

// Scheduler Function App
module schedulerFunction './modules/scheduler-function.bicep' = {
  name: 'schedulerFunction'
  params: {
    schedulerEnabled: schedulerEnabled
    location: location
    functionAppName: schedulerFunctionAppName
    storageAccountName: schedulerFunctionStorageAccountName
    hostingPlanName: schedulerFunctionPlanName
    applicationInsightsName: schedulerAppInsightsName
    tags: union(tags, { component: 'scheduler' })
    workerRuntime: schedulerWorkerRuntime
    additionalAppSettings: [
      {
        name: 'SCHEDULER_ENVIRONMENT'
        value: environment
      }
      {
        name: 'SCHEDULER_DISPATCH_TOPIC'
        value: schedulerDispatchTopicName
      }
      {
        name: 'SCHEDULER_DLQ_NAME'
        value: schedulerDeadLetterQueueName
      }
      {
        name: 'SCHEDULER_COMPLETE_QUEUE'
        value: schedulerCompleteQueueName
      }
      {
        name: 'SCHEDULER_STATE_TABLE'
        value: schedulerStateTableName
      }
    ]
  }
}

// Outputs for downstream referencing
output routingServiceBusNamespaceId string = routingServiceBus.outputs.namespaceId
output routingTopicId string = routingServiceBus.outputs.routingTopicId
output controlNumberSqlDatabaseId string = controlNumberSql.outputs.sqlDatabaseResourceId
output schedulerNamespaceId string = schedulerServiceBus.outputs.namespaceId
output schedulerFunctionAppId string = schedulerFunction.outputs.functionAppId
output schedulerStateStorageAccountId string = schedulerStateStore.outputs.storageAccountId
