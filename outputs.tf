# Resource Group Output
output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
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

output "storage_account_primary_endpoint" {
  description = "Primary endpoint of the storage account"
  value       = azurerm_storage_account.main.primary_blob_endpoint
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

output "file_share_quota" {
  description = "Quota of the file share in GB"
  value       = azurerm_storage_share.attribute_management.quota
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

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

# Application Insights Outputs
output "application_insights_name" {
  description = "Name of the Application Insights instance"
  value       = azurerm_application_insights.main.name
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key of Application Insights"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string of Application Insights"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "application_insights_app_id" {
  description = "App ID of Application Insights"
  value       = azurerm_application_insights.main.app_id
}

# App Service Plan Outputs
output "app_service_plan_name" {
  description = "Name of the App Service Plan"
  value       = azurerm_service_plan.main.name
}

output "app_service_plan_id" {
  description = "ID of the App Service Plan"
  value       = azurerm_service_plan.main.id
}

output "app_service_plan_sku" {
  description = "SKU of the App Service Plan"
  value       = azurerm_service_plan.main.sku_name
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

output "web_app_id" {
  description = "ID of the web app"
  value       = azurerm_linux_web_app.main.id
}

output "web_app_managed_identity_principal_id" {
  description = "Principal ID of the web app managed identity"
  value       = azurerm_linux_web_app.main.identity[0].principal_id
}

output "web_app_default_hostname" {
  description = "Default hostname of the web app"
  value       = azurerm_linux_web_app.main.default_hostname
}

# Runbook Output
output "runbook_name" {
  description = "Name of the extension attribute management runbook"
  value       = azurerm_automation_runbook.extension_attribute_management.name
}

output "runbook_id" {
  description = "ID of the extension attribute management runbook"
  value       = azurerm_automation_runbook.extension_attribute_management.id
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

# Automation Variables Summary
output "automation_variables" {
  description = "Summary of automation variables created"
  value = {
    basic_variables = {
      resource_group    = "ResourceGroupName"
      storage_account   = "StorageAccountName"
      file_share       = "FileShareName"
      key_vault        = "KeyVaultName"
    }
    email_variables = {
      from_email       = "EntraMgmt_FromEmail"
      to_email         = "EntraMgmt_ToEmail"
    }
    enhanced_variables = {
      storage_account  = "EntraMgmt_StorageAccount"
      file_share      = "EntraMgmt_FileShare"
      resource_group  = "EntraMgmt_ResourceGroup"
    }
  }
}

# Deployment Summary
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    resource_group       = azurerm_resource_group.main.name
    location            = azurerm_resource_group.main.location
    storage_account     = azurerm_storage_account.main.name
    automation_account  = azurerm_automation_account.main.name
    key_vault          = azurerm_key_vault.main.name
    web_app            = azurerm_linux_web_app.main.name
    app_service_plan   = azurerm_service_plan.main.name
    application_insights = azurerm_application_insights.main.name
    runbook            = azurerm_automation_runbook.extension_attribute_management.name
    deployment_time    = timestamp()
  }
}

# Azure Resource Information
output "azure_environment_info" {
  description = "Azure environment information"
  value = {
    subscription_id = data.azurerm_client_config.current.subscription_id
    tenant_id      = data.azurerm_client_config.current.tenant_id
    client_id      = data.azurerm_client_config.current.client_id
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
    email_config = "Update email addresses in automation variables: EntraMgmt_FromEmail and EntraMgmt_ToEmail"
  }
}

# Next Steps
output "next_steps" {
  description = "Next steps after basic deployment"
  value = [
    "1. Update email addresses in automation variables (EntraMgmt_FromEmail, EntraMgmt_ToEmail)",
    "2. Create Azure AD Application with Graph API permissions",
    "3. Assign required RBAC roles to managed identities",
    "4. Install PowerShell modules in Automation Account",
    "5. Deploy web application code (server.js, package.json, HTML files)",
    "6. Test runbook execution with What-If mode",
    "7. Configure email notifications and test alerts",
    "8. Set up monitoring and alerting in Application Insights"
  ]
}

# Connection Strings and URLs
output "connection_info" {
  description = "Important connection information"
  value = {
    web_app_url         = "https://${azurerm_linux_web_app.main.default_hostname}"
    key_vault_url       = azurerm_key_vault.main.vault_uri
    storage_file_url    = "https://${azurerm_storage_account.main.name}.file.core.windows.net/${azurerm_storage_share.attribute_management.name}"
    storage_blob_url    = azurerm_storage_account.main.primary_blob_endpoint
    app_insights_portal = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource${azurerm_application_insights.main.id}"
    automation_portal   = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource${azurerm_automation_account.main.id}"
  }
}

# Security and Access Information
output "security_summary" {
  description = "Security and access configuration summary"
  value = {
    managed_identities = {
      automation_account = azurerm_automation_account.main.identity[0].principal_id
      web_app           = azurerm_linux_web_app.main.identity[0].principal_id
    }
    key_vault_access = {
      current_user      = "Full access (Get, List, Set, Delete secrets)"
      automation_account = "Read access (Get, List secrets)"
      web_app           = "Read access (Get, List secrets)"
    }
    storage_access = {
      automation_account = "Managed identity access required"
      web_app           = "Managed identity access required"
    }
  }
}