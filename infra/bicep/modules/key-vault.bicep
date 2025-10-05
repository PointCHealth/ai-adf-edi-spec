@description('The name of the Key Vault')
param name string

@description('The location where the Key Vault will be deployed')
param location string

@description('Tags to apply to the Key Vault')
param tags object = {}

@description('The SKU of the Key Vault')
@allowed([
  'standard'
  'premium'
])
param sku string = 'standard'

@description('Enable soft delete for the Key Vault')
param enableSoftDelete bool = true

@description('Soft delete retention in days')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Enable purge protection for the Key Vault')
param enablePurgeProtection bool = true

@description('Enable RBAC authorization for the Key Vault')
param enableRbacAuthorization bool = true

@description('Allowed IP addresses for firewall rules')
param allowedIpAddresses array = []

@description('The tenant ID for the Key Vault')
param tenantId string = tenant().tenantId

@description('Enable public network access')
param publicNetworkAccess string = 'Enabled'

@description('Resource ID of the Log Analytics workspace for diagnostics')
param workspaceId string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: sku
    }
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection ? true : null
    enableRbacAuthorization: enableRbacAuthorization
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: empty(allowedIpAddresses) ? 'Allow' : 'Deny'
      ipRules: [for ip in allowedIpAddresses: {
        value: ip
      }]
    }
    accessPolicies: []
  }
}

// Diagnostic settings
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: keyVault
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

@description('The resource ID of the Key Vault')
output keyVaultId string = keyVault.id

@description('The name of the Key Vault')
output keyVaultName string = keyVault.name

@description('The URI of the Key Vault')
output keyVaultUri string = keyVault.properties.vaultUri
