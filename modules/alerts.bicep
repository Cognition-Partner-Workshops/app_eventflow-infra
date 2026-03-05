@description('Alert rules and action group for triggering Devin API on payment failures')

param location string
param namePrefix string
param appInsightsId string
param functionAppUrl string = ''

var actionGroupName = '${namePrefix}-devin-alerts'
var alertRuleName = '${namePrefix}-payment-error-spike'

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

// Metric alert — fires when Payment Service error rate spikes
resource paymentErrorAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertRuleName
  location: 'global'
  properties: {
    description: 'Fires when the Payment Service error rate exceeds threshold, triggering Devin API investigation'
    severity: 1
    enabled: true
    scopes: [
      appInsightsId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'payment-errors'
          metricName: 'exceptions/count'
          metricNamespace: 'microsoft.insights/components'
          operator: 'GreaterThan'
          threshold: 3
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// Log-based alert — fires on specific Payment Service ValueError exceptions
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
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: '''
            exceptions
            | where cloud_RoleName == "eventflow-payment-service"
            | where type == "ValueError"
            | where outerMessage contains "below minimum threshold"
            | summarize count() by bin(timestamp, 1m)
          '''
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

@description('Metric alert ID')
output metricAlertId string = paymentErrorAlert.id
