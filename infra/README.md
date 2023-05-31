# Hosting Infrastructure 

## Create resource group

First we need a resource group. Location is restricted to West Europe, as the Azure Open Ai is not available in other european regions.
```powershell
az group create -l westeurope -n rg-dinner-finder
```

## Deploy the environment

Deploy the environment with the following command. This will create the following resources:
- Azure Container Registry (for storing the container images)
- Azure Container App Environment for the services
- Serverless Cosmos DB (for storing the recipes)
- Azure Open AI and a gpt model
- Azure Application Insights (for observability)
- Azure Key Vault (for storing secrets)
- Azure Service Bus (for communication between the services)
The nameSuffix parameter is used to create unique names for the resources.
```powershell
az deployment group create -g rg-dinner-finder -f .\env.bicep -p nameSuffix=<yourname>
```

Next step is to build the container images for the services and push them to the Azure Container Registry created in the previous step.

## Build the container images for the services

The services are deployed as containers. To build the images please refer to the [Application readme](../README.md).

## Deploy the main application

Before this step the containers must be built. The main application is deployed with the following command:
```powershell
az deployment group create -g rg-dinner-finder -f .\apps.bicep -p nameSuffix=<yourname>
```

## Deploy email service

This is a optional service. It is used to send recipe emails to the users. It deploys:
- Email sender service (Azure Container App)
- Azure Communication Services 
- Azure Email Service 
- Azure Managed Domain (For testing purposes) 
The service is deployed with the following command.
```powershell
az deployment group create -g rg-dinner-finder -f .\email-sending.bicep -p nameSuffix=<yourname>
```