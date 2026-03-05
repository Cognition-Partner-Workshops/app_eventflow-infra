@description('Azure Function App — Consumption plan for alert webhook → Devin API trigger')

param location string
param namePrefix string
param appInsightsConnectionString string
param appInsightsInstrumentationKey string

var functionAppName = '${namePrefix}-devin-fn'
var storageName = replace('${namePrefix}fnstore', '-', '')
var hostingPlanName = '${namePrefix}-fn-plan'

// Storage account required by Azure Functions (cheapest tier)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS' // Locally redundant — cheapest option
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// Consumption plan — pay per execution, first 1M free
resource hostingPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true // Linux
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'DEVIN_API_KEY'
          value: '' // Set post-deployment via app settings
        }
        {
          name: 'DEVIN_API_URL'
          value: 'https://api.devin.ai/v1/sessions'
        }
      ]
    }
  }
}

@description('Function App default hostname')
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}/api/alert-webhook'

@description('Function App name')
output functionAppName string = functionApp.name
