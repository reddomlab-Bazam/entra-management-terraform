# =============================================================================
# PRODUCTION ENVIRONMENT OUTPUTS
# =============================================================================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.storage.storage_account_name
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = module.storage.storage_account_id
}

output "file_share_name" {
  description = "Name of the file share"
  value       = module.storage.file_share_name
}

output "web_app_name" {
  description = "Name of the web application"
  value       = module.webapp.web_app_name
}

output "web_app_default_hostname" {
  description = "Default hostname of the web application"
  value       = module.webapp.web_app_default_hostname
}

output "app_insights_id" {
  description = "ID of the Application Insights instance"
  value       = module.webapp.app_insights_id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "automation_account_name" {
  description = "Name of the Azure Automation Account"
  value       = azurerm_automation_account.main.name
}

output "automation_account_id" {
  description = "ID of the Azure Automation Account"
  value       = azurerm_automation_account.main.id
}

output "automation_runbook_name" {
  description = "Name of the automation runbook"
  value       = azurerm_automation_runbook.extension_attribute_management.name
} 