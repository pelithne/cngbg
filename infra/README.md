# Hosting Infrastructure 

## Create resource group

First we need a resource group. Location is restricted to West Europe, as the Azure Open Ai is not available in other european regions.
```powershell
az group create -l westeurope -n rg-dinner-finder
```

## Deploy the environment

Deploy the environment with the following command. The nameSuffix parameter is used to create unique names for the resources.
```powershell
az deployment group create -g rg-dinner-finder -f .\env.bicep -p nameSuffix=<yourname>
```

## Build the container images for the services

The services are deployed as containers. The container images are built with the following commands. The images are stored in the Azure Container Registry.
```powershell
az acr build -g rg-dinner-finder --registry acr<yourname> --image demo/ai-processor:0.1 . -f .\Dockerfile
```