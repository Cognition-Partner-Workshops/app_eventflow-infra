@description('Azure Service Bus — Basic tier for event-driven messaging with per-team queues')

param location string
param namePrefix string
param queueName string = 'order-events'
param teamCount int = 10

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

// Per-team queues (order-events-team1 through order-events-team10)
resource queues 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = [for i in range(1, teamCount): {
  parent: serviceBusNamespace
  name: '${queueName}-team${i}'
  properties: {
    lockDuration: 'PT1M'
    maxSizeInMegabytes: 1024
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: true
    maxDeliveryCount: 5
  }
}]

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

@description('Base queue name prefix (append -teamN for per-team queues)')
output queueNamePrefix string = queueName
