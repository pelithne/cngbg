param nameSuffix string
param location string = resourceGroup().location
param useOtelCollectorMonitoring bool = false

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
resource application_uai 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: 'uai-dinner-finder-application'
}

// Dinner Api
resource dinner_api 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'dinner-api'
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
      ingress: {
        external: true
        targetPort: 80
      }
      dapr: {
        appId: 'dinner-api'
        appPort: 80
        enabled: true
      }
      secrets: [
        {
          name: 'appinsights-connection-string'
          // using the vault name in the url is a workaround for a bug in the container apps resource provider
          keyVaultUrl: 'https://${kv.name}.vault.azure.net/secrets/appinsights-connection-string'
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
          image: '${acr.name}.azurecr.io/dinner/api:0.1'
          name: 'dinner-api'
          resources:{
            cpu: json('.25')
            memory: '.5Gi'
          }
          env: [
            {
              name: 'USE_CONSOLE_LOG_OUTPUT'
              value: 'true'
            }
            {
              name: 'OTEL_EXPORTER_OTLP_ENDPOINT'
              value: useOtelCollectorMonitoring == true ? 'http://otel-collector-app' : ''
            }
            {
              name: 'OTEL_EXPORTER_OTLP_PROTOCOL'
              value: 'http/protobuf'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              secretRef: 'appinsights-connection-string'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
        rules: [
          {
            name: 'http-scale-rule'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

// Ai processor
resource ai_processor 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'ai-processor'
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
        appId: 'ai-processor'
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
          name: 'open-ai-api-endpoint'
          // using the vault name in the url is a workaround for a bug in the container apps resource provider
          keyVaultUrl: 'https://${kv.name}.vault.azure.net/secrets/open-ai-api-endpoint'
          identity: application_uai.id
        }
        {
          name: 'open-ai-api-key'
          // using the vault name in the url is a workaround for a bug in the container apps resource provider
          keyVaultUrl: 'https://${kv.name}.vault.azure.net/secrets/open-ai-api-key'
          identity: application_uai.id
        }
        {
          name: 'open-ai-api-model'
          // using the vault name in the url is a workaround for a bug in the container apps resource provider
          keyVaultUrl: 'https://${kv.name}.vault.azure.net/secrets/open-ai-api-model'
          identity: application_uai.id
        }
        {
          name: 'appinsights-connection-string'
          // using the vault name in the url is a workaround for a bug in the container apps resource provider
          keyVaultUrl: 'https://${kv.name}.vault.azure.net/secrets/appinsights-connection-string'
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
          image: '${acr.name}.azurecr.io/dinner/ai-processor:0.1'
          name: 'ai-processor'
          resources:{
            cpu: json('.25')
            memory: '.5Gi'
          }
          env: [
            {
              name: 'AZURE_OPENAI_API_ENDPOINT'
              secretRef: 'open-ai-api-endpoint'
            }
            {
              name: 'AZURE_OPENAI_API_KEY'
              secretRef: 'open-ai-api-key'
            }
            {
              name: 'AZURE_OPENAI_API_MODEL'
              secretRef: 'open-ai-api-model'
            }
            {
              name: 'USE_CONSOLE_LOG_OUTPUT'
              value: 'true'
            }
            {
              name: 'OTEL_EXPORTER_OTLP_ENDPOINT'
              value: useOtelCollectorMonitoring == true ? 'http://otel-collector-app' : ''
            }
            {
              name: 'OTEL_EXPORTER_OTLP_PROTOCOL'
              value: 'http/protobuf'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              secretRef: 'appinsights-connection-string'
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
                topicName: 'dinner-meal-requests'
                subscriptionName: 'ai-processor'
                queueLength: '1'
              }
            }
          }
        ]
      }
    }
  }
}

// Web frontend
resource web_frontend 'Microsoft.App/containerApps@2022-11-01-preview' = {
  name: 'web-frontend'
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
      ingress: {
        external: true
        targetPort: 80
        stickySessions: {
          affinity: 'sticky'
        }
      }
      dapr: {
        appId: 'web-frontend'
        appPort: 80
        enabled: true
      }
      secrets: [
        {
          name: 'appinsights-connection-string'
          // using the vault name in the url is a workaround for a bug in the container apps resource provider
          keyVaultUrl: 'https://${kv.name}.vault.azure.net/secrets/appinsights-connection-string'
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
          image: '${acr.name}.azurecr.io/dinner/web-frontend:0.1'
          name: 'web-frontend'
          resources:{
            cpu: json('.25')
            memory: '.5Gi'
          }
          env: [
            {
              name: 'USE_CONSOLE_LOG_OUTPUT'
              value: 'true'
            }
            {
              name: 'OTEL_EXPORTER_OTLP_ENDPOINT'
              value: useOtelCollectorMonitoring == true ? 'http://otel-collector-app' : ''
            }
            {
              name: 'OTEL_EXPORTER_OTLP_PROTOCOL'
              value: 'http/protobuf'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              secretRef: 'appinsights-connection-string'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
        rules: [
          {
            name: 'http-scale-rule'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}
