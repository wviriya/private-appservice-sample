param appName string
param serviceId string
param privateDnsZoneName string = 'privatelink.azurewebsites.net'
param vnetName string
param subnetName string
param location string

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZoneName
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: vnet
  name: subnetName
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: '${appName}-pe'
  location: location
  properties: {
    subnet: {
      id: subnet.id
    }
    privateLinkServiceConnections: [
      {
        name: appName
        properties: {
          privateLinkServiceId: serviceId
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = {
  parent: privateEndpoint
  name: appName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneName
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

