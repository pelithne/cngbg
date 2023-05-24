# cngbg

This application is a demo on how to setup an event driven architecture combining Dapr, Azure OpenAI and Azure Container Apps.

## Prerequisites

To run this application you need an **Approved Azure OpenAI Azure subscription** ([Azure Open AI](https://azure.microsoft.com/en-us/products/cognitive-services/openai-service/)) an and the following tools installed:

- [Docker](https://www.docker.com/products/docker-desktop) (for local development)
- [Dapr CLI](https://docs.dapr.io/getting-started/install-dapr-cli/) (for local development)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Azure Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)
- [.NET 7 SDK](https://dotnet.microsoft.com/download/dotnet/7.0)

## Local development

To run the application locally with Docker compose, you need to create a `.env` file in the root of the repository. This file should contain the following variables:

```bash
AZURE_OPENAI_API_MODEL="<your model here>" # e.g. gpt-35-turbo
AZURE_OPENAI_API_ENDPOINT="<your azure openai endpoint here>" 
AZURE_OPENAI_API_KEY="<your azure openai key here>"

AZURE_COMMUNICATION_ENDPOINT="<your azure communication endpoint here>" 
AZURE_COMMUNICATION_FROM_ADDRESS="<your azure communication custom domain from address here>"
APPLICATION_INSIGHTS_INSTRUMENTATION_KEY="<your application insights instrumentation key here>"
```

Then you can run the application with the following command:

```bash
docker compose build
docker compose up
```

To clean up the resources created by Docker compose, run the following command:

```bash
docker compose down
```

## Deploy to Azure

Please refer to the [Hosting Infrastructure](infra/README.md) documentation for instructions on how to deploy the application to Azure.

## Building the container images in Azure

The container images are built with the following commands. The images are stored in the Azure Container Registry.
First set the environment variable for the Azure Container Registry name:

```powershell	
$ENV:ACR="<your acr name>"
```
Then build the images with the following commands:

```powershell
push-location src
push-location dinner-api
az acr build -g rg-dinner-finder -r $ENV:ACR -t dinner/api:0.1 .
pop-location
push-location ai-processor
az acr build -g rg-dinner-finder -r $ENV:ACR -t dinner/ai-processor:0.1 .
pop-location
```

