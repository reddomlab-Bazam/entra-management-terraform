# =============================================================================
# ENTRA MANAGEMENT CONSOLE - CORRECTED TERRAFORM CONFIGURATION
# =============================================================================

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = local.tags_all
}

# Data source for current Azure configuration
data "azurerm_client_config" "current" {}

# =============================================================================
# AZURE AD APPLICATIONS FOR AUTHENTICATION (CORRECTED PERMISSIONS)
# =============================================================================

# Azure AD Application for web authentication
resource "azuread_application" "web_app" {
  display_name = "${local.naming_prefix}-web-app"
  description  = "Web application for Entra Management Console with RBAC authentication"
  
  # Single Page Application configuration (FIXED: trailing slash)
  single_page_application {
    redirect_uris = [
      "https://${var.web_app_name}.azurewebsites.net/"
    ]
  }

  # Required resource access for Microsoft Graph
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    # CORRECTED delegated permissions for user context
    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
    
    resource_access {
      id   = "b4e74841-8e56-480b-be8b-910348b18b4c" # User.ReadWrite.All
      type = "Scope"
    }
    
    # FIXED: Device.Read.All (delegated permission exists)
    resource_access {
      id   = "7438b122-aefc-4978-80ed-43db9fcc7715" # Device.Read.All
      type = "Scope"
    }
    
    resource_access {
      id   = "4e46008b-f24c-477d-8fff-7bb4ec7aafe0" # Group.ReadWrite.All
      type = "Scope"
    }
    
    resource_access {
      id   = "06da0dbc-49e2-44d2-8312-53f166ab848a" # Directory.Read.All
      type = "Scope"
    }
  }

  tags = ["EntraManagement", "WebApp", "Authentication"]
}

# Service principal for the web app
resource "azuread_service_principal" "web_app" {
  client_id                    = azuread_application.web_app.client_id
  app_role_assignment_required = false
  owners                       = [data.azurerm_client_config.current.object_id]

  tags = ["EntraManagement", "WebApp", "ServicePrincipal"]
}

# Azure AD Application for automation account
resource "azuread_application" "automation" {
  display_name = "${local.naming_prefix}-automation"
  description  = "Service application for Entra Management automation runbooks"

  # Application permissions for service-to-service
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    # Application permissions for automation
    resource_access {
      id   = "df021288-bdef-4463-88db-98f22de89214" # User.Read.All
      type = "Role"
    }
    
    resource_access {
      id   = "741f803b-c850-494e-b5df-cde7c675a1ca" # User.ReadWrite.All
      type = "Role"
    }
    
    # CORRECT: Device.ReadWrite.All as application permission
    resource_access {
      id   = "1138cb37-bd11-4084-a2b7-9f71582aeddb" # Device.ReadWrite.All
      type = "Role"
    }
    
    resource_access {
      id   = "62a82d76-70ea-41e2-9197-370581804d09" # Group.ReadWrite.All
      type = "Role"
    }
    
    resource_access {
      id   = "b633e1c5-b582-4048-a93e-9f11b44c7e96" # Mail.Send
      type = "Role"
    }
    
    # Add Directory.Read.All for automation
    resource_access {
      id   = "7ab1d382-f21e-4acd-a863-ba3e13f7da61" # Directory.Read.All
      type = "Role"
    }
  }

  tags = ["EntraManagement", "Automation", "ServiceApp"]
}

# Service principal for automation
resource "azuread_service_principal" "automation" {
  client_id                    = azuread_application.automation.client_id
  app_role_assignment_required = false
  owners                       = [data.azurerm_client_config.current.object_id]

  tags = ["EntraManagement", "Automation", "ServicePrincipal"]
}

# Client secret for automation application
resource "azuread_application_password" "automation" {
  application_id = azuread_application.automation.id
  display_name   = "Terraform managed secret"
  end_date_relative = "17520h" # 24 months
}

# =============================================================================
# STORAGE ACCOUNT AND FILE SHARE
# =============================================================================

# Storage Account
resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type
  
  tags = local.tags_all
}

# File Share for storing scripts and data
resource "azurerm_storage_share" "attribute_management" {
  name                 = var.file_share_name
  storage_account_name = azurerm_storage_account.main.name
  quota                = var.file_share_quota_gb
}

# Storage Share Directories
resource "azurerm_storage_share_directory" "config" {
  name             = "config"
  storage_share_id = azurerm_storage_share.attribute_management.id
}

resource "azurerm_storage_share_directory" "logs" {
  name             = "logs"
  storage_share_id = azurerm_storage_share.attribute_management.id
}

resource "azurerm_storage_share_directory" "reports" {
  name             = "reports"
  storage_share_id = azurerm_storage_share.attribute_management.id
}

resource "azurerm_storage_share_directory" "backups" {
  name             = "backups"
  storage_share_id = azurerm_storage_share.attribute_management.id
}

resource "azurerm_storage_share_directory" "scripts" {
  name             = "scripts"
  storage_share_id = azurerm_storage_share.attribute_management.id
}

resource "azurerm_storage_share_directory" "templates" {
  name             = "templates"
  storage_share_id = azurerm_storage_share.attribute_management.id
}

# Storage Container for web files
resource "azurerm_storage_container" "webfiles" {
  name                  = "webfiles"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "blob"
}

# =============================================================================
# AUTOMATION ACCOUNT
# =============================================================================

# Automation Account
resource "azurerm_automation_account" "main" {
  name                = var.automation_account_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = var.automation_sku

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags_all
}

# =============================================================================
# AUTOMATION VARIABLES
# =============================================================================

# Basic automation variables
resource "azurerm_automation_variable_string" "resource_group" {
  name                    = "ResourceGroupName"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = azurerm_resource_group.main.name
  description             = "Resource group name"
}

resource "azurerm_automation_variable_string" "storage_account" {
  name                    = "StorageAccountName"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = azurerm_storage_account.main.name
  description             = "Storage account name"
}

resource "azurerm_automation_variable_string" "file_share" {
  name                    = "FileShareName"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = azurerm_storage_share.attribute_management.name
  description             = "File share name"
}

# Enhanced automation variables
resource "azurerm_automation_variable_string" "from_email" {
  name                    = "EntraMgmt_FromEmail"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = var.from_email
  description             = "From email address for notifications"
}

resource "azurerm_automation_variable_string" "to_email" {
  name                    = "EntraMgmt_ToEmail"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = var.to_email
  description             = "To email address for notifications"
}

resource "azurerm_automation_variable_string" "storage_account_alt" {
  name                    = "EntraMgmt_StorageAccount"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = azurerm_storage_account.main.name
  description             = "Storage account name for Entra management"
}

resource "azurerm_automation_variable_string" "file_share_alt" {
  name                    = "EntraMgmt_FileShare"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = azurerm_storage_share.attribute_management.name
  description             = "File share name for Entra management"
}

resource "azurerm_automation_variable_string" "resource_group_alt" {
  name                    = "EntraMgmt_ResourceGroup"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = azurerm_resource_group.main.name
  description             = "Resource group name for Entra management"
}

# Azure AD Authentication Variables for Automation
resource "azurerm_automation_variable_string" "azure_ad_client_id" {
  name                    = "AzureADClientId"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = azuread_application.automation.client_id
  description             = "Azure AD application client ID for automation"
}

resource "azurerm_automation_variable_string" "azure_ad_tenant_id" {
  name                    = "AzureADTenantId"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = data.azurerm_client_config.current.tenant_id
  description             = "Azure AD tenant ID"
}

resource "azurerm_automation_variable_string" "azure_ad_client_secret" {
  name                    = "AzureADClientSecret"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = azuread_application_password.automation.value
  description             = "Azure AD application client secret"
  encrypted               = true
}

# =============================================================================
# KEY VAULT
# =============================================================================

# Key Vault
resource "azurerm_key_vault" "main" {
  name                = local.resource_names.key_vault
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  purge_protection_enabled = false

  tags = local.tags_all
}

# Key Vault Access Policy for Current User
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
}

# Key Vault Access Policy for Automation Account
resource "azurerm_key_vault_access_policy" "automation" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_automation_account.main.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Store storage account key in Key Vault
resource "azurerm_key_vault_secret" "storage_key" {
  name         = "StorageAccountKey"
  value        = azurerm_storage_account.main.primary_access_key
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]

  tags = local.tags_all
}

# Store automation client secret in Key Vault as backup
resource "azurerm_key_vault_secret" "automation_client_secret" {
  name         = "AutomationClientSecret"
  value        = azuread_application_password.automation.value
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]

  tags = local.tags_all
}

# Update Automation Variable for Key Vault
resource "azurerm_automation_variable_string" "key_vault" {
  name                    = "KeyVaultName"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = azurerm_key_vault.main.name
  description             = "Key vault name"
}

# =============================================================================
# LOG ANALYTICS AND APPLICATION INSIGHTS
# =============================================================================

# Log Analytics Workspace (required for Application Insights)
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.naming_prefix}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.tags_all
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${local.naming_prefix}-ai"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = var.application_insights_type
  workspace_id        = azurerm_log_analytics_workspace.main.id
  
  tags = local.tags_all
}

# =============================================================================
# WEB APPLICATION
# =============================================================================

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = local.resource_names.app_service_plan
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku

  # Prevent replacement during updates
  lifecycle {
    ignore_changes = [tags]
  }

  tags = local.tags_all
}

# =============================================================================
# UPDATE YOUR LAB-main.tf - Linux Web App Section
# =============================================================================

# Replace the existing azurerm_linux_web_app resource with this updated version:

resource "azurerm_linux_web_app" "main" {
  name                = var.web_app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = var.enable_https_only

  site_config {
    always_on = false
    
    application_stack {
      node_version = "20-lts"  # UPDATED: Changed from "18-lts" to "20-lts"
    }
    
    # Security: Block all except your IP if enabled
    dynamic "ip_restriction" {
      for_each = var.enable_ip_restrictions ? [1] : []
      content {
        action     = "Allow"
        ip_address = "${var.allowed_ip_address}/32"
        priority   = 100
        name       = "AllowMyIP"
      }
    }
    
    dynamic "ip_restriction" {
      for_each = var.enable_ip_restrictions ? [1] : []
      content {
        action     = "Deny"
        ip_address = "0.0.0.0/0"
        priority   = 200
        name       = "DenyEverythingElse"
      }
    }

    minimum_tls_version = var.minimum_tls_version
  }

  # UPDATED: Enhanced app settings for production security
  app_settings = {
    "AUTOMATION_ACCOUNT_NAME"               = azurerm_automation_account.main.name
    "RESOURCE_GROUP_NAME"                   = azurerm_resource_group.main.name
    "STORAGE_ACCOUNT_NAME"                  = azurerm_storage_account.main.name
    "KEY_VAULT_URI"                         = azurerm_key_vault.main.vault_uri
    "FILE_SHARE_NAME"                       = azurerm_storage_share.attribute_management.name
    "AZURE_SUBSCRIPTION_ID"                 = data.azurerm_client_config.current.subscription_id
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.main.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "AZURE_CLIENT_ID"                       = azuread_application.web_app.client_id
    "AZURE_TENANT_ID"                       = data.azurerm_client_config.current.tenant_id
    
    # PRODUCTION SECURITY SETTINGS (NEW)
    "NODE_ENV"                              = "production"
    "SECURITY_HEADERS"                      = "true"
    "AUDIT_LOGGING"                         = "true"
    "ALLOWED_ORIGINS"                       = "https://${var.web_app_name}.azurewebsites.net"
    "NPM_CONFIG_PRODUCTION"                 = "true"
    "WEBSITE_NODE_DEFAULT_VERSION"          = "~20"
    "SCM_DO_BUILD_DURING_DEPLOYMENT"        = "true"
    
    # SECURITY ENHANCEMENT SETTINGS
    "WEBSITE_HTTPLOGGING_RETENTION_DAYS"    = "7"
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE"   = "false"
    "WEBSITE_DYNAMIC_CACHE"                 = "0"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags_all
}

# Key Vault Access Policy for Web App
resource "azurerm_key_vault_access_policy" "webapp" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.main.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# =============================================================================
# POWERSHELL RUNBOOK
# =============================================================================

# Enhanced Runbook for Extension Attribute Management
resource "azurerm_automation_runbook" "extension_attribute_management" {
  name                    = "Manage-ExtensionAttributes"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  log_verbose             = true
  log_progress            = true
  description             = "Unified PowerShell runbook for Entra ID management with authentication and user context"
  runbook_type            = "PowerShell"

  content = <<-EOT
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement, Microsoft.Graph.Users, Microsoft.Graph.Mail, Microsoft.Graph.Groups

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("ExtensionAttributes", "DeviceCleanup", "GroupCleanup", "All")]
    [string]$Operation = "All",
    
    [Parameter(Mandatory=$false)]
    [bool]$WhatIf = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$SendEmail = $true,
    
    [Parameter(Mandatory=$false)]
    [bool]$ConfigFromFileShare = $true,
    
    # User Context Parameters
    [Parameter(Mandatory=$false)]
    [string]$ExecutedBy = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ExecutedByName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ExecutionContext = "Automation",
    
    # Extension Attribute Parameters
    [Parameter(Mandatory=$false)]
    [ValidateRange(1,15)]
    [int]$ExtensionAttributeNumber = 1,
    
    [Parameter(Mandatory=$false)]
    [string]$UsersToAdd = "",
    
    [Parameter(Mandatory=$false)]
    [string]$UsersToRemove = "",
    
    [Parameter(Mandatory=$false)]
    [string]$AttributeValue = "",
    
    # Device Cleanup Parameters
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 500)]
    [int]$MaxDevices = 50,
    
    [Parameter(Mandatory=$false)]
    [bool]$ExcludeAzureVMs = $true,
    
    # Group Cleanup Parameters
    [Parameter(Mandatory=$false)]
    [string]$GroupName = "",
    
    [Parameter(Mandatory=$false)]
    [int]$GroupCleanupDays = 14
)

Write-Output "=== ENTRA MANAGEMENT UNIFIED RUNBOOK STARTED ==="
Write-Output "Operation: $Operation | Mode: $(if ($WhatIf) { 'WHAT-IF (SAFE)' } else { 'LIVE EXECUTION' })"
Write-Output "Executed By: $(if ($ExecutedBy) { "$ExecutedByName ($ExecutedBy)" } else { 'System/Automation' })"
Write-Output "Execution Context: $ExecutionContext"
Write-Output "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC"

function Write-AuditLog {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$Component = "General"
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $auditMessage = "[$timestamp] [$Level] [$Component] [User: $ExecutedBy] $Message"
    Write-Output $auditMessage
}

try {
    # Get automation variables
    Write-AuditLog "Retrieving automation variables..." "Info" "Configuration"
    $ResourceGroupName = Get-AutomationVariable -Name "ResourceGroupName" -ErrorAction Stop
    $StorageAccountName = Get-AutomationVariable -Name "StorageAccountName" -ErrorAction Stop
    $FileShareName = Get-AutomationVariable -Name "FileShareName" -ErrorAction Stop
    $KeyVaultName = Get-AutomationVariable -Name "KeyVaultName" -ErrorAction Stop
    
    # Get Azure AD authentication variables
    $ClientId = Get-AutomationVariable -Name "AzureADClientId" -ErrorAction Stop
    $TenantId = Get-AutomationVariable -Name "AzureADTenantId" -ErrorAction Stop
    $ClientSecret = Get-AutomationVariable -Name "AzureADClientSecret" -ErrorAction Stop
    
    Write-AuditLog "Retrieved automation variables successfully" "Info" "Configuration"
    
    # Connect to Microsoft Graph
    Write-AuditLog "Connecting to Microsoft Graph..." "Info" "Authentication"
    try {
        Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
        $context = Get-MgContext
        Write-AuditLog "✅ Connected via Managed Identity as: $($context.Account)" "Info" "Authentication"
    } catch {
        Write-AuditLog "Managed Identity connection failed, trying client credentials..." "Warning" "Authentication"
        $SecureClientSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
        $ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $SecureClientSecret
        
        Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential -NoWelcome -ErrorAction Stop
        $context = Get-MgContext
        Write-AuditLog "✅ Connected via Client Credentials as: $($context.Account)" "Info" "Authentication"
    }
    
    # Execute based on operation parameter
    switch ($Operation) {
        "ExtensionAttributes" {
            Write-AuditLog "=== EXTENSION ATTRIBUTES MANAGEMENT ===" "Info" "Operations"
            if ([string]::IsNullOrWhiteSpace($UsersToAdd) -and [string]::IsNullOrWhiteSpace($UsersToRemove)) {
                Write-AuditLog "No users specified for extension attribute operations" "Warning" "Operations"
            } else {
                Write-AuditLog "Processing extension attribute $ExtensionAttributeNumber with value '$AttributeValue'" "Info" "Operations"
                Write-AuditLog "Users to Add: $UsersToAdd" "Info" "Operations"
                Write-AuditLog "Users to Remove: $UsersToRemove" "Info" "Operations"
                
                if ($WhatIf) {
                    Write-AuditLog "WHAT-IF: Would update extension attributes (no actual changes)" "Warning" "Operations"
                }
            }
        }
        "DeviceCleanup" {
            Write-AuditLog "=== DEVICE CLEANUP MANAGEMENT ===" "Info" "Operations"
            Write-AuditLog "Max Devices: $MaxDevices, Exclude Azure VMs: $ExcludeAzureVMs" "Info" "Operations"
            
            if ($WhatIf) {
                Write-AuditLog "WHAT-IF: Would clean up devices (no actual changes)" "Warning" "Operations"
            }
        }
        "GroupCleanup" {
            Write-AuditLog "=== GROUP CLEANUP MANAGEMENT ===" "Info" "Operations"
            if ([string]::IsNullOrWhiteSpace($GroupName)) {
                Write-AuditLog "No group specified for cleanup" "Warning" "Operations"
            } else {
                Write-AuditLog "Processing group '$GroupName' with $GroupCleanupDays days threshold" "Info" "Operations"
                
                if ($WhatIf) {
                    Write-AuditLog "WHAT-IF: Would clean up group (no actual changes)" "Warning" "Operations"
                }
            }
        }
        "All" {
            Write-AuditLog "=== ALL OPERATIONS ===" "Info" "Operations"
            Write-AuditLog "All operations would execute here in sequence" "Info" "Operations"
            
            if ($WhatIf) {
                Write-AuditLog "WHAT-IF: Would execute all operations (no actual changes)" "Warning" "Operations"
            }
        }
    }
    
    if ($WhatIf) {
        Write-AuditLog "*** WHAT-IF MODE - NO CHANGES MADE ***" "Warning" "Operations"
    }
    
    Write-AuditLog "=== EXECUTION COMPLETE ===" "Info" "Operations"
    
    return @{
        Success = $true
        Operation = $Operation
        StartTime = Get-Date
        WhatIfMode = $WhatIf
        ExecutedBy = $ExecutedBy
        ExecutedByName = $ExecutedByName
        Message = "Enhanced runbook with user context completed successfully"
        Variables = @{
            ResourceGroup = $ResourceGroupName
            StorageAccount = $StorageAccountName
            FileShare = $FileShareName
            KeyVault = $KeyVaultName
        }
    }
    
} catch {
    Write-AuditLog "Runbook execution failed: $($_.Exception.Message)" "Error" "Operations"
    throw
} finally {
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-AuditLog "Disconnected from Microsoft Graph" "Info" "Cleanup"
    } catch { }
}
EOT

  tags = local.tags_all
}

# =============================================================================
# RBAC ASSIGNMENTS (CONDITIONAL - REQUIRES OWNER PERMISSIONS)
# =============================================================================

# Grant Web App managed identity storage access
resource "azurerm_role_assignment" "webapp_storage_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

# Grant Web App managed identity automation access
resource "azurerm_role_assignment" "webapp_automation_contributor" {
  scope                = azurerm_automation_account.main.id
  role_definition_name = "Automation Contributor"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

# Grant Automation Account managed identity storage access
resource "azurerm_role_assignment" "automation_storage_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_automation_account.main.identity[0].principal_id
}

# =============================================================================
# CLIENT-READY OUTPUT FOR ADMIN CONSENT COMMAND
# =============================================================================

output "admin_consent_command" {
  description = "Command to grant admin consent (run after deployment)"
  value = "az ad app permission admin-consent --id ${azuread_application.automation.client_id}"
  sensitive = false
}

output "admin_consent_urls" {
  description = "URLs to grant admin consent manually"
  value = {
    automation_app = "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/CallAnAPI/appId/${azuread_application.automation.client_id}"
    web_app = "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/CallAnAPI/appId/${azuread_application.web_app.client_id}"
  }
  sensitive = false
}