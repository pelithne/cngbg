param nameSuffix string
param location string = resourceGroup().location

resource acr 'Microsoft.ContainerRegistry/registries@2022-12-01' = {
  name: 'acr${nameSuffix}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
  }
}

resource kv 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: 'kv-${nameSuffix}'
  location: location 
  properties: {
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
  }
}

resource account 'Microsoft.CognitiveServices/accounts@2022-10-01' = {
  name: 'openai-${nameSuffix}'
  location: location
  kind: 'OpenAI'
  properties: {
    publicNetworkAccess: 'Enabled'
  }
  sku: {
    name: 'S0'
  }
}

resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2022-10-01' = {
  name: 'gpt-35-turbo'
  parent: account
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-35-turbo'
      version: '0301'
    }
    scaleSettings: {
      scaleType: 'Standard'
    }
  }
}

resource loganalytics_workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'logs-${nameSuffix}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appin-${nameSuffix}'
  kind: 'web'
  location: location
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Redfield'
    Request_Source: 'CustomDeployment'
    WorkspaceResourceId: loganalytics_workspace.id
  }
}

resource aca_env 'Microsoft.App/managedEnvironments@2022-11-01-preview' = {
  name: 'acaenv-${nameSuffix}'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: loganalytics_workspace.properties.customerId
        sharedKey: loganalytics_workspace.listKeys().primarySharedKey
      }
    }
    daprAIConnectionString: appinsights.properties.ConnectionString
    daprAIInstrumentationKey: appinsights.properties.InstrumentationKey
  }
}

var acrPullRole = resourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
var sbDataReceiverRole = resourceId('Microsoft.Authorization/roleDefinitions', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0')
var sbDataSenderRole = resourceId('Microsoft.Authorization/roleDefinitions', '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39')

resource sb_ns 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: 'sb${nameSuffix}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }

  resource topic 'topics' = {
    name: 'dinner-meals-requests'
    properties: {
      supportOrdering: true
    }

    resource subscription 'subscriptions' = {
      name: 'ai-processor'
      properties: {
        deadLetteringOnFilterEvaluationExceptions: true
        deadLetteringOnMessageExpiration: true
        maxDeliveryCount: 10
      }
    }
  }
}

resource application_uai 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'uai-dinner-finder-application'
  location: location
}

resource application_uai_acr_role 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, application_uai.id, acrPullRole)
  scope: acr
  properties: {
    roleDefinitionId: acrPullRole
    principalId: application_uai.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource application_uai_sb_data_receiver_role 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sb_ns.id, application_uai.id, sbDataReceiverRole)
  scope: sb_ns
  properties: {
    roleDefinitionId: sbDataReceiverRole
    principalId: application_uai.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource application_uai_sb_data_sender_role 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sb_ns.id, application_uai.id, sbDataSenderRole)
  scope: sb_ns
  properties: {
    roleDefinitionId: sbDataSenderRole
    principalId: application_uai.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource pubsub_component 'Microsoft.App/managedEnvironments/daprComponents@2022-10-01' = {
  name: 'pubsub'
  parent: aca_env
  properties: {
    componentType: 'pubsub.azure.servicebus.topics'
    version: 'v1'
    initTimeout: '30s'
    metadata: [
      {
        name: 'azureClientId'
        value: application_uai.properties.clientId
      }
      {
        name: 'namespaceName'
        value: '${sb_ns.name}.servicebus.windows.net'
      }
      {
        name: 'maxActiveMessages'
        value: '1'
      }
      {
        name: 'consumerID'
        value: 'ai-processor'
      }
    ]
    scopes: [
      'dinner-api', 'ai-processor'
    ]
  }
}
