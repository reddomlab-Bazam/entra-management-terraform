output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name  # Fixed to use created resource group
}

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

output "file_share_name" {
  description = "Name of the file share"
  value       = azurerm_storage_share.attribute_management.name
}

output "file_share_url" {
  description = "URL of the file share"
  value       = azurerm_storage_share.attribute_management.url
}

output "automation_account_name" {
  description = "Name of the automation account"
  value       = azurerm_automation_account.main.name
}

output "automation_account_id" {
  description = "ID of the automation account"
  value       = azurerm_automation_account.main.id
}

output "automation_managed_identity_principal_id" {
  description = "Principal ID of the automation account's managed identity"
  value       = azurerm_automation_account.main.identity[0].principal_id
}

output "automation_managed_identity_tenant_id" {
  description = "Tenant ID of the automation account's managed identity"
  value       = azurerm_automation_account.main.identity[0].tenant_id
}

output "runbook_name" {
  description = "Name of the PowerShell runbook"
  value       = azurerm_automation_runbook.extension_attribute_management.name
}

output "web_app_name" {
  description = "Name of the web application"
  value       = azurerm_linux_web_app.main.name
}

output "web_app_url" {
  description = "URL of the web application"
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "html_interface_path" {
  description = "Path to the HTML interface in the file share"
  value       = "\\\\${azurerm_storage_account.main.name}.file.core.windows.net\\${azurerm_storage_share.attribute_management.name}\\config\\attribute-management.html"
}

output "file_share_access_commands" {
  description = "PowerShell commands to access the file share"
  value = {
    create_context = "New-AzStorageContext -StorageAccountName '${azurerm_storage_account.main.name}' -StorageAccountKey '[ACCESS_KEY]'"
    list_files     = "Get-AzStorageFile -ShareName '${azurerm_storage_share.attribute_management.name}' -Context $ctx"
    config_path    = "config/attribute-management.html"
    logs_path      = "logs/"
    reports_path   = "reports/"
  }
}

output "azure_ad_application" {
  description = "Azure AD application details for Graph API access"
  value = {
    client_id    = azuread_application.extension_attribute_app.client_id  # Fixed deprecated attribute
    object_id    = azuread_application.extension_attribute_app.object_id
    display_name = azuread_application.extension_attribute_app.display_name
  }
}

output "deployment_summary" {
  description = "Summary of the deployed resources and next steps"
  value = {
    resource_group     = azurerm_resource_group.main.name
    storage_account    = azurerm_storage_account.main.name
    file_share         = azurerm_storage_share.attribute_management.name
    automation_account = azurerm_automation_account.main.name
    runbook           = azurerm_automation_runbook.extension_attribute_management.name
    web_app           = azurerm_linux_web_app.main.name
    web_app_url       = "https://${azurerm_linux_web_app.main.default_hostname}"
    key_vault         = azurerm_key_vault.main.name
    html_interface    = "\\\\${azurerm_storage_account.main.name}.file.core.windows.net\\${azurerm_storage_share.attribute_management.name}\\config\\attribute-management.html"
    next_steps = [
      "1. Access the web interface at: https://${azurerm_linux_web_app.main.default_hostname}",
      "2. Deploy the web application code to the App Service",
      "3. Configure email settings in Key Vault (email-from, email-to)",
      "4. Test extension attribute management in What-If mode",
      "5. Configure Graph API admin consent if needed",
      "6. Set up monitoring and alerts as required"
    ]
  }
}

output "graph_api_permissions" {
  description = "Microsoft Graph API permissions assigned"
  value = [
    "User.Read.All",
    "User.ReadWrite.All", 
    "Directory.ReadWrite.All",
    "Mail.Send"
  ]
}

output "role_assignments" {
  description = "Role assignments for the automation account managed identity"
  value = [
    "Storage File Data SMB Share Contributor",
    "Storage Account Contributor"
  ]
}

output "monitoring_and_logs" {
  description = "Locations for monitoring and logs"
  value = {
    execution_logs     = "\\\\${azurerm_storage_account.main.name}.file.core.windows.net\\${azurerm_storage_share.attribute_management.name}\\logs\\"
    html_reports      = "\\\\${azurerm_storage_account.main.name}.file.core.windows.net\\${azurerm_storage_share.attribute_management.name}\\reports\\"
    config_backups    = "\\\\${azurerm_storage_account.main.name}.file.core.windows.net\\${azurerm_storage_share.attribute_management.name}\\backups\\"
    automation_logs   = "Azure Portal -> Automation Account -> Jobs"
    application_insights = azurerm_application_insights.main.name
    web_app_logs      = "Azure Portal -> App Service -> Log stream"
  }
}