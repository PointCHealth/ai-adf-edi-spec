// ============================================================================
// Log Analytics Workspace Module
// ============================================================================
// Centralized logging workspace for all platform resources
// ============================================================================

@description('Log Analytics workspace name')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Log retention in days (30-730)')
@minValue(30)
@maxValue(730)
param retentionInDays int = 90

// ============================================================================
// Resources
// ============================================================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1 // No cap
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Log Analytics Workspace ID')
output workspaceId string = logAnalyticsWorkspace.id

@description('Log Analytics Workspace Name')
output workspaceName string = logAnalyticsWorkspace.name

@description('Log Analytics Workspace Customer ID')
output customerId string = logAnalyticsWorkspace.properties.customerId
