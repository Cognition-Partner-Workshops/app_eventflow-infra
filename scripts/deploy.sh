#!/usr/bin/env bash
# Deploy EventFlow infrastructure to Azure
# Usage: ./scripts/deploy.sh [resource-group] [parameters-file]

set -euo pipefail

RESOURCE_GROUP="${1:-rg-eventflow-demo}"
PARAMS_FILE="${2:-parameters/dev.bicepparam}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== EventFlow Infrastructure Deployment ==="
echo "Resource Group: $RESOURCE_GROUP"
echo "Parameters:     $PARAMS_FILE"
echo ""

# Verify Azure CLI is logged in
if ! az account show &>/dev/null; then
    echo "ERROR: Not logged in to Azure CLI. Run 'az login' first."
    exit 1
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
echo "Subscription:   $SUBSCRIPTION"
echo ""

# Create resource group if it doesn't exist
echo "--- Ensuring resource group exists..."
az group create \
    --name "$RESOURCE_GROUP" \
    --location eastus \
    --output none

# Deploy Bicep template
echo "--- Deploying infrastructure (this may take 3-5 minutes)..."
az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$ROOT_DIR/main.bicep" \
    --parameters "$ROOT_DIR/$PARAMS_FILE" \
    --output json \
    --query "properties.outputs"

echo ""
echo "=== Deployment complete ==="
echo ""
echo "Next steps:"
echo "  1. Build and push container images to the ACR"
echo "  2. Update Container Apps with image references"
echo "  3. Configure Devin API key in the Function App settings"
echo ""
echo "To push images:"
echo "  ACR_SERVER=\$(az deployment group show -g $RESOURCE_GROUP -n deploy-acr --query properties.outputs.loginServer.value -o tsv)"
echo "  az acr login --name \$ACR_SERVER"
echo "  docker build -t \$ACR_SERVER/eventflow-order-service:latest ./order-service/"
echo "  docker push \$ACR_SERVER/eventflow-order-service:latest"
