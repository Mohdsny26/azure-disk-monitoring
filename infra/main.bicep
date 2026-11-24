// Central monitoring resources. Deploy ONCE into the central subscription / resource group.
//   az group create -n rg-disk-monitoring -l centralindia
//   az deployment group create -g rg-disk-monitoring -f infra/main.bicep -p alertEmail=team@example.com
targetScope = 'resourceGroup'

param location string = resourceGroup().location
param workspaceName string = 'law-disk-monitoring'
param alertEmail string
param retentionDays int = 30
param warningThreshold int = 80
param criticalThreshold int = 90

// 1. One Log Analytics workspace that receives disk data from ALL subscriptions
resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: retentionDays
  }
}

// 2. Data Collection Rule: what Azure Monitor Agent collects from the Linux VMs
resource dcr 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcr-disk-monitoring-linux'
  location: location
  kind: 'Linux'
  properties: {
    dataSources: {
      performanceCounters: [
        {
          name: 'diskCounters'
          streams: [ 'Microsoft-Perf' ]
          samplingFrequencyInSeconds: 300
          counterSpecifiers: [
            'Logical Disk(*)\\% Used Space'
            'Logical Disk(*)\\% Used Inodes'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        { name: 'central-law', workspaceResourceId: law.id }
      ]
    }
    dataFlows: [
      { streams: [ 'Microsoft-Perf' ], destinations: [ 'central-law' ] }
    ]
  }
}

// 3. Who gets the alert (email here; can be Teams / webhook / ITSM too)
resource ag 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-disk-alerts'
  location: 'global'
  properties: {
    groupShortName: 'diskalert'
    enabled: true
    emailReceivers: [
      { name: 'ops-team', emailAddress: alertEmail, useCommonAlertSchema: true }
    ]
  }
}

// 4. Alert rules. ONE rule watches ALL VMs in ALL subscriptions (they all write to this workspace).
var levels = [
  { name: 'warning',  severity: 2, min: warningThreshold,  max: criticalThreshold }
  { name: 'critical', severity: 1, min: criticalThreshold, max: 101 }
]

resource diskRules 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = [for l in levels: {
  name: 'disk-used-${l.name}'
  location: location
  properties: {
    displayName: 'Disk usage ${l.name} (>= ${l.min}%)'
    description: 'A disk is ${l.min}% or more full'
    severity: l.severity
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    scopes: [ law.id ]
    autoMitigate: true
    criteria: {
      allOf: [
        {
          query: 'Perf | where ObjectName == "Logical Disk" and CounterName == "% Used Space" | where InstanceName != "_Total" | summarize UsedPct = max(CounterValue) by Computer, InstanceName | where UsedPct >= ${l.min} and UsedPct < ${l.max}'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          dimensions: [
            { name: 'Computer', operator: 'Include', values: [ '*' ] }
            { name: 'InstanceName', operator: 'Include', values: [ '*' ] }
          ]
          failingPeriods: { numberOfEvaluationPeriods: 1, minFailingPeriodsToAlert: 1 }
        }
      ]
    }
    actions: { actionGroups: [ ag.id ] }
  }
}]

// 5. Alert when a VM stops sending data (agent broken = we are blind)
resource silentRule 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: 'disk-agent-silent'
  location: location
  properties: {
    displayName: 'VM stopped reporting (agent problem)'
    severity: 2
    enabled: true
    evaluationFrequency: 'PT15M'
    windowSize: 'PT1H'
    scopes: [ law.id ]
    autoMitigate: true
    criteria: {
      allOf: [
        {
          query: 'Heartbeat | summarize LastSeen = max(TimeGenerated) by Computer | where LastSeen < ago(20m)'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: { numberOfEvaluationPeriods: 1, minFailingPeriodsToAlert: 1 }
        }
      ]
    }
    actions: { actionGroups: [ ag.id ] }
  }
}

output workspaceId string = law.id
output dcrId string = dcr.id
output actionGroupId string = ag.id
