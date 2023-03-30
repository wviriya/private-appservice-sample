param vNetName string = 'Hub-Vnet'
param vNetAddressPrefix string = '10.0.0.0/23'
param subnets array = [
  {
    name: 'GatewaySubnet'
    prefix: '10.0.0.0/28'
    delegations: []
  }
  {
    name: 'AzureFirewallSubnet'
    prefix: '10.0.1.0/26'
    delegations: []
  }
  {
    name: 'AzureBastionSubnet'
    prefix: '10.0.0.32/27'
    delegations: []
  }
  {
    name: 'PrivateEndpointsSubnet'
    prefix: '10.0.0.128/25'
    delegations: []
  }
  {
    name: 'ManagementSubnet'
    prefix: '10.0.1.128/25'
    delegations: []
  }
]
param location string = resourceGroup().location

resource vNet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vNetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNetAddressPrefix
      ]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.prefix
        delegations: subnet.delegations
      }
    }]
  }
}

output vNetName string = vNet.name
output vNetId string = vNet.id
