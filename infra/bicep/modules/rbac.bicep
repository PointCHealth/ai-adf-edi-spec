@description('The principal ID to assign the role to')
param principalId string

@description('The resource ID to assign the role on')
param resourceId string

@description('The role definition ID to assign')
param roleDefinitionId string

@description('The type of principal')
@allowed([
  'ServicePrincipal'
  'User'
  'Group'
])
param principalType string = 'ServicePrincipal'

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(principalId, roleDefinitionId, resourceId)
  scope: any(resourceId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: principalType
  }
}

@description('The resource ID of the role assignment')
output roleAssignmentId string = roleAssignment.id

@description('The name of the role assignment')
output roleAssignmentName string = roleAssignment.name
