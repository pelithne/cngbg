param nameSuffix string
param location string = resourceGroup().location

// Reference existing resources
resource acr 'Microsoft.ContainerRegistry/registries@2022-12-01' existing = {
  name: 'acr${nameSuffix}'
}
resource aca_env 'Microsoft.App/managedEnvironments@2022-11-01-preview' existing = {
  name: 'acaenv-${nameSuffix}'
}
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: 'kv${nameSuffix}'
}
resource application_uai 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: 'uai-dinner-finder-application'
}

resource email_services 'Microsoft.Communication/emailServices@2023-03-31' = {
  name: 'email-${nameSuffix}'
  location: 'global'
  properties: {
    dataLocation: 'europe'
  }
}

resource azure_test_domain 'Microsoft.Communication/emailServices/domains@2023-03-31' = {
  name: 'AzureManagedDomain'
  parent: email_services
  location: 'global'
  properties: {
    domainManagement: 'AzureManaged'
    userEngagementTracking: 'Disabled'
  }
}

resource communication_services 'Microsoft.Communication/communicationServices@2023-03-31' = {
  name: 'com-${nameSuffix}'
  location: 'global'
  properties: {
    dataLocation: 'europe'
    linkedDomains: [
      azure_test_domain.id
    ]
  }
}

resource kv_sender_mail 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: 'sender-mail'
  parent: kv
  properties: {
    value: 'DoNotReply@${azure_test_domain.properties.mailFromSenderDomain}'
  }
}
resource kv_communication_connection_string 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: 'com-connection-string'
  parent: kv
  properties: {
    value: communication_services.listKeys().primaryConnectionString
  }
}

// Email sender
resource email_sender 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'email-sender'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${application_uai.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: aca_env.id
    configuration: {
      activeRevisionsMode: 'single'
      dapr: {
        appId: 'email-sender'
        appPort: 80
        enabled: true
      }
      secrets: [
        {
          name: 'sb-connection-string'
          // using the vault name in the url is a workaround for a bug in the container apps resource provider
          keyVaultUrl: 'https://${kv.name}.vault.azure.net/secrets/kvs-keda-sb-connection-string'
          identity: application_uai.id
        }
        {
          name: 'com-sender-mail'
          // using the vault name in the url is a workaround for a bug in the container apps resource provider
          keyVaultUrl: 'https://${kv.name}.vault.azure.net/secrets/sender-mail'
          identity: application_uai.id
        }
        {
          name: 'com-connection-string'
          // using the vault name in the url is a workaround for a bug in the container apps resource provider
          keyVaultUrl: 'https://${kv.name}.vault.azure.net/secrets/com-connection-string'
          identity: application_uai.id
        }
      ]
      registries: [
        {
          identity: application_uai.id
          server: acr.properties.loginServer
        }
      ]
    }
    template: {
      containers: [
        {
          image: '${acr.name}.azurecr.io/dinner/email-sender:0.1'
          name: 'email-sender'
          resources:{
            cpu: json('.25')
            memory: '.5Gi'
          }
          env: [
            {
              name: 'AZURE_COMMUNICATION_ENDPOINT'
              secretRef: 'com-connection-string'
            }
            {
              name: 'AZURE_COMMUNICATION_FROM_ADDRESS'
              secretRef: 'com-sender-mail'
            }
            {
              name: 'USE_CONSOLE_LOG_OUTPUT'
              value: 'true'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
        rules: [
          {
            name: 'sb-scale-rule'
            custom: {
              type: 'azure-servicebus'
              auth: [
                {
                  secretRef: 'sb-connection-string'
                  triggerParameter: 'connection'
                }
              ]
              metadata: {
                topicName: 'notifications'
                subscriptionName: 'email-sender'
                queueLength: '1'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    kv_sender_mail
    kv_communication_connection_string
  ]
}
