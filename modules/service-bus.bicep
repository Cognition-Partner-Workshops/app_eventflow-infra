@description('Azure Service Bus — Basic tier for event-driven messaging')

param location string
param namePrefix string
param queueName string = 'order-events'

var namespaceName = '${namePrefix}-sbns'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: namespaceName
  location: location
  sku: {
    name: 'Basic' // ~$0.05/million operations — cheapest tier
    tier: 'Basic'
  }
  properties: {}
}

resource queue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: queueName
  properties: {
    lockDuration: 'PT1M'
    maxSizeInMegabytes: 1024
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: true
    maxDeliveryCount: 5
  }
}

// Shared access policy for the services
resource sendListenPolicy 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'SendListenPolicy'
  properties: {
    rights: [
      'Send'
      'Listen'
    ]
  }
}

@description('Connection string with Send and Listen rights')
output connectionString string = listKeys(sendListenPolicy.id, sendListenPolicy.apiVersion).primaryConnectionString

@description('The namespace name')
output namespaceName string = serviceBusNamespace.name

@description('The queue name')
output queueName string = queue.name
