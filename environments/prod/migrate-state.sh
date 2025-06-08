#!/bin/bash

# =============================================================================
# TERRAFORM STATE MIGRATION SCRIPT
# =============================================================================
# This script helps migrate existing Terraform state to the new module structure

set -e

echo "Starting Terraform state migration..."

# Function to check if resource exists in state
check_resource() {
    local resource=$1
    if terraform state show "$resource" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to move resource with error handling
move_resource() {
    local from=$1
    local to=$2
    
    if check_resource "$from"; then
        echo "Moving $from to $to..."
        terraform state mv "$from" "$to"
    else
        echo "Resource $from not found in state, skipping..."
    fi
}

echo "Migrating storage resources to module..."
move_resource "azurerm_storage_account.main" "module.storage.azurerm_storage_account.main"
move_resource "azurerm_storage_share.attribute_management" "module.storage.azurerm_storage_share.attribute_management"
move_resource "azurerm_storage_container.webfiles" "module.storage.azurerm_storage_container.webfiles"
move_resource "azurerm_storage_share_directory.config" "module.storage.azurerm_storage_share_directory.config"
move_resource "azurerm_storage_share_directory.logs" "module.storage.azurerm_storage_share_directory.logs"
move_resource "azurerm_storage_share_directory.reports" "module.storage.azurerm_storage_share_directory.reports"
move_resource "azurerm_storage_share_directory.backups" "module.storage.azurerm_storage_share_directory.backups"
move_resource "azurerm_storage_share_directory.scripts" "module.storage.azurerm_storage_share_directory.scripts"
move_resource "azurerm_storage_share_directory.templates" "module.storage.azurerm_storage_share_directory.templates"

echo "Migrating webapp resources to module..."
move_resource "azurerm_service_plan.main" "module.webapp.azurerm_service_plan.main"
move_resource "azurerm_linux_web_app.main" "module.webapp.azurerm_linux_web_app.main"
move_resource "azurerm_application_insights.main" "module.webapp.azurerm_application_insights.main"

echo "Removing old Azure AD application resources (they will be recreated)..."
# These resources will be removed and recreated with the new configuration
if check_resource "data.azuread_application.web_app"; then
    terraform state rm "data.azuread_application.web_app" || true
fi

if check_resource "azuread_application.web_app"; then
    terraform state rm "azuread_application.web_app" || true
fi

if check_resource "azuread_service_principal.web_app"; then
    terraform state rm "azuread_service_principal.web_app" || true
fi

echo "Removing automation-related resources (no longer managed)..."
# Remove automation resources that are no longer in the configuration
automation_resources=(
    "azuread_application.automation"
    "azuread_service_principal.automation" 
    "azuread_application_password.automation"
    "azurerm_automation_account.main"
    "azurerm_automation_runbook.extension_attribute_management"
    "azurerm_automation_variable_string.azure_ad_client_id"
    "azurerm_automation_variable_string.azure_ad_client_secret"
    "azurerm_automation_variable_string.azure_ad_tenant_id"
    "azurerm_automation_variable_string.file_share"
    "azurerm_automation_variable_string.file_share_alt"
    "azurerm_automation_variable_string.from_email"
    "azurerm_automation_variable_string.key_vault"
    "azurerm_automation_variable_string.resource_group"
    "azurerm_automation_variable_string.resource_group_alt"
    "azurerm_automation_variable_string.storage_account"
    "azurerm_automation_variable_string.storage_account_alt"
    "azurerm_automation_variable_string.to_email"
    "azurerm_role_assignment.automation_storage_contributor"
    "azurerm_role_assignment.webapp_automation_contributor"
    "azurerm_role_assignment.webapp_storage_contributor"
    "azurerm_key_vault_access_policy.automation"
    "azurerm_key_vault_secret.automation_client_secret"
)

for resource in "${automation_resources[@]}"; do
    if check_resource "$resource"; then
        echo "Removing $resource..."
        terraform state rm "$resource" || true
    fi
done

echo "State migration completed!"
echo ""
echo "Next steps:"
echo "1. Run 'terraform plan' to review the changes"
echo "2. Run 'terraform apply' to apply the changes"
echo ""
echo "Note: The Azure AD application will be recreated with the new configuration."
echo "You may need to update any external references to use the new application ID." 