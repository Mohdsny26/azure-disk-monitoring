// Auto-enrollment. Deploy at the MANAGEMENT GROUP, so every current and future subscription is covered.
//   az deployment mg create -m <mg-id> -l centralindia -f infra/policy.bicep -p dcrId=<dcr resource id>
// Uses two Microsoft built-in policies. IDs, parameter names and required roles were
// verified against github.com/Azure/azure-policy (built-in-policies/Monitoring).
targetScope = 'managementGroup'

param dcrId string
param location string = 'centralindia'

// Built-in: "Configure Linux virtual machines to run Azure Monitor Agent with system-assigned managed identity"
var amaPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/a4034bc6-ae50-406d-bf76-50f4ee5a7811'
// Built-in: "Configure Linux Machines to be associated with a Data Collection Rule or a Data Collection Endpoint"
var dcrPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/2ea82cdd-f2e8-4500-af75-67a2e084ca74'

// Roles required by each built-in policy (checked against Microsoft's azure-policy repo)
var vmContributor = '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'          // Virtual Machine Contributor
var monitoringContributor = '749f88d5-cbae-40b8-bcfc-e573ddc772fa'  // Monitoring Contributor
var logAnalyticsContributor = '92aaf0da-9dab-42b6-94a3-d43ce8d16293' // Log Analytics Contributor

resource amaAssign 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'diskmon-ama'
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName: 'Disk monitoring - install Azure Monitor Agent on Linux VMs'
    policyDefinitionId: amaPolicyId
    enforcementMode: 'Default'
  }
}

resource dcrAssign 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'diskmon-dcr'
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName: 'Disk monitoring - associate Linux VMs with the disk DCR'
    policyDefinitionId: dcrPolicyId
    enforcementMode: 'Default'
    parameters: {
      dcrResourceId: { value: dcrId }
      resourceType: { value: 'Microsoft.Insights/dataCollectionRules' }
    }
  }
}

// The policy identities need rights to install the extension and create associations.
// Agent policy -> Virtual Machine Contributor
resource amaVm 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(amaAssign.id, vmContributor)
  properties: {
    principalId: amaAssign.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', vmContributor)
  }
}
// DCR association policy -> Monitoring Contributor + Log Analytics Contributor
resource dcrMon 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(dcrAssign.id, monitoringContributor)
  properties: {
    principalId: dcrAssign.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', monitoringContributor)
  }
}
resource dcrLaw 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(dcrAssign.id, logAnalyticsContributor)
  properties: {
    principalId: dcrAssign.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: tenantResourceId('Microsoft.Authorization/roleDefinitions', logAnalyticsContributor)
  }
}
