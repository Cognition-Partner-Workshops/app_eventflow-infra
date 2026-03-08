@description('Per-team Container Apps deployment (Order Service + Payment Service)')

param location string
param teamNumber int
param environmentId string
param acrLoginServer string
param acrName string
param serviceBusConnectionString string
param serviceBusQueueName string
param appInsightsConnectionString string

var teamSuffix = 'team${teamNumber}'

// Reference to ACR for pulling images
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// Order Service — System 1 (per team)
resource orderService 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'ef-order-${teamSuffix}'
  location: location
  properties: {
    managedEnvironmentId: environmentId
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
            {
              name: 'TEAM_ID'
              value: teamSuffix
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
              timeoutSeconds: 5
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8001
              }
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 10
              initialDelaySeconds: 5
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
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

// Payment Service — System 2 (per team, contains the bug)
resource paymentService 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'ef-payment-${teamSuffix}'
  location: location
  properties: {
    managedEnvironmentId: environmentId
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
            {
              name: 'TEAM_ID'
              value: teamSuffix
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
              timeoutSeconds: 5
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8002
              }
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 10
              initialDelaySeconds: 5
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
      }
    }
  }
}

@description('Order Service FQDN for this team')
output orderServiceFqdn string = orderService.properties.configuration.ingress.fqdn

@description('Payment Service FQDN for this team')
output paymentServiceFqdn string = paymentService.properties.configuration.ingress.fqdn
