#!/usr/bin/env bash
# Tear down EventFlow infrastructure from Azure
# Usage: ./scripts/teardown.sh [resource-group]

set -euo pipefail

RESOURCE_GROUP="${1:-rg-eventflow-demo}"

echo "=== EventFlow Infrastructure Teardown ==="
echo "Resource Group: $RESOURCE_GROUP"
echo ""
echo "WARNING: This will delete ALL resources in the resource group."
echo ""

# Verify Azure CLI is logged in
if ! az account show &>/dev/null; then
    echo "ERROR: Not logged in to Azure CLI. Run 'az login' first."
    exit 1
fi

read -rp "Are you sure you want to delete '$RESOURCE_GROUP'? (y/N) " confirm
if [[ "$confirm" != [yY] ]]; then
    echo "Aborted."
    exit 0
fi

echo "--- Deleting resource group '$RESOURCE_GROUP'..."
az group delete \
    --name "$RESOURCE_GROUP" \
    --yes \
    --no-wait

echo ""
echo "=== Teardown initiated (running in background) ==="
echo "Resource group deletion typically takes 2-5 minutes."
echo "Check status: az group show --name $RESOURCE_GROUP --query properties.provisioningState -o tsv"
