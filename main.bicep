param appName string
param hubVnetName string = 'hub-spoke-vnet'
param appVnetName string = 'app-spoke-vnet'
param location string = resourceGroup().location
param vmAdminUsername string
param keyVaultName string
param keyVaultResourceGroupName string

var vmName = 'mgmt-vm'

// create a hub vnet
module hubVnet 'modules/vnet.bicep' = {
  name: hubVnetName
  params: {
    vNetName: hubVnetName
    location: location
    subnets: [
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
  }
}

// create a spoke vnet for application workload
module appVnet 'modules/vnet.bicep' = {
  name: appVnetName
  params: {
    vNetName: appVnetName
    vNetAddressPrefix: '10.0.2.0/24'
    subnets: [
      {
        name: 'PrivateEndpointsSubnet'
        prefix: '10.0.2.0/27'
        delegations: []
      }
      {
        name: 'FEVnetIntegrationSubnet'
        prefix: '10.0.2.32/27'
        delegations: [
          {
            name: 'Microsoft.Web.serverFarms'
            properties: {
              serviceName: 'Microsoft.Web/serverFarms'
            }
          }
        ]
      }
      {
        name: 'BEVnetIntegrationSubnet'
        prefix: '10.0.2.64/27'
        delegations: [
          {
            name: 'Microsoft.Web.serverFarms'
            properties: {
              serviceName: 'Microsoft.Web/serverFarms'
            }
          }
        ]
      }
      {
        name: 'APIManagementSubnet'
        prefix: '10.0.2.96/27'
        delegations: []
      }
    ]
    location: location
  }
}

// peer the hub vnet to the app vnet
resource hubVnetToAppVnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: '${hubVnetName}/${hubVnetName}-to-${appVnetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: appVnet.outputs.vNetId
    }
  }
}

// peer the app vnet to the hub vnet
resource appVnetToHubVnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-07-01' = {
  name: '${appVnetName}/${appVnetName}-to-${hubVnetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hubVnet.outputs.vNetId
    }
  }
}

// create a private dns zone for the app vnet
module privateDNSZone 'modules/privateDNSZone.bicep' = {
  name: 'privateDNSZone'
  params: {
    hubVnetName: hubVnet.outputs.vNetName
    appVnetName: appVnet.outputs.vNetName
  }
}

// create an app service plan for the web app and api app
module web 'modules/appservices.bicep' = {
  name: 'web'
  params: {
    appName: '${appName}-web'
    location: location
    vnetName: appVnet.outputs.vNetName
    integrationSubnet: 'FEVnetIntegrationSubnet'
  }
}

module privateLinkWeb 'modules/privateLink.bicep' = {
  name: 'privateLinkWeb'
  params: {
    appName: web.outputs.name
    serviceId: web.outputs.id
    vnetName: appVnet.outputs.vNetName
    subnetName: 'PrivateEndpointsSubnet'
    location: location
  }
}

module api 'modules/appservices.bicep' = {
  name: 'api'
  params: {
    appName: '${appName}-api'
    location: location
    vnetName: appVnet.outputs.vNetName
    integrationSubnet: 'BEVnetIntegrationSubnet'
    corsOrigins: [
      'http://${web.outputs.hostName}'
      'https://${web.outputs.hostName}'
    ]
  }
}

module privateLinkAPI 'modules/privateLink.bicep' = {
  name: 'privateLinkAPI'
  params: {
    appName: api.outputs.name
    serviceId: api.outputs.id
    vnetName: appVnet.outputs.vNetName
    subnetName: 'PrivateEndpointsSubnet'
    location: location
  }
}

module bastion 'modules/bastionhost.bicep' = {
  name: 'bastion'
  params: {
    name: '${appName}-bastion'
    location: location
    vnetName: hubVnet.outputs.vNetName
    subnetName: 'AzureBastionSubnet'
  }
}

resource kv 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
  scope: resourceGroup(subscription().subscriptionId, keyVaultResourceGroupName )
}

module vm 'modules/vm.bicep' = {
  name: 'vm'
  params: {
    name: vmName
    location: location
    vnetName: hubVnet.outputs.vNetName
    subnetName: 'ManagementSubnet'
    adminUsername: vmAdminUsername
    adminPassword: kv.getSecret('mgmt-vm-password')
    adoPAT: kv.getSecret('ado-pat')
  }
}

