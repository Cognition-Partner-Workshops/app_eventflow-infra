@description('Azure Container Registry — Basic tier for cost optimization')

param location string
param namePrefix string

var acrName = replace('${namePrefix}acr', '-', '')

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic' // ~$5/month — cheapest tier with 10GB storage
  }
  properties: {
    adminUserEnabled: true // Enables simple auth for Container Apps
    publicNetworkAccess: 'Enabled'
  }
}

@description('The login server URL for the container registry')
output loginServer string = containerRegistry.properties.loginServer

@description('The resource ID of the container registry')
output id string = containerRegistry.id

@description('The name of the container registry')
output name string = containerRegistry.name
