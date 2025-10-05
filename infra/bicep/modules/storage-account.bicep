@description('The name of the storage account')
@maxLength(24)
param name string

@description('The location where the storage account will be deployed')
param location string

@description('Tags to apply to the storage account')
param tags object = {}

@description('The SKU of the storage account')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
])
param sku string = 'Standard_LRS'

@description('The kind of storage account')
@allowed([
  'StorageV2'
  'BlobStorage'
  'BlockBlobStorage'
])
param kind string = 'StorageV2'

@description('Enable hierarchical namespace for ADLS Gen2')
param enableHierarchicalNamespace bool = false

@description('Enable SFTP')
param enableSftp bool = false

@description('Enable blob versioning')
param enableVersioning bool = true

@description('Enable blob soft delete')
param enableBlobSoftDelete bool = true

@description('Blob soft delete retention in days')
@minValue(1)
@maxValue(365)
param blobSoftDeleteRetentionDays int = 7

@description('Enable container soft delete')
param enableContainerSoftDelete bool = true

@description('Container soft delete retention in days')
@minValue(1)
@maxValue(365)
param containerSoftDeleteRetentionDays int = 7

@description('Enable blob change feed')
param enableChangeFeed bool = false

@description('Array of container names to create')
param containerNames array = []

@description('Public network access setting')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Allowed IP addresses for firewall rules')
param allowedIpAddresses array = []

@description('Resource ID of the Log Analytics workspace for diagnostics')
param workspaceId string

@description('Lifecycle management rules')
param lifecycleRules array = []

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: kind
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    publicNetworkAccess: publicNetworkAccess
    isHnsEnabled: enableHierarchicalNamespace
    isSftpEnabled: enableSftp
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: empty(allowedIpAddresses) ? 'Allow' : 'Deny'
      ipRules: [for ip in allowedIpAddresses: {
        value: ip
        action: 'Allow'
      }]
    }
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

// Blob service properties
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: enableBlobSoftDelete
      days: blobSoftDeleteRetentionDays
    }
    containerDeleteRetentionPolicy: {
      enabled: enableContainerSoftDelete
      days: containerSoftDeleteRetentionDays
    }
    changeFeed: {
      enabled: enableChangeFeed
      retentionInDays: enableChangeFeed ? 7 : null
    }
    isVersioningEnabled: enableVersioning
    restorePolicy: {
      enabled: false
    }
  }
}

// Containers
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for containerName in containerNames: {
  parent: blobService
  name: containerName
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}]

// Lifecycle management policy
resource managementPolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = if (!empty(lifecycleRules)) {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: lifecycleRules
    }
  }
}

// Diagnostic settings for storage account
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: storageAccount
  properties: {
    workspaceId: workspaceId
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

// Diagnostic settings for blob service
resource blobDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'blob-diagnostics'
  scope: blobService
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

@description('The resource ID of the storage account')
output storageAccountId string = storageAccount.id

@description('The name of the storage account')
output storageAccountName string = storageAccount.name

@description('The primary blob endpoint of the storage account')
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob

@description('The primary file endpoint of the storage account')
output primaryFileEndpoint string = storageAccount.properties.primaryEndpoints.file
