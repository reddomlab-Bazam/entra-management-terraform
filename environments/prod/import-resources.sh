#!/bin/bash

# =============================================================================
# TERRAFORM CLOUD RESOURCE IMPORT SCRIPT
# =============================================================================
# This script imports existing Azure resources into Terraform Cloud workspace

set -e

echo "🚀 Starting resource import for Terraform Cloud..."
echo "Make sure you have run 'terraform login' and 'terraform init' first!"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to import resource with error handling
import_resource() {
    local resource_name=$1
    local resource_id=$2
    
    echo -e "${YELLOW}Importing $resource_name...${NC}"
    
    if terraform import "$resource_name" "$resource_id"; then
        echo -e "${GREEN}✅ Successfully imported $resource_name${NC}"
    else
        echo -e "${RED}❌ Failed to import $resource_name${NC}"
        echo "Resource ID: $resource_id"
        echo "This might be normal if the resource doesn't exist or is already imported."
    fi
    echo ""
}

# Import core resources
echo "📦 Importing core infrastructure resources..."

import_resource "azurerm_resource_group.main" \
    "/subscriptions/102e9107-d789-4139-9220-6eb6ed33b472/resourceGroups/lab-uks-entra-rg"

import_resource "azurerm_log_analytics_workspace.main" \
    "/subscriptions/102e9107-d789-4139-9220-6eb6ed33b472/resourceGroups/lab-uks-entra-rg/providers/Microsoft.OperationalInsights/workspaces/lab-uks-entra-logs"

import_resource "azurerm_key_vault.main" \
    "/subscriptions/102e9107-d789-4139-9220-6eb6ed33b472/resourceGroups/lab-uks-entra-rg/providers/Microsoft.KeyVault/vaults/lab-uks-entra-kv"

# Import storage module resources
echo "💾 Importing storage module resources..."

import_resource "module.storage.azurerm_storage_account.main" \
    "/subscriptions/102e9107-d789-4139-9220-6eb6ed33b472/resourceGroups/lab-uks-entra-rg/providers/Microsoft.Storage/storageAccounts/labentraautomation"

import_resource "module.storage.azurerm_storage_share.attribute_management" \
    "https://labentraautomation.file.core.windows.net/entra-management"

import_resource "module.storage.azurerm_storage_container.webfiles" \
    "https://labentraautomation.blob.core.windows.net/webfiles"

# Import storage directories
echo "📁 Importing storage directories..."

directories=("config" "logs" "reports" "backups" "scripts" "templates")
for dir in "${directories[@]}"; do
    import_resource "module.storage.azurerm_storage_share_directory.$dir" \
        "https://labentraautomation.file.core.windows.net/entra-management/$dir"
done

# Import webapp module resources
echo "🌐 Importing webapp module resources..."

import_resource "module.webapp.azurerm_service_plan.main" \
    "/subscriptions/102e9107-d789-4139-9220-6eb6ed33b472/resourceGroups/lab-uks-entra-rg/providers/Microsoft.Web/serverFarms/lab-uks-entra-webapp-plan"

import_resource "module.webapp.azurerm_linux_web_app.main" \
    "/subscriptions/102e9107-d789-4139-9220-6eb6ed33b472/resourceGroups/lab-uks-entra-rg/providers/Microsoft.Web/sites/lab-uks-entra-webapp"

import_resource "module.webapp.azurerm_application_insights.main" \
    "/subscriptions/102e9107-d789-4139-9220-6eb6ed33b472/resourceGroups/lab-uks-entra-rg/providers/Microsoft.Insights/components/lab-uks-entra-ai"

echo ""
echo -e "${GREEN}🎉 Import process completed!${NC}"
echo ""
echo "Next steps:"
echo "1. Run 'terraform plan' to see what changes are needed"
echo "2. Review the plan carefully"
echo "3. Commit your changes to Git to trigger a Terraform Cloud run"
echo "4. Review and apply the plan in Terraform Cloud"
echo ""
echo "Note: Some resources may not import if they don't exist or have different names."
echo "This is normal for a phased migration approach." 