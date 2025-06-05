# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "Lab"
    Purpose     = "Entra Extension Attribute Management"
    CreatedBy   = "Terraform"
  }
}

# Storage Account
resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type
  
  tags = {
    Environment = "Lab"
    Purpose     = "File Storage for Extension Attribute Management"
  }
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

# Data source for current Azure configuration
data "azurerm_client_config" "current" {}

# Automation Account
resource "azurerm_automation_account" "main" {
  name                = var.automation_account_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = var.automation_sku

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Lab"
    Purpose     = "Extension Attribute Management"
  }
}

# Automation Variables - Original set
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

# Automation Variables - Enhanced set for PowerShell script
resource "azurerm_automation_variable_string" "from_email" {
  name                    = "EntraMgmt_FromEmail"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = "automation@lab.local"
  description             = "From email address for notifications"
}

resource "azurerm_automation_variable_string" "to_email" {
  name                    = "EntraMgmt_ToEmail"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = "admin@lab.local"
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

# Key Vault
resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  purge_protection_enabled = false

  tags = {
    Environment = "Lab"
    Purpose     = "Secret Management for Extension Attributes"
  }
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
}

# Update Automation Variable for Key Vault
resource "azurerm_automation_variable_string" "key_vault" {
  name                    = "KeyVaultName"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = azurerm_key_vault.main.name
  description             = "Key vault name"
}

# Application Insights - Fixed with workspace_id
resource "azurerm_application_insights" "main" {
  name                = "${var.web_app_name}-insights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = var.application_insights_type
  workspace_id        = azurerm_log_analytics_workspace.main.id
  
  tags = var.common_tags
}

# Log Analytics Workspace (required for Application Insights)
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.web_app_name}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.common_tags
}

# App Service Plan - Fixed to prevent replacement
resource "azurerm_service_plan" "main" {
  name                = "lab-uks-entra-webapp-plan"  # Use exact existing name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "F1"  # Keep existing SKU

  # Prevent replacement during updates
  lifecycle {
    ignore_changes = [tags]
  }

  tags = {
    Environment = "Lab"
    Purpose     = "Web Interface for Extension Attribute Management"
  }
}

# Linux Web App
resource "azurerm_linux_web_app" "main" {
  name                = var.web_app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id
  https_only          = true

site_config {
  always_on = false
  
  application_stack {
    node_version = "18-lts"
  }
  
  # Security: Block all except your IP
  ip_restriction {
    action     = "Allow"
    ip_address = "${var.allowed_ip_address}/32"
    priority   = 100
    name       = "AllowMyIP"
  }
  
  ip_restriction {
    action     = "Deny"
    ip_address = "0.0.0.0/0"
    priority   = 200
    name       = "DenyEverythingElse"
  }
}

  app_settings = {
    "AUTOMATION_ACCOUNT_NAME"               = azurerm_automation_account.main.name
    "RESOURCE_GROUP_NAME"                   = azurerm_resource_group.main.name
    "STORAGE_ACCOUNT_NAME"                  = azurerm_storage_account.main.name
    "KEY_VAULT_URI"                         = azurerm_key_vault.main.vault_uri
    "FILE_SHARE_NAME"                       = azurerm_storage_share.attribute_management.name
    "AZURE_SUBSCRIPTION_ID"                 = data.azurerm_client_config.current.subscription_id
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.main.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Lab"
    Purpose     = "Web Interface for Extension Attribute Management"
  }
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

# Enhanced Runbook for Extension Attribute Management
resource "azurerm_automation_runbook" "extension_attribute_management" {
  name                    = "Manage-ExtensionAttributes"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  log_verbose             = true
  log_progress            = true
  description             = "Unified PowerShell runbook for Entra ID management - Extension Attributes, Device Cleanup, and Group Management"
  runbook_type            = "PowerShell"

  content = <<-EOT
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.DeviceManagement, Microsoft.Graph.Users, Microsoft.Graph.Mail, Microsoft.Graph.Groups

<#
.SYNOPSIS
    Unified Entra Management PowerShell Runbook
.DESCRIPTION
    Combined runbook for Extension Attributes, Device Cleanup, and Group Membership Management.
    Supports all three core functions in a single script for centralized management.
.PARAMETER Operation
    The operation to perform: ExtensionAttributes, DeviceCleanup, GroupCleanup, or All
.PARAMETER WhatIf
    Run in preview mode (no changes made)
.PARAMETER SendEmail
    Send email report after execution
.PARAMETER ConfigFromFileShare
    Read configuration from Azure File Share
#>

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

# =============================================================================
# GLOBAL CONFIGURATION
# =============================================================================

Write-Output "=== ENTRA MANAGEMENT UNIFIED RUNBOOK STARTED ==="
Write-Output "Operation: $Operation | Mode: $(if ($WhatIf) { 'WHAT-IF (SAFE)' } else { 'LIVE EXECUTION' })"
Write-Output "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC"

try {
    # Get automation variables
    $ResourceGroupName = Get-AutomationVariable -Name "ResourceGroupName" -ErrorAction Stop
    $StorageAccountName = Get-AutomationVariable -Name "StorageAccountName" -ErrorAction Stop
    $FileShareName = Get-AutomationVariable -Name "FileShareName" -ErrorAction Stop
    $KeyVaultName = Get-AutomationVariable -Name "KeyVaultName" -ErrorAction Stop
    
    Write-Output "Retrieved automation variables:"
    Write-Output "  Resource Group: $ResourceGroupName"
    Write-Output "  Storage Account: $StorageAccountName"
    Write-Output "  File Share: $FileShareName"
    Write-Output "  Key Vault: $KeyVaultName"
    
    # Connect to Microsoft Graph
    Write-Output "Connecting to Microsoft Graph..."
    Connect-MgGraph -Identity -NoWelcome -ErrorAction Stop
    
    $context = Get-MgContext
    Write-Output "Connected as: $($context.Account)"
    
    # Execute based on operation parameter
    switch ($Operation) {
        "ExtensionAttributes" {
            Write-Output "=== EXTENSION ATTRIBUTES MANAGEMENT ==="
            if ([string]::IsNullOrWhiteSpace($UsersToAdd) -and [string]::IsNullOrWhiteSpace($UsersToRemove)) {
                Write-Output "No users specified for extension attribute operations"
            } else {
                Write-Output "Extension Attribute Management would execute here"
                Write-Output "Attribute: extensionAttribute$ExtensionAttributeNumber"
                Write-Output "Value: '$AttributeValue'"
                Write-Output "Users to Add: $UsersToAdd"
                Write-Output "Users to Remove: $UsersToRemove"
            }
        }
        "DeviceCleanup" {
            Write-Output "=== DEVICE CLEANUP MANAGEMENT ==="
            Write-Output "Device cleanup would execute here"
            Write-Output "Max Devices: $MaxDevices"
            Write-Output "Exclude Azure VMs: $ExcludeAzureVMs"
        }
        "GroupCleanup" {
            Write-Output "=== GROUP CLEANUP MANAGEMENT ==="
            if ([string]::IsNullOrWhiteSpace($GroupName)) {
                Write-Output "No group specified for cleanup"
            } else {
                Write-Output "Group cleanup would execute here"
                Write-Output "Group Name: $GroupName"
                Write-Output "Cleanup Days: $GroupCleanupDays"
            }
        }
        "All" {
            Write-Output "=== ALL OPERATIONS ==="
            Write-Output "All operations would execute here in sequence"
        }
    }
    
    if ($WhatIf) {
        Write-Warning "*** WHAT-IF MODE - NO CHANGES MADE ***"
    }
    
    Write-Output "=== EXECUTION COMPLETE ==="
    
    # Return results
    return @{
        Success = $true
        Operation = $Operation
        StartTime = Get-Date
        WhatIfMode = $WhatIf
        Message = "Basic runbook test completed successfully"
        Variables = @{
            ResourceGroup = $ResourceGroupName
            StorageAccount = $StorageAccountName
            FileShare = $FileShareName
            KeyVault = $KeyVaultName
        }
    }
}
catch {
    Write-Error "Runbook execution failed: $($_.Exception.Message)"
    throw
}
finally {
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Output "Disconnected from Microsoft Graph"
    } catch { }
}
EOT

  tags = {
    Environment = "Lab"
    Purpose     = "Extension Attribute Management"
  }
}