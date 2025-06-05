# Resource Group Output
output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

# Storage Account Outputs
output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.main.id
}

output "storage_account_primary_key" {
  description = "Primary access key for the storage account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

# File Share Outputs
output "file_share_name" {
  description = "Name of the file share"
  value       = azurerm_storage_share.attribute_management.name
}

output "file_share_url" {
  description = "URL of the file share"
  value       = azurerm_storage_share.attribute_management.url
}

# Automation Account Outputs
output "automation_account_name" {
  description = "Name of the automation account"
  value       = azurerm_automation_account.main.name
}

output "automation_account_id" {
  description = "ID of the automation account"
  value       = azurerm_automation_account.main.id
}

output "automation_managed_identity_principal_id" {
  description = "Principal ID of the automation account managed identity"
  value       = azurerm_automation_account.main.identity[0].principal_id
}

output "automation_managed_identity_tenant_id" {
  description = "Tenant ID of the automation account managed identity"
  value       = azurerm_automation_account.main.identity[0].tenant_id
}

# Key Vault Outputs
output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

# Web App Outputs
output "web_app_name" {
  description = "Name of the web app"
  value       = azurerm_linux_web_app.main.name
}

output "web_app_url" {
  description = "URL of the web app"
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

# Runbook Output
output "runbook_name" {
  description = "Name of the extension attribute management runbook"
  value       = azurerm_automation_runbook.extension_attribute_management.name
}

# File Share Access Commands
output "file_share_access_commands" {
  description = "Commands to access the file share"
  value = {
    azure_cli     = "az storage file list --account-name ${azurerm_storage_account.main.name} --share-name ${azurerm_storage_share.attribute_management.name}"
    powershell    = "Get-AzStorageFile -ShareName ${azurerm_storage_share.attribute_management.name} -Context (New-AzStorageContext -StorageAccountName ${azurerm_storage_account.main.name} -StorageAccountKey '<key>')"
    mount_windows = "net use Z: \\\\${azurerm_storage_account.main.name}.file.core.windows.net\\${azurerm_storage_share.attribute_management.name}"
    mount_linux   = "sudo mount -t cifs //${azurerm_storage_account.main.name}.file.core.windows.net/${azurerm_storage_share.attribute_management.name} /mnt/azure-share -o username=${azurerm_storage_account.main.name},password=<key>"
  }
}

# Deployment Summary
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    resource_group    = azurerm_resource_group.main.name
    location         = azurerm_resource_group.main.location
    storage_account  = azurerm_storage_account.main.name
    automation_account = azurerm_automation_account.main.name
    key_vault       = azurerm_key_vault.main.name
    web_app         = azurerm_linux_web_app.main.name
    runbook         = azurerm_automation_runbook.extension_attribute_management.name
    deployment_time = timestamp()
  }
}

# Manual Configuration Required
output "manual_steps_required" {
  description = "Manual steps required after deployment"
  value = {
    azure_ad_app = "Create Azure AD application manually in Azure Portal with Graph API permissions"
    role_assignments = "Assign Storage Blob Data Contributor and Automation Contributor roles manually"
    automation_modules = "Install PowerShell modules manually: Microsoft.Graph.Authentication, Microsoft.Graph.Users, etc."
    graph_permissions = "Grant admin consent for Graph API permissions in Azure AD"
    web_app_code = "Deploy web application code to the App Service"
  }
}

# Next Steps
output "next_steps" {
  description = "Next steps after basic deployment"
  value = [
    "1. Create Azure AD Application with Graph API permissions",
    "2. Assign required RBAC roles to managed identities",
    "3. Install PowerShell modules in Automation Account",
    "4. Deploy web application code",
    "5. Test runbook execution",
    "6. Configure email notifications in Key Vault"
  ]
}