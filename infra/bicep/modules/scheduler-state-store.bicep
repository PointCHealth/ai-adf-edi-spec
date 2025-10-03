@description('Deploy scheduler state store when true.')
param schedulerEnabled bool = true

@description('Azure region for the state store.')
param location string

@description('Storage account name used to host scheduler metadata.')
param storageAccountName string

@description('Table name for scheduler state tracking.')
param tableName string = 'SchedulerState'

@description('Tags applied to all resources in this module.')
param tags object = {}

@description('Optional Log Analytics workspace resource ID for diagnostics.')
param logAnalyticsWorkspaceId string = ''

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
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource tableResource 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-04-01' = if (schedulerEnabled) {
  name: '${storage.name}/default/${tableName}'
  properties: {}
  dependsOn: [ storage ]
}

resource storageDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (schedulerEnabled && !empty(logAnalyticsWorkspaceId)) {
  name: 'diag-${storageAccountName}'
  scope: storage
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
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

output storageAccountId string = schedulerEnabled ? storage.id : ''
output tableResourceId string = schedulerEnabled ? tableResource.id : ''
