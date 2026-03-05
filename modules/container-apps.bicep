@description('Container Apps Environment + Order Service + Payment Service')

param location string
param namePrefix string
param logAnalyticsWorkspaceId string
param acrLoginServer string
param acrName string
param serviceBusConnectionString string
param serviceBusQueueName string
param appInsightsConnectionString string

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

// Reference to ACR for pulling images
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// Order Service — System 1
resource orderService 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'eventflow-order-service'
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8001
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: acr.listCredentials().passwords[0].value
        }
        {
          name: 'servicebus-connection'
          value: serviceBusConnectionString
        }
        {
          name: 'appinsights-connection'
          value: appInsightsConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'order-service'
          image: '${acrLoginServer}/eventflow-order-service:latest'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'AZURE_SERVICEBUS_CONNECTION_STRING'
              secretRef: 'servicebus-connection'
            }
            {
              name: 'AZURE_SERVICEBUS_QUEUE_NAME'
              value: serviceBusQueueName
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              secretRef: 'appinsights-connection'
            }
            {
              name: 'ENVIRONMENT'
              value: 'production'
            }
            {
              name: 'LOG_LEVEL'
              value: 'INFO'
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8001
              }
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/ready'
                port: 8001
              }
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0 // Scale to zero when idle — cost optimization
        maxReplicas: 2
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
}

// Payment Service — System 2
resource paymentService 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'eventflow-payment-service'
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8002
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: acr.listCredentials().passwords[0].value
        }
        {
          name: 'servicebus-connection'
          value: serviceBusConnectionString
        }
        {
          name: 'appinsights-connection'
          value: appInsightsConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'payment-service'
          image: '${acrLoginServer}/eventflow-payment-service:latest'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'AZURE_SERVICEBUS_CONNECTION_STRING'
              secretRef: 'servicebus-connection'
            }
            {
              name: 'AZURE_SERVICEBUS_QUEUE_NAME'
              value: serviceBusQueueName
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              secretRef: 'appinsights-connection'
            }
            {
              name: 'ENVIRONMENT'
              value: 'production'
            }
            {
              name: 'LOG_LEVEL'
              value: 'INFO'
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8002
              }
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/ready'
                port: 8002
              }
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1 // Keep at least 1 replica to consume Service Bus messages
        maxReplicas: 2
        rules: [
          {
            name: 'servicebus-rule'
            custom: {
              type: 'azure-servicebus'
              metadata: {
                queueName: serviceBusQueueName
                messageCount: '5'
              }
              auth: [
                {
                  secretRef: 'servicebus-connection'
                  triggerParameter: 'connection'
                }
              ]
            }
          }
        ]
      }
    }
  }
}

@description('Order Service FQDN')
output orderServiceFqdn string = orderService.properties.configuration.ingress.fqdn

@description('Payment Service FQDN')
output paymentServiceFqdn string = paymentService.properties.configuration.ingress.fqdn

@description('Container Apps Environment ID')
output environmentId string = containerAppsEnvironment.id
