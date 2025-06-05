# Data sources
data "azurerm_client_config" "current" {}

# Create Resource Group since it doesn't exist in lab
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  
  tags = local.tags_all
}

# Storage Account
resource "azurerm_storage_account" "main" {
  name                     = local.resource_names.storage_account
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type
  account_kind             = "StorageV2"
  
  # Security settings
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true  # Required for web app access
  
  # Enable file share access
  shared_access_key_enabled = true
  
  # Enable CORS for web interface
  share_properties {
    cors_rule {
      allowed_origins    = ["https://${local.resource_names.web_app}.azurewebsites.net"]
      allowed_methods    = ["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS"]
      allowed_headers    = ["*"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }
  
  tags = local.tags_all
}

# Storage Share and Directories
resource "azurerm_storage_share" "attribute_management" {
  name                 = var.file_share_name
  storage_account_name = azurerm_storage_account.main.name
  quota                = var.file_share_quota_gb
  
  depends_on = [azurerm_storage_account.main]
}

resource "azurerm_storage_share_directory" "config" {
  name                 = "config"
  share_name           = azurerm_storage_share.attribute_management.name
  storage_account_name = azurerm_storage_account.main.name
}

resource "azurerm_storage_share_directory" "logs" {
  name                 = "logs"
  share_name           = azurerm_storage_share.attribute_management.name
  storage_account_name = azurerm_storage_account.main.name
}

resource "azurerm_storage_share_directory" "reports" {
  name                 = "reports"
  share_name           = azurerm_storage_share.attribute_management.name
  storage_account_name = azurerm_storage_account.main.name
}

resource "azurerm_storage_share_directory" "backups" {
  name                 = "backups"
  share_name           = azurerm_storage_share.attribute_management.name
  storage_account_name = azurerm_storage_account.main.name
}

resource "azurerm_storage_share_directory" "scripts" {
  name                 = "scripts"
  share_name           = azurerm_storage_share.attribute_management.name
  storage_account_name = azurerm_storage_account.main.name
}

resource "azurerm_storage_share_directory" "templates" {
  name                 = "templates"
  share_name           = azurerm_storage_share.attribute_management.name
  storage_account_name = azurerm_storage_account.main.name
}

# Automation Account
resource "azurerm_automation_account" "main" {
  name                = local.resource_names.automation_account
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = var.automation_sku
  
  # Enable system-assigned managed identity
  identity {
    type = "SystemAssigned"
  }
  
  # Enable local authentication for web interface
  local_authentication_enabled = true
  
  tags = local.tags_all
}

# Automation Variables
resource "azurerm_automation_variable_string" "storage_account" {
  name                    = "EntraMgmt_StorageAccount"
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  value                   = azurerm_storage_account.main.name
  description            = "Storage account name for Entra management"
}

resource "azurerm_automation_variable_string" "file_share" {
  name                    = "EntraMgmt_FileShare"
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  value                   = azurerm_storage_share.attribute_management.name
  description            = "File share name for logs and configuration"
}

resource "azurerm_automation_variable_string" "resource_group" {
  name                    = "EntraMgmt_ResourceGroup"
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  value                   = azurerm_resource_group.main.name
  description            = "Resource group name"
}

resource "azurerm_automation_variable_string" "key_vault" {
  name                    = "EntraMgmt_KeyVault"
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  value                   = local.resource_names.key_vault
  description            = "Key Vault name for secure configuration"
}

# PowerShell Modules
resource "azurerm_automation_module" "graph_authentication" {
  name                    = "Microsoft.Graph.Authentication"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  
  module_uri = "https://www.powershellgallery.com/packages/Microsoft.Graph.Authentication"
  
  depends_on = [azurerm_automation_account.main]
}

resource "azurerm_automation_module" "graph_users" {
  name                    = "Microsoft.Graph.Users"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  
  module_uri = "https://www.powershellgallery.com/packages/Microsoft.Graph.Users"
  
  depends_on = [azurerm_automation_module.graph_authentication]
}

resource "azurerm_automation_module" "graph_mail" {
  name                    = "Microsoft.Graph.Mail"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  
  module_uri = "https://www.powershellgallery.com/packages/Microsoft.Graph.Mail"
  
  depends_on = [azurerm_automation_module.graph_users]
}

resource "azurerm_automation_module" "graph_groups" {
  name                    = "Microsoft.Graph.Groups"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  
  module_uri = "https://www.powershellgallery.com/packages/Microsoft.Graph.Groups"
  
  depends_on = [azurerm_automation_module.graph_mail]
}

resource "azurerm_automation_module" "graph_devicemanagement" {
  name                    = "Microsoft.Graph.DeviceManagement"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  
  module_uri = "https://www.powershellgallery.com/packages/Microsoft.Graph.DeviceManagement"
  
  depends_on = [azurerm_automation_module.graph_groups]
}

resource "azurerm_automation_module" "az_storage" {
  name                    = "Az.Storage"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  
  module_uri = "https://www.powershellgallery.com/packages/Az.Storage"
  
  depends_on = [azurerm_automation_module.graph_devicemanagement]
}

resource "azurerm_automation_module" "az_accounts" {
  name                    = "Az.Accounts"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  
  module_uri = "https://www.powershellgallery.com/packages/Az.Accounts"
  
  depends_on = [azurerm_automation_module.az_storage]
}

resource "azurerm_automation_module" "az_compute" {
  name                    = "Az.Compute"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  
  module_uri = "https://www.powershellgallery.com/packages/Az.Compute"
  
  depends_on = [azurerm_automation_module.az_accounts]
}

# PowerShell Runbook
resource "azurerm_automation_runbook" "extension_attribute_management" {
  name                    = "Extension-Attribute-Management"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  
  log_verbose  = true
  log_progress = true
  runbook_type = "PowerShell"
  
  content = file("${path.module}/scripts/extension-attribute-management.ps1")
  
  depends_on = [
    azurerm_automation_module.az_compute,
    azurerm_automation_module.az_accounts,
    azurerm_automation_module.az_storage,
    azurerm_automation_module.graph_authentication,
    azurerm_automation_module.graph_users,
    azurerm_automation_module.graph_mail,
    azurerm_automation_module.graph_groups,
    azurerm_automation_module.graph_devicemanagement
  ]
  
  tags = local.tags_all
}

# Web App Infrastructure
resource "azurerm_service_plan" "main" {
  name                = local.resource_names.app_service_plan
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  
  tags = local.tags_all
}

resource "azurerm_linux_web_app" "main" {
  name                = local.resource_names.web_app
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    application_stack {
      node_version = "18-lts"
    }
    
    always_on = var.app_service_plan_sku != "F1" ? true : false
    
    # Enable HTTPS only
    https_only = true
    
    # Application settings for the web interface
    app_command_line = "npm start"
  }

  app_settings = {
    "AZURE_SUBSCRIPTION_ID"       = data.azurerm_client_config.current.subscription_id
    "RESOURCE_GROUP_NAME"         = azurerm_resource_group.main.name
    "AUTOMATION_ACCOUNT_NAME"     = azurerm_automation_account.main.name
    "STORAGE_ACCOUNT_NAME"        = azurerm_storage_account.main.name
    "FILE_SHARE_NAME"             = azurerm_storage_share.attribute_management.name
    "KEY_VAULT_NAME"              = local.resource_names.key_vault
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "WEBSITE_RUN_FROM_PACKAGE"    = "1"
  }

  # Enable managed identity
  identity {
    type = "SystemAssigned"
  }

  tags = local.tags_all
}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                = local.resource_names.key_vault
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  
  sku_name = "standard"
  
  # Enable for deployment and template deployment
  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  enabled_for_disk_encryption     = true
  
  # Lab settings - more permissive for testing
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  
  # Network access rules
  network_acls {
    default_action = "Allow"  # Open for lab access
    bypass         = "AzureServices"
  }
  
  tags = local.tags_all
}

# Key Vault Access Policies
resource "azurerm_key_vault_access_policy" "automation" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_automation_account.main.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List",
    "Set"
  ]
  
  depends_on = [azurerm_key_vault.main]
}

resource "azurerm_key_vault_access_policy" "webapp" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.main.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
  
  depends_on = [azurerm_key_vault.main]
}

# Add current user access to Key Vault for lab setup
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Backup",
    "Restore"
  ]
  
  depends_on = [azurerm_key_vault.main]
}

# Store storage key in Key Vault
resource "azurerm_key_vault_secret" "storage_key" {
  name         = "storage-account-key"
  value        = azurerm_storage_account.main.primary_access_key
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_key_vault_access_policy.automation]
  
  tags = local.tags_all
}

# Role Assignments for Automation Account
resource "azurerm_role_assignment" "automation_storage_access" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_automation_account.main.identity[0].principal_id
  
  depends_on = [azurerm_automation_account.main]
}

resource "azurerm_role_assignment" "automation_storage_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_automation_account.main.identity[0].principal_id
  
  depends_on = [azurerm_automation_account.main]
}

# Web App Role Assignments
resource "azurerm_role_assignment" "webapp_automation_contributor" {
  scope                = azurerm_automation_account.main.id
  role_definition_name = "Automation Contributor"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "webapp_storage_reader" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

# Azure AD Application for Graph API
resource "azuread_application" "extension_attribute_app" {
  display_name = "${var.automation_account_name}-graph-app"
  
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
    
    resource_access {
      id   = "df021288-bdef-4463-88db-98f22de89214" # User.Read.All
      type = "Role"
    }
    
    resource_access {
      id   = "741f803b-c850-494e-b5df-cde7c675a1ca" # User.ReadWrite.All
      type = "Role"
    }
    
    resource_access {
      id   = "19dbc75e-c2e2-444c-a770-ec69d8559fc7" # Directory.ReadWrite.All
      type = "Role"
    }
    
    resource_access {
      id   = "b633e1c5-b582-4048-a93e-9f11b44c7e96" # Mail.Send
      type = "Role"
    }
  }
  
  tags = ["ExtensionAttributeManagement", "Lab", "Terraform"]
}

resource "azuread_service_principal" "extension_attribute_sp" {
  application_id = azuread_application.extension_attribute_app.application_id
  
  depends_on = [azuread_application.extension_attribute_app]
  
  tags = ["ExtensionAttributeManagement", "Lab", "Terraform"]
}

data "azuread_service_principal" "microsoft_graph" {
  application_id = "00000003-0000-0000-c000-000000000000"
}

# Graph API Role Assignments
resource "azuread_app_role_assignment" "user_read_all" {
  app_role_id         = "df021288-bdef-4463-88db-98f22de89214" # User.Read.All
  principal_object_id = azurerm_automation_account.main.identity[0].principal_id
  resource_object_id  = data.azuread_service_principal.microsoft_graph.object_id
}

resource "azuread_app_role_assignment" "user_readwrite_all" {
  app_role_id         = "741f803b-c850-494e-b5df-cde7c675a1ca" # User.ReadWrite.All
  principal_object_id = azurerm_automation_account.main.identity[0].principal_id
  resource_object_id  = data.azuread_service_principal.microsoft_graph.object_id
}

resource "azuread_app_role_assignment" "directory_readwrite_all" {
  app_role_id         = "19dbc75e-c2e2-444c-a770-ec69d8559fc7" # Directory.ReadWrite.All
  principal_object_id = azurerm_automation_account.main.identity[0].principal_id
  resource_object_id  = data.azuread_service_principal.microsoft_graph.object_id
}

resource "azuread_app_role_assignment" "mail_send" {
  app_role_id         = "b633e1c5-b582-4048-a93e-9f11b44c7e96" # Mail.Send
  principal_object_id = azurerm_automation_account.main.identity[0].principal_id
  resource_object_id  = data.azuread_service_principal.microsoft_graph.object_id
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = local.resource_names.application_insights
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "Node.JS"
  
  tags = local.tags_all
}

# Storage container for web app deployment
resource "azurerm_storage_container" "webfiles" {
  name                  = "webfiles"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Upload HTML interface to file share
resource "azurerm_storage_share_file" "html_interface" {
  name             = "attribute-management.html"
  storage_share_id = azurerm_storage_share.attribute_management.id
  path             = "config"
  source           = "${path.module}/files/attribute-management.html"
  
  depends_on = [azurerm_storage_share_directory.config]
}

# Optional scheduled execution (disabled by default for lab)
resource "azurerm_automation_schedule" "weekly_execution" {
  count                   = var.enable_schedule ? 1 : 0
  name                    = "weekly-extension-attribute-update"
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  frequency               = var.schedule_frequency
  interval                = 1
  timezone                = var.schedule_timezone
  start_time              = var.schedule_start_time
  description             = "Weekly extension attribute management execution"
  
  week_days = var.schedule_frequency == "Week" ? ["Sunday"] : null
}

resource "azurerm_automation_job_schedule" "weekly_job" {
  count                   = var.enable_schedule ? 1 : 0
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  schedule_name           = azurerm_automation_schedule.weekly_execution[0].name
  runbook_name            = azurerm_automation_runbook.extension_attribute_management.name
}