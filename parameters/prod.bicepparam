using '../main.bicep'

// Production parameters — higher limits and redundancy
// Not used for demo, included as a reference
param location = 'eastus'
param namePrefix = 'eventflow-prod'
param serviceBusQueueName = 'order-events'
