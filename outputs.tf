output "resource_group_name" {
  description = "Name of the resource group"
  value       = data.azurerm_resource_group.main.name
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
    application_id = azuread_application.extension_attribute_app.application_id
    object_id      = azuread_application.extension_attribute_app.object_id
    display_name   = azuread_application.extension_attribute_app.display_name
  }
}

output "deployment_summary" {
  description = "Summary of the deployed resources and next steps"
  value = {
    storage_account   = azurerm_storage_account.main.name
    file_share       = azurerm_storage_share.attribute_management.name
    automation_account = azurerm_automation_account.main.name
    runbook          = azurerm_automation_runbook.extension_attribute_management.name
    html_interface   = "\\\\${azurerm_storage_account.main.name}.file.core.windows.net\\${azurerm_storage_share.attribute_management.name}\\config\\attribute-management.html"
    next_steps = [
      "1. Access the HTML interface at the provided path",
      "2. Configure extension attribute settings via the web interface",
      "3. Test the runbook execution in Azure Automation Account",
      "4. Set up email notifications if required",
      "5. Enable scheduled execution if needed"
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
    execution_logs = "\\\\${azurerm_storage_account.main.name}.file.core.windows.net\\${azurerm_storage_share.attribute_management.name}\\logs\\"
    html_reports  = "\\\\${azurerm_storage_account.main.name}.file.core.windows.net\\${azurerm_storage_share.attribute_management.name}\\reports\\"
    config_backups = "\\\\${azurerm_storage_account.main.name}.file.core.windows.net\\${azurerm_storage_share.attribute_management.name}\\backups\\"
    automation_logs = "Azure Portal -> Automation Account -> Jobs"
  }
}