@description('The name of the virtual network')
param name string

@description('The location where the virtual network will be deployed')
param location string

@description('Tags to apply to the virtual network')
param tags object = {}

@description('The address space for the virtual network')
param addressPrefix string

@description('The address prefix for the Azure Functions subnet')
param functionSubnetPrefix string

@description('The address prefix for the Private Endpoints subnet')
param privateEndpointSubnetPrefix string

@description('The address prefix for the Azure Data Factory subnet')
param dataFactorySubnetPrefix string

@description('The address prefix for the Application Gateway subnet')
param appGatewaySubnetPrefix string

@description('Enable DDoS protection for the virtual network')
param enableDdosProtection bool = false

@description('Resource ID of the DDoS protection plan')
param ddosProtectionPlanId string = ''

// Network Security Groups
resource functionNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: '${name}-functions-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowVNetOutbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'AllowInternetOutbound'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '443'
            '80'
          ]
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
        }
      }
    ]
  }
}

resource privateEndpointNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: '${name}-pe-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowVNetInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
    ]
  }
}

resource dataFactoryNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: '${name}-adf-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowDataFactoryManagement'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'DataFactoryManagement'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAzureServices'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
        }
      }
    ]
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    enableDdosProtection: enableDdosProtection
    ddosProtectionPlan: enableDdosProtection && !empty(ddosProtectionPlanId) ? {
      id: ddosProtectionPlanId
    } : null
    subnets: [
      {
        name: 'functions-subnet'
        properties: {
          addressPrefix: functionSubnetPrefix
          networkSecurityGroup: {
            id: functionNsg.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                location
              ]
            }
            {
              service: 'Microsoft.KeyVault'
              locations: [
                location
              ]
            }
            {
              service: 'Microsoft.Sql'
              locations: [
                location
              ]
            }
            {
              service: 'Microsoft.ServiceBus'
              locations: [
                location
              ]
            }
          ]
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'private-endpoints-subnet'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          networkSecurityGroup: {
            id: privateEndpointNsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'data-factory-subnet'
        properties: {
          addressPrefix: dataFactorySubnetPrefix
          networkSecurityGroup: {
            id: dataFactoryNsg.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                location
              ]
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'app-gateway-subnet'
        properties: {
          addressPrefix: appGatewaySubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

@description('The resource ID of the virtual network')
output vnetId string = vnet.id

@description('The name of the virtual network')
output vnetName string = vnet.name

@description('The resource ID of the Functions subnet')
output functionSubnetId string = vnet.properties.subnets[0].id

@description('The resource ID of the Private Endpoints subnet')
output privateEndpointSubnetId string = vnet.properties.subnets[1].id

@description('The resource ID of the Data Factory subnet')
output dataFactorySubnetId string = vnet.properties.subnets[2].id

@description('The resource ID of the Application Gateway subnet')
output appGatewaySubnetId string = vnet.properties.subnets[3].id
