@description('The name of the private endpoint')
param name string

@description('The location where the private endpoint will be deployed')
param location string

@description('Tags to apply to the private endpoint')
param tags object = {}

@description('The resource ID of the subnet for the private endpoint')
param subnetId string

@description('The resource ID of the resource to create a private endpoint for')
param privateLinkServiceId string

@description('The group ID for the private endpoint')
param groupId string

@description('The resource ID of the private DNS zone')
param privateDnsZoneId string = ''

@description('Enable private DNS zone integration')
param enablePrivateDnsZoneIntegration bool = false

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: name
        properties: {
          privateLinkServiceId: privateLinkServiceId
          groupIds: [
            groupId
          ]
        }
      }
    ]
  }
}

// Private DNS Zone Group (if enabled)
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = if (enablePrivateDnsZoneIntegration && !empty(privateDnsZoneId)) {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

@description('The resource ID of the private endpoint')
output privateEndpointId string = privateEndpoint.id

@description('The name of the private endpoint')
output privateEndpointName string = privateEndpoint.name
