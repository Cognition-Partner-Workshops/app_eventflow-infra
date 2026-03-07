// EventFlow Demo — Event-driven Azure stack with observability and Devin AI integration
// Supports 10 parallel team deployments, each with their own subdomains

targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Prefix for all resource names (must be lowercase, no spaces)')
param namePrefix string = 'eventflow'

@description('Name of the Service Bus queue for order events')
param serviceBusQueueName string = 'order-events'

@description('Number of team environments to deploy (1-10)')
@minValue(1)
@maxValue(10)
param teamCount int = 10

@description('Deploy the Azure Function App for Devin API trigger (requires Dynamic VM quota)')
param deployFunctionApp bool = false

// ─── Container Registry ─────────────────────────────────────────────────────
module acr 'modules/container-registry.bicep' = {
  name: 'deploy-acr'
  params: {
    location: location
    namePrefix: namePrefix
  }
}

// ─── Service Bus (shared namespace, per-team queues) ────────────────────────
module serviceBus 'modules/service-bus.bicep' = {
  name: 'deploy-servicebus'
  params: {
    location: location
    namePrefix: namePrefix
    queueName: serviceBusQueueName
    teamCount: teamCount
  }
}

// ─── Monitoring (Log Analytics + Application Insights — shared) ─────────────
module monitoring 'modules/monitoring.bicep' = {
  name: 'deploy-monitoring'
  params: {
    location: location
    namePrefix: namePrefix
  }
}

// ─── Container Apps Environment (shared) ────────────────────────────────────
module containerAppsEnv 'modules/container-apps-env.bicep' = {
  name: 'deploy-container-apps-env'
  params: {
    location: location
    namePrefix: namePrefix
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
  }
}

// ─── Per-Team Container Apps (team1 through team10) ─────────────────────────
module teamApps 'modules/team-apps.bicep' = [for i in range(1, teamCount): {
  name: 'deploy-team${i}'
  params: {
    location: location
    teamNumber: i
    environmentId: containerAppsEnv.outputs.environmentId
    acrLoginServer: acr.outputs.loginServer
    acrName: acr.outputs.name
    serviceBusConnectionString: serviceBus.outputs.connectionString
    serviceBusQueueName: '${serviceBusQueueName}-team${i}'
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
  }
}]

// ─── Azure Function (Alert Webhook → Devin API) — optional ─────────────────
module functionApp 'modules/function-app.bicep' = if (deployFunctionApp) {
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
    appInsightsId: monitoring.outputs.appInsightsId
    functionAppUrl: deployFunctionApp ? functionApp.outputs.functionAppUrl : ''
  }
}

// ─── Outputs ─────────────────────────────────────────────────────────────────

@description('Container Registry login server')
output acrLoginServer string = acr.outputs.loginServer

@description('Application Insights connection string')
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString

@description('Log Analytics Workspace name')
output logAnalyticsWorkspaceName string = monitoring.outputs.workspaceName

@description('Service Bus connection string')
output serviceBusConnectionString string = serviceBus.outputs.connectionString

@description('Devin trigger Function App URL')
output devinTriggerUrl string = deployFunctionApp ? functionApp.outputs.functionAppUrl : 'not-deployed'

@description('Team Order Service URLs')
output teamOrderServiceUrls array = [for i in range(1, teamCount): {
  team: 'team${i}'
  url: 'https://${teamApps[i - 1].outputs.orderServiceFqdn}'
}]

@description('Team Payment Service URLs')
output teamPaymentServiceUrls array = [for i in range(1, teamCount): {
  team: 'team${i}'
  url: 'https://${teamApps[i - 1].outputs.paymentServiceFqdn}'
}]
