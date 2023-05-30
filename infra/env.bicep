param nameSuffix string
param location string = resourceGroup().location
param openaiLocation string = 'westeurope'

resource acr 'Microsoft.ContainerRegistry/registries@2022-12-01' = {
  name: 'acr${nameSuffix}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

// Azure OpenAI
resource account 'Microsoft.CognitiveServices/accounts@2022-10-01' = {
  name: 'openai-${nameSuffix}'
  location: openaiLocation
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

// Cosmos DB
resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: 'cosmos${nameSuffix}'
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    databaseAccountOfferType: 'Standard'
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmos
  name: 'dinner-finder'
  properties: {
    resource: {
      id: 'dinner-finder'
    }
  }
}

resource recipesdb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  parent: database
  name: 'recipes'
  properties: {
    resource: {
      id: 'recipes'
      partitionKey: {
        paths: [
          '/partitionKey'
        ]
        kind: 'Hash'
      }
    }
  }
}

// Service Bus
resource sb_ns 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: 'sb${nameSuffix}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }

  resource dinner_meal_requests 'topics' = {
    name: 'dinner-meal-requests'
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

  resource recipe_notifications 'topics' = {
    name: 'recipe-notifications'
    properties: {
      supportOrdering: true
    }

    resource subscription 'subscriptions' = {
      name: 'email-sender'
      properties: {
        deadLetteringOnFilterEvaluationExceptions: true
        deadLetteringOnMessageExpiration: true
        maxDeliveryCount: 10
      }
    }
  }
}

resource sb_keda_key 'Microsoft.ServiceBus/namespaces/authorizationRules@2021-11-01' = {
  name: 'keda-key'
  parent: sb_ns
  properties: {
    rights: [ 'Send', 'Listen', 'Manage' ]
  }
}

// Key Vault 
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv${nameSuffix}'
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

  resource keda_sb_connection_string_secret 'secrets' = {
    name: 'kvs-keda-sb-connection-string'
    properties: {
      value: sb_keda_key.listKeys().primaryConnectionString
    }
  }
  resource open_ai_api_endpoint 'secrets' = {
    name: 'open-ai-api-endpoint'
    properties: {
      value: account.properties.endpoint
    }
  }
  resource open_ai_api_key 'secrets' = {
    name: 'open-ai-api-key'
    properties: {
      value: account.listKeys().key1
    }
  }
  resource open_ai_api_model 'secrets' = {
    name: 'open-ai-api-model'
    properties: {
      value: deployment.properties.model.name
    }
  }
  resource appinsights_connection_string 'secrets' = {
    name: 'appinsights-connection-string'
    properties: {
      value: appinsights.properties.ConnectionString
    }
  }
}

// Managed Identity and Role Assignments
var acrPullRole = resourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
var sbDataReceiverRole = resourceId('Microsoft.Authorization/roleDefinitions', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0')
var sbDataSenderRole = resourceId('Microsoft.Authorization/roleDefinitions', '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39')
var kvSecretUser = resourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

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

resource application_uai_kv_secret_user 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, application_uai.id, kvSecretUser)
  scope: kv
  properties: {
    roleDefinitionId: kvSecretUser
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

resource sqlRoleDefinition 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2023-04-15' = {
  name: guid('sql-rw-role-definition-', application_uai.name, cosmos.id)
  parent: cosmos
  properties: {
    roleName: 'application-uai-rw-role'
    type: 'CustomRole'
    assignableScopes: [
      cosmos.id
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
        ]
      }
    ]
  }
}

resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-04-15' = {
  name: guid(cosmos.id, application_uai.id, sqlRoleDefinition.id)
  parent: cosmos
  properties: {
    roleDefinitionId: sqlRoleDefinition.id
    principalId: application_uai.properties.principalId
    scope: cosmos.id
  }
}

// Dapr components -------------------------
resource pubsub_requests_component 'Microsoft.App/managedEnvironments/daprComponents@2022-10-01' = {
  name: 'requests'
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
    ]
    scopes: [
      'dinner-api', 'ai-processor'
    ]
  }
}

resource pubsub_notifications_component 'Microsoft.App/managedEnvironments/daprComponents@2022-10-01' = {
  name: 'notifications'
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
    ]
    scopes: [
      'ai-processor', 'email-sender'
    ]
  }
}

resource recipe_state_component 'Microsoft.App/managedEnvironments/daprComponents@2022-10-01' = {
  name: 'recipes'
  parent: aca_env
  properties: {
    componentType: 'state.azure.cosmosdb'
    version: 'v1'
    initTimeout: '5m'
    metadata: [
      {
        name: 'azureClientId'
        value: application_uai.properties.clientId
      }
      {
        name: 'url'
        value: cosmos.properties.documentEndpoint
      }
      {
        name: 'database'
        value: database.name
      }
      {
        name: 'collection'
        value: recipesdb.name
      }
      {
        name: 'keyPrefix'
        value: 'none'
      }
    ]
    scopes: [
      'dinner-api', 'ai-processor'
    ]
  }
}
