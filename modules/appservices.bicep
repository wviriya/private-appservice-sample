param appName string
param location string = resourceGroup().location

@allowed([
  'F1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1V3'
  'P2V3'
  'P3V3'
])
param appServicePlanSize string = 'S1'
param appServiceInstance int = 1
param vnetName string
param integrationSubnet string
param corsOrigins array = ['*']

var planName = '${appName}-plan'
var appServicePlanFamily = substring(appServicePlanSize, 0, 1)
var appServicePlanTier = appServicePlanFamily == 'B' ? 'Basic' : appServicePlanFamily == 'S' ? 'Standard' : appServicePlanFamily == 'P' ? 'Premium' : 'Free'

resource vNet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: vnetName
}
 
resource _integrationSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  parent: vNet
  name: integrationSubnet
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: planName
  location: location
  sku: {
    name: appServicePlanSize
    tier: appServicePlanTier
    size: appServicePlanSize
    family: appServicePlanFamily
    capacity: appServiceInstance
  }
  kind: 'app'
}

resource app 'Microsoft.Web/sites@2022-03-01' = {
  name: appName
  location: location
  kind: 'app'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      netFrameworkVersion: 'v7.0'
      cors: {
        allowedOrigins: corsOrigins
      }
      http20Enabled: true
    }
    httpsOnly: true
    virtualNetworkSubnetId: _integrationSubnet.id
  }
  identity: {
    type: 'SystemAssigned'
  }
}

output name string = app.name
output id string = app.id
output hostName string = app.properties.defaultHostName

