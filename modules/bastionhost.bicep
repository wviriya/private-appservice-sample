param name string

@description('The Azure region where the Bastion should be deployed')
param location string = resourceGroup().location

@description('Virtual network name')
param vnetName string

@description('Subnet name')
param subnetName string

var publicIpName = '${name}-pip'


resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  parent: vnet
  name: subnetName
}

resource publicIpAddressForBastion 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2022-01-01' = {
  name: name
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: subnet.id
          }
          publicIPAddress: {
            id: publicIpAddressForBastion.id
          }
        }
      }
    ]
  }
}

output bastionHostName string = bastionHost.name
