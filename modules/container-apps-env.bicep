@description('Shared Container Apps Environment — Consumption plan (serverless)')

param location string
param namePrefix string
param logAnalyticsWorkspaceId string

var environmentName = '${namePrefix}-cae'

// Container Apps Environment — Consumption plan (serverless, pay-per-request)
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2022-10-01').customerId
        sharedKey: listKeys(logAnalyticsWorkspaceId, '2022-10-01').primarySharedKey
      }
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

@description('Container Apps Environment ID')
output environmentId string = containerAppsEnvironment.id
