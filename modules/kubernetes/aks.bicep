// module kubernetes
param dnsPrefix string
param clusterName string
param location string
param agentCount int 
param agentVMSize string
param tagEnvironmentNameAks string
param tagCostCenterAks string
param vnetSubnetId string

resource aks 'Microsoft.ContainerService/managedClusters@2020-09-01' = {
  name: clusterName
  location: location
  tags: {
    Environment: tagEnvironmentNameAks
    tagCostCenter: tagCostCenterAks
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enableRBAC: true
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: 'pool01'
        count: agentCount
        mode: 'System'
        vmSize: agentVMSize
        type: 'VirtualMachineScaleSets'
        osType: 'Linux'
        enableAutoScaling: false
        vnetSubnetID: vnetSubnetId
      }
    ]
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    networkProfile: {
      networkPlugin: 'azure'
      loadBalancerSku: 'standard'
    }
  }
}

output id string = aks.id
output apiServerAddress string = aks.properties.fqdn
output name string = aks.name