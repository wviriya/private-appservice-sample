param name string = 'privatelink.azurewebsites.net'
param hubVnetName string
param appVnetName string

resource appVnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: appVnetName
}

resource hubVnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: hubVnetName
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: name
  location: 'global'
}

resource hubVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${privateDnsZone.name}-${hubVnet.name}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVnet.id
    }
  }
}

resource appVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${privateDnsZone.name}-${appVnet.name}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: appVnet.id
    }
  }
}

