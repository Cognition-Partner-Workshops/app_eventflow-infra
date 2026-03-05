@description('EventFlow Demo — Event-driven Azure stack with observability and Devin AI integration')

targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Prefix for all resource names (must be lowercase, no spaces)')
param namePrefix string = 'eventflow'

@description('Name of the Service Bus queue for order events')
param serviceBusQueueName string = 'order-events'

// ─── Container Registry ─────────────────────────────────────────────────────
module acr 'modules/container-registry.bicep' = {
  name: 'deploy-acr'
  params: {
    location: location
    namePrefix: namePrefix
  }
}

// ─── Service Bus ─────────────────────────────────────────────────────────────
module serviceBus 'modules/service-bus.bicep' = {
  name: 'deploy-servicebus'
  params: {
    location: location
    namePrefix: namePrefix
    queueName: serviceBusQueueName
  }
}

// ─── Monitoring (Log Analytics + Application Insights) ───────────────────────
module monitoring 'modules/monitoring.bicep' = {
  name: 'deploy-monitoring'
  params: {
    location: location
    namePrefix: namePrefix
  }
}

// ─── Container Apps (Order Service + Payment Service) ────────────────────────
module containerApps 'modules/container-apps.bicep' = {
  name: 'deploy-container-apps'
  params: {
    location: location
    namePrefix: namePrefix
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    acrLoginServer: acr.outputs.loginServer
    acrName: acr.outputs.name
    serviceBusConnectionString: serviceBus.outputs.connectionString
    serviceBusQueueName: serviceBus.outputs.queueName
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
  }
}

// ─── Azure Function (Alert Webhook → Devin API) ─────────────────────────────
module functionApp 'modules/function-app.bicep' = {
  name: 'deploy-function-app'
  params: {
    location: location
    namePrefix: namePrefix
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
  }
}

// ─── Alert Rules ─────────────────────────────────────────────────────────────
module alerts 'modules/alerts.bicep' = {
  name: 'deploy-alerts'
  params: {
    location: location
    namePrefix: namePrefix
    appInsightsId: monitoring.outputs.workspaceId
    functionAppUrl: functionApp.outputs.functionAppUrl
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────

@description('Container Registry login server')
output acrLoginServer string = acr.outputs.loginServer

@description('Order Service URL')
output orderServiceUrl string = 'https://${containerApps.outputs.orderServiceFqdn}'

@description('Payment Service URL')
output paymentServiceUrl string = 'https://${containerApps.outputs.paymentServiceFqdn}'

@description('Application Insights connection string')
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString

@description('Log Analytics Workspace name')
output logAnalyticsWorkspaceName string = monitoring.outputs.workspaceName

@description('Service Bus connection string')
output serviceBusConnectionString string = serviceBus.outputs.connectionString

@description('Devin trigger Function App URL')
output devinTriggerUrl string = functionApp.outputs.functionAppUrl
