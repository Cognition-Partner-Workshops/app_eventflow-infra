# EventFlow Infrastructure

Infrastructure as Code (Bicep) for the EventFlow event-driven architecture demo on Azure.

## Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────────┐
│  Order Service   │────▶│ Service Bus  │────▶│  Payment Service    │
│ (Container App)  │     │   (Queue)    │     │  (Container App)    │
└────────┬────────┘     └──────────────┘     └────────┬────────────┘
         │                                            │
         ▼                                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Application Insights                         │
│                    Log Analytics Workspace                      │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                   ┌──────────────────┐     ┌─────────────────────┐
                   │   Alert Rule     │────▶│  Azure Function     │
                   │ (error spike)    │     │ (Devin API trigger) │
                   └──────────────────┘     └─────────────────────┘
```

## Cost Optimization

All resources use the cheapest tier suitable for demos:

| Resource | SKU/Tier | Estimated Monthly Cost |
|---|---|---|
| Container Apps Environment | Consumption (serverless) | ~$0 (pay-per-request) |
| Container Apps (×2) | Consumption | ~$0 at demo traffic |
| Azure Service Bus | Basic | ~$0.05/million ops |
| Log Analytics Workspace | Pay-as-you-go (5GB free) | $0 |
| Application Insights | Pay-as-you-go (5GB free) | $0 |
| Container Registry | Basic | ~$5/month |
| Azure Functions | Consumption | $0 (1M free executions) |
| **Total** | | **< $10/month** |

## Prerequisites

- Azure CLI 2.50+
- Bicep CLI (included with Azure CLI)
- An Azure subscription with Contributor access

## Deployment

```bash
# Login to Azure
az login

# Deploy the infrastructure
./scripts/deploy.sh

# Or deploy manually
az deployment group create \
  --resource-group rg-eventflow-demo \
  --template-file main.bicep \
  --parameters parameters/dev.bicepparam
```

## Teardown

```bash
# Remove all resources
./scripts/teardown.sh

# Or manually
az group delete --name rg-eventflow-demo --yes --no-wait
```

## Modules

| Module | Description |
|---|---|
| `modules/container-registry.bicep` | Azure Container Registry (Basic tier) |
| `modules/service-bus.bicep` | Azure Service Bus namespace + queue |
| `modules/monitoring.bicep` | Log Analytics + Application Insights |
| `modules/container-apps.bicep` | Container Apps Environment + both services |
| `modules/alerts.bicep` | Alert rules + action group for Devin trigger |
| `modules/function-app.bicep` | Azure Function for alert webhook → Devin API |

## Parameters

- `parameters/dev.bicepparam` — Development/demo environment (minimal resources)
- `parameters/prod.bicepparam` — Production example (higher limits, redundancy)

## Post-Deployment

After deploying infrastructure, you need to:

1. Build and push container images to the Container Registry
2. Update Container Apps with the image references
3. Set the Service Bus connection string in each service's environment
4. Configure the Devin API key in the Azure Function's app settings
