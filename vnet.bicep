
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
