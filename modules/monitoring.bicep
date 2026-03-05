@description('Monitoring stack — Log Analytics Workspace + Application Insights')

param location string
param namePrefix string

var workspaceName = '${namePrefix}-logs'
var appInsightsName = '${namePrefix}-appinsights'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018' // Pay-as-you-go, first 5GB/month free
    }
    retentionInDays: 30 // Minimum retention — keeps costs low
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    RetentionInDays: 30
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('Log Analytics Workspace ID')
output workspaceId string = logAnalytics.id

@description('Log Analytics Workspace customer ID (for queries)')
output workspaceCustomerId string = logAnalytics.properties.customerId

@description('Application Insights connection string')
output appInsightsConnectionString string = appInsights.properties.ConnectionString

@description('Application Insights instrumentation key')
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

@description('Log Analytics Workspace name')
output workspaceName string = logAnalytics.name
