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
  account_replication_type = "LRS"
  
  tags = {
    Environment = "Lab"
    Purpose     = "File Storage for Extension Attribute Management"
  }
}

# File Share for storing scripts and data
resource "azurerm_storage_share" "attribute_management" {
  name                 = "entra-management"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 50
}

# Storage Share Directories - Updated syntax
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
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Lab"
    Purpose     = "Extension Attribute Management"
  }
}

# Automation Variables
resource "azurerm_automation_variable_string" "resource_group" {
  name                    = "ResourceGroupName"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = azurerm_resource_group.main.name
}

resource "azurerm_automation_variable_string" "storage_account" {
  name                    = "StorageAccountName"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = azurerm_storage_account.main.name
}

resource "azurerm_automation_variable_string" "file_share" {
  name                    = "FileShareName"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = azurerm_storage_share.attribute_management.name
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
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = "${var.web_app_name}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "F1"

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
  }

  app_settings = {
    "AUTOMATION_ACCOUNT_NAME" = azurerm_automation_account.main.name
    "RESOURCE_GROUP_NAME"     = azurerm_resource_group.main.name
    "STORAGE_ACCOUNT_NAME"    = azurerm_storage_account.main.name
    "KEY_VAULT_URI"           = azurerm_key_vault.main.vault_uri
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

# Basic Runbook for Extension Attribute Management
resource "azurerm_automation_runbook" "extension_attribute_management" {
  name                    = "Manage-ExtensionAttributes"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  automation_account_name = azurerm_automation_account.main.name
  log_verbose             = true
  log_progress            = true
  description             = "PowerShell runbook to manage Entra ID extension attributes"
  runbook_type            = "PowerShell"

  content = <<-EOT
<#
.SYNOPSIS
    Manage Entra ID Extension Attributes

.DESCRIPTION
    This runbook manages extension attributes for users in Entra ID (Azure AD).
    Basic version without modules (to be added later manually).

.PARAMETER Action
    The action to perform: Test, List

.NOTES
    Version: 1.0 (Basic)
    Author: Terraform Automation
    Created: ${formatdate("YYYY-MM-DD", timestamp())}
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Test", "List")]
    [string]$Action = "Test"
)

try {
    Write-Output "Starting Extension Attribute Management Runbook (Basic Version)..."
    Write-Output "Action: $Action"
    
    # Get automation variables
    $ResourceGroupName = Get-AutomationVariable -Name "ResourceGroupName"
    $StorageAccountName = Get-AutomationVariable -Name "StorageAccountName"
    $FileShareName = Get-AutomationVariable -Name "FileShareName"
    $KeyVaultName = Get-AutomationVariable -Name "KeyVaultName"
    
    Write-Output "Retrieved automation variables:"
    Write-Output "  Resource Group: $ResourceGroupName"
    Write-Output "  Storage Account: $StorageAccountName"
    Write-Output "  File Share: $FileShareName"
    Write-Output "  Key Vault: $KeyVaultName"
    
    switch ($Action) {
        "Test" {
            Write-Output "Test completed successfully!"
            return @{
                Success = $true
                Message = "Basic runbook test completed"
                Variables = @{
                    ResourceGroup = $ResourceGroupName
                    StorageAccount = $StorageAccountName
                    FileShare = $FileShareName
                    KeyVault = $KeyVaultName
                }
            }
        }
        
        "List" {
            Write-Output "List function placeholder - requires Graph modules to be installed manually"
            return @{
                Success = $false
                Message = "Graph modules need to be installed manually first"
            }
        }
        
        default {
            throw "Invalid action specified: $Action"
        }
    }
}
catch {
    Write-Error "Runbook execution failed: $($_.Exception.Message)"
    throw
}
EOT

  tags = {
    Environment = "Lab"
    Purpose     = "Extension Attribute Management"
  }
}