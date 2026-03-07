@description('Alert rules and action group for triggering Devin API on payment failures')

param location string
param namePrefix string
param appInsightsId string
param functionAppUrl string = ''

var actionGroupName = '${namePrefix}-devin-alerts'

// Action group — webhook to Azure Function that triggers Devin API
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  properties: {
    groupShortName: 'DevinAlert'
    enabled: true
    webhookReceivers: functionAppUrl != '' ? [
      {
        name: 'devin-trigger-function'
        serviceUri: functionAppUrl
        useCommonAlertSchema: true
      }
    ] : []
    emailReceivers: [
      {
        name: 'demo-notification'
        emailAddress: 'eventflow-alerts@example.com'
        useCommonAlertSchema: true
      }
    ]
  }
}

// Log-based alert — fires on Payment Service ValueError exceptions
resource paymentCrashAlert 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: '${namePrefix}-payment-crash-log-alert'
  location: location
  properties: {
    description: 'Fires when Payment Service logs ValueError exceptions (currency conversion bug)'
    severity: 1
    enabled: true
    scopes: [
      appInsightsId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    skipQueryValidation: true
    criteria: {
      allOf: [
        {
          query: 'exceptions | where cloud_RoleName contains "ef-payment" | where type == "ValueError" | where outerMessage contains "below minimum threshold"'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 1
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
  }
}

@description('Action group ID')
output actionGroupId string = actionGroup.id

@description('Log alert ID')
output logAlertId string = paymentCrashAlert.id
