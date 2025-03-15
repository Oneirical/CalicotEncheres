
// Définir les paramètres
param codeIdentification string
param location string = 'Canada Central'

// Variables pour les noms des ressources
var vnetName = 'vnet-dev-calicot-cc-${codeIdentification}'
var webSubnetName = 'snet-dev-web-cc-${codeIdentification}'
var dbSubnetName = 'snet-dev-db-cc-${codeIdentification}'

// Créer le réseau virtuel (VNet)
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: webSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: webNsg.id
          }
        }
      }
      {
        name: dbSubnetName
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: {
            id: dbNsg.id
          }
        }
      }
    ]
  }
}

// Créer un groupe de sécurité réseau (NSG) pour le sous-réseau web
resource webNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: 'nsg-dev-web-cc-${codeIdentification}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'Allow-HTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Créer un groupe de sécurité réseau (NSG) pour le sous-réseau de la base de données
resource dbNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: 'nsg-dev-db-cc-${codeIdentification}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Deny-All-Inbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Créer un plan App Service
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'plan-calicot-dev-${codeIdentification}'
  location: location
  sku: {
    name: 'S1'
    tier: 'Standard'
    size: 'S1'
    family: 'S'
    capacity: 1
  }
  properties: {
    reserved: true // Pour Linux, mettre à true
  }
}

// Créer une application web
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: 'app-calicot-dev-${codeIdentification}'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      alwaysOn: true
      http20Enabled: true
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'ImageUrl'
          value: 'https://stcalicotprod000.blob.core.windows.net/images/'
        }
      ]
      connectionStrings: [
        {
          name: 'ConnectionStrings'
          connectionString: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/ConnectionStrings/)'
          type: 'SQLAzure'
        }
      ]
    }
    httpsOnly: true
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Intégration au réseau virtuel (VNet Integration)
resource vnetIntegration 'Microsoft.Web/sites/virtualNetworkConnections@2023-01-01' = {
  name: '${webApp.name}/integration'
  properties: {
    vnetResourceId: vnet.id
    subnetName: webSubnetName
  }
}

// Créer un serveur SQL
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: 'sqlsrv-calicot-dev-${codeIdentification}'
  location: location
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'P@ssw0rd123!' // Remplacez par un mot de passe sécurisé
  }
}

// Créer une base de données SQL
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  name: 'sqldb-calicot-dev-${codeIdentification}'
  parent: sqlServer
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    maxSizeBytes: 2147483648 // 2 Go
  }
}

// Configurer un point de terminaison de service pour la base de données
resource sqlSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {
  name: dbSubnetName
  parent: vnet
  properties: {
    addressPrefix: '10.0.2.0/24'
    serviceEndpoints: [
      {
        service: 'Microsoft.Sql'
      }
    ]
  }
}

// Variables
var keyVaultName = 'kv-calicot-dev-${codeIdentification}'

// Créer un Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      name: 'Standard'
      family: 'A'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
  }
}

// Configurer une politique d'accès pour l'identité managée
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  name: '${keyVaultName}/add'
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: webApp.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}
