// ============================================================================
// Application Insights Module
// ============================================================================
// Application monitoring with Log Analytics integration
// ============================================================================

@description('Application Insights name')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Log Analytics Workspace Resource ID')
param workspaceResourceId string

// ============================================================================
// Resources
// ============================================================================

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
    RetentionInDays: 90
    WorkspaceResourceId: workspaceResourceId
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Application Insights Resource ID')
output appInsightsId string = appInsights.id

@description('Application Insights Name')
output appInsightsName string = appInsights.name

@description('Application Insights Instrumentation Key')
output instrumentationKey string = appInsights.properties.InstrumentationKey

@description('Application Insights Connection String')
output connectionString string = appInsights.properties.ConnectionString
