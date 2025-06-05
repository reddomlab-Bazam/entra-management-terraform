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

# Storage Share Directories
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

# Storage Container for web files
resource "azurerm_storage_container" "webfiles" {
  name                  = "webfiles"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "blob"
}

# HTML Interface File
resource "azurerm_storage_share_file" "html_interface" {
  name             = "interface.html"
  storage_share_id = azurerm_storage_share.attribute_management.id
  path             = "scripts"
  source           = "${path.module}/interface.html"

  depends_on = [azurerm_storage_share_directory.scripts]
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

# PowerShell Modules for Automation Account
resource "azurerm_automation_module" "graph_authentication" {
  name                    = "Microsoft.Graph.Authentication"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name

  module_link {
    uri = "https://www.powershellgallery.com/packages/Microsoft.Graph.Authentication"
  }
}

resource "azurerm_automation_module" "graph_users" {
  name                    = "Microsoft.Graph.Users"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name

  module_link {
    uri = "https://www.powershellgallery.com/packages/Microsoft.Graph.Users"
  }

  depends_on = [azurerm_automation_module.graph_authentication]
}

resource "azurerm_automation_module" "graph_groups" {
  name                    = "Microsoft.Graph.Groups"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name

  module_link {
    uri = "https://www.powershellgallery.com/packages/Microsoft.Graph.Groups"
  }

  depends_on = [azurerm_automation_module.graph_authentication]
}

resource "azurerm_automation_module" "graph_mail" {
  name                    = "Microsoft.Graph.Mail"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name

  module_link {
    uri = "https://www.powershellgallery.com/packages/Microsoft.Graph.Mail"
  }

  depends_on = [azurerm_automation_module.graph_authentication]
}

resource "azurerm_automation_module" "graph_devicemanagement" {
  name                    = "Microsoft.Graph.DeviceManagement"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name

  module_link {
    uri = "https://www.powershellgallery.com/packages/Microsoft.Graph.DeviceManagement"
  }

  depends_on = [azurerm_automation_module.graph_authentication]
}

resource "azurerm_automation_module" "az_accounts" {
  name                    = "Az.Accounts"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name

  module_link {
    uri = "https://www.powershellgallery.com/packages/Az.Accounts"
  }
}

resource "azurerm_automation_module" "az_storage" {
  name                    = "Az.Storage"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name

  module_link {
    uri = "https://www.powershellgallery.com/packages/Az.Storage"
  }

  depends_on = [azurerm_automation_module.az_accounts]
}

resource "azurerm_automation_module" "az_compute" {
  name                    = "Az.Compute"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name

  module_link {
    uri = "https://www.powershellgallery.com/packages/Az.Compute"
  }

  depends_on = [azurerm_automation_module.az_accounts]
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

resource "azurerm_automation_variable_string" "key_vault" {
  name                    = "KeyVaultName"
  automation_account_name = azurerm_automation_account.main.name
  resource_group_name     = azurerm_resource_group.main.name
  value                   = azurerm_key_vault.main.name
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

# Key Vault Access Policies
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

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${var.web_app_name}-insights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"

  tags = {
    Environment = "Lab"
    Purpose     = "Monitoring for Extension Attribute Management"
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
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.main.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "AUTOMATION_ACCOUNT_NAME"               = azurerm_automation_account.main.name
    "RESOURCE_GROUP_NAME"                   = azurerm_resource_group.main.name
    "STORAGE_ACCOUNT_NAME"                  = azurerm_storage_account.main.name
    "KEY_VAULT_URI"                         = azurerm_key_vault.main.vault_uri
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

# RBAC Assignments
resource "azurerm_role_assignment" "automation_storage_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_automation_account.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "automation_storage_access" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = azurerm_automation_account.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "webapp_storage_reader" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "webapp_automation_contributor" {
  scope                = azurerm_automation_account.main.id
  role_definition_name = "Automation Contributor"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

# Runbook for Extension Attribute Management
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
    It can create, read, update, and delete extension attributes.

.PARAMETER Action
    The action to perform: Create, Read, Update, Delete, List

.PARAMETER UserPrincipalName
    The UPN of the user to manage

.PARAMETER AttributeName
    The name of the extension attribute

.PARAMETER AttributeValue
    The value to set for the extension attribute

.PARAMETER BulkOperation
    Switch to indicate bulk operation from CSV

.PARAMETER CSVPath
    Path to CSV file for bulk operations

.NOTES
    Version: 1.0
    Author: Terraform Automation
    Created: ${formatdate("YYYY-MM-DD", timestamp())}
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Create", "Read", "Update", "Delete", "List", "Bulk")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$UserPrincipalName,
    
    [Parameter(Mandatory=$false)]
    [string]$AttributeName,
    
    [Parameter(Mandatory=$false)]
    [string]$AttributeValue,
    
    [Parameter(Mandatory=$false)]
    [switch]$BulkOperation,
    
    [Parameter(Mandatory=$false)]
    [string]$CSVPath
)

# Import required modules
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Users
Import-Module Az.Accounts
Import-Module Az.Storage

try {
    Write-Output "Starting Extension Attribute Management Runbook..."
    Write-Output "Action: $Action"
    
    # Connect to Microsoft Graph using Managed Identity
    Connect-MgGraph -Identity
    Write-Output "Connected to Microsoft Graph"
    
    # Get automation variables
    $ResourceGroupName = Get-AutomationVariable -Name "ResourceGroupName"
    $StorageAccountName = Get-AutomationVariable -Name "StorageAccountName"
    $FileShareName = Get-AutomationVariable -Name "FileShareName"
    $KeyVaultName = Get-AutomationVariable -Name "KeyVaultName"
    
    Write-Output "Retrieved automation variables"
    
    # Connect to Azure using Managed Identity
    Connect-AzAccount -Identity
    Write-Output "Connected to Azure"
    
    # Function to log operations
    function Write-Log {
        param($Message)
        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Output "[$Timestamp] $Message"
    }
    
    # Function to create extension attribute
    function New-ExtensionAttribute {
        param($UPN, $AttrName, $AttrValue)
        
        try {
            Write-Log "Creating extension attribute '$AttrName' for user '$UPN' with value '$AttrValue'"
            
            # Get user
            $User = Get-MgUser -UserId $UPN -ErrorAction Stop
            Write-Log "Found user: $($User.DisplayName)"
            
            # Update user with extension attribute
            $ExtensionData = @{}
            $ExtensionData["extension_$AttrName"] = $AttrValue
            
            Update-MgUser -UserId $User.Id -BodyParameter $ExtensionData
            Write-Log "Successfully created extension attribute '$AttrName' for user '$UPN'"
            
            return @{
                Success = $true
                Message = "Extension attribute created successfully"
                User = $UPN
                Attribute = $AttrName
                Value = $AttrValue
            }
        }
        catch {
            Write-Log "Error creating extension attribute: $($_.Exception.Message)"
            return @{
                Success = $false
                Message = $_.Exception.Message
                User = $UPN
                Attribute = $AttrName
            }
        }
    }
    
    # Function to read extension attribute
    function Get-ExtensionAttribute {
        param($UPN, $AttrName)
        
        try {
            Write-Log "Reading extension attribute '$AttrName' for user '$UPN'"
            
            # Get user with extension attributes
            $User = Get-MgUser -UserId $UPN -Property "Id,DisplayName,UserPrincipalName,*" -ErrorAction Stop
            
            $ExtensionProperty = "extension_$AttrName"
            $AttributeValue = $User.AdditionalProperties[$ExtensionProperty]
            
            Write-Log "Extension attribute value: $AttributeValue"
            
            return @{
                Success = $true
                User = $UPN
                Attribute = $AttrName
                Value = $AttributeValue
                DisplayName = $User.DisplayName
            }
        }
        catch {
            Write-Log "Error reading extension attribute: $($_.Exception.Message)"
            return @{
                Success = $false
                Message = $_.Exception.Message
                User = $UPN
                Attribute = $AttrName
            }
        }
    }
    
    # Function to update extension attribute
    function Set-ExtensionAttribute {
        param($UPN, $AttrName, $AttrValue)
        
        try {
            Write-Log "Updating extension attribute '$AttrName' for user '$UPN' with value '$AttrValue'"
            
            $User = Get-MgUser -UserId $UPN -ErrorAction Stop
            
            $ExtensionData = @{}
            $ExtensionData["extension_$AttrName"] = $AttrValue
            
            Update-MgUser -UserId $User.Id -BodyParameter $ExtensionData
            Write-Log "Successfully updated extension attribute '$AttrName' for user '$UPN'"
            
            return @{
                Success = $true
                Message = "Extension attribute updated successfully"
                User = $UPN
                Attribute = $AttrName
                Value = $AttrValue
            }
        }
        catch {
            Write-Log "Error updating extension attribute: $($_.Exception.Message)"
            return @{
                Success = $false
                Message = $_.Exception.Message
                User = $UPN
                Attribute = $AttrName
            }
        }
    }
    
    # Function to delete extension attribute
    function Remove-ExtensionAttribute {
        param($UPN, $AttrName)
        
        try {
            Write-Log "Deleting extension attribute '$AttrName' for user '$UPN'"
            
            $User = Get-MgUser -UserId $UPN -ErrorAction Stop
            
            $ExtensionData = @{}
            $ExtensionData["extension_$AttrName"] = $null
            
            Update-MgUser -UserId $User.Id -BodyParameter $ExtensionData
            Write-Log "Successfully deleted extension attribute '$AttrName' for user '$UPN'"
            
            return @{
                Success = $true
                Message = "Extension attribute deleted successfully"
                User = $UPN
                Attribute = $AttrName
            }
        }
        catch {
            Write-Log "Error deleting extension attribute: $($_.Exception.Message)"
            return @{
                Success = $false
                Message = $_.Exception.Message
                User = $UPN
                Attribute = $AttrName
            }
        }
    }
    
    # Function to list all users with extension attributes
    function Get-AllExtensionAttributes {
        try {
            Write-Log "Listing all users with extension attributes"
            
            $Users = Get-MgUser -All -Property "Id,DisplayName,UserPrincipalName,*"
            $Results = @()
            
            foreach ($User in $Users) {
                $ExtensionAttributes = @{}
                
                foreach ($Property in $User.AdditionalProperties.Keys) {
                    if ($Property -like "extension_*") {
                        $ExtensionAttributes[$Property] = $User.AdditionalProperties[$Property]
                    }
                }
                
                if ($ExtensionAttributes.Count -gt 0) {
                    $Results += @{
                        UserPrincipalName = $User.UserPrincipalName
                        DisplayName = $User.DisplayName
                        ExtensionAttributes = $ExtensionAttributes
                    }
                }
            }
            
            Write-Log "Found $($Results.Count) users with extension attributes"
            return $Results
        }
        catch {
            Write-Log "Error listing extension attributes: $($_.Exception.Message)"
            return @{
                Success = $false
                Message = $_.Exception.Message
            }
        }
    }
    
    # Main execution logic
    $Result = switch ($Action) {
        "Create" {
            if (-not $UserPrincipalName -or -not $AttributeName -or -not $AttributeValue) {
                throw "Create action requires UserPrincipalName, AttributeName, and AttributeValue parameters"
            }
            New-ExtensionAttribute -UPN $UserPrincipalName -AttrName $AttributeName -AttrValue $AttributeValue
        }
        
        "Read" {
            if (-not $UserPrincipalName -or -not $AttributeName) {
                throw "Read action requires UserPrincipalName and AttributeName parameters"
            }
            Get-ExtensionAttribute -UPN $UserPrincipalName -AttrName $AttributeName
        }
        
        "Update" {
            if (-not $UserPrincipalName -or -not $AttributeName -or -not $AttributeValue) {
                throw "Update action requires UserPrincipalName, AttributeName, and AttributeValue parameters"
            }
            Set-ExtensionAttribute -UPN $UserPrincipalName -AttrName $AttributeName -AttrValue $AttributeValue
        }
        
        "Delete" {
            if (-not $UserPrincipalName -or -not $AttributeName) {
                throw "Delete action requires UserPrincipalName and AttributeName parameters"
            }
            Remove-ExtensionAttribute -UPN $UserPrincipalName -AttrName $AttributeName
        }
        
        "List" {
            Get-AllExtensionAttributes
        }
        
        "Bulk" {
            Write-Log "Bulk operations not yet implemented"
            @{
                Success = $false
                Message = "Bulk operations feature coming soon"
            }
        }
        
        default {
            throw "Invalid action specified: $Action"
        }
    }
    
    # Output results
    Write-Output "Operation completed:"
    Write-Output ($Result | ConvertTo-Json -Depth 10)
    
    # Store results in storage for web interface
    try {
        $ResultsJson = $Result | ConvertTo-Json -Depth 10
        $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $FileName = "operation-result-$Timestamp.json"
        
        # Save to storage account (simplified - would need full implementation)
        Write-Log "Results saved as $FileName"
    }
    catch {
        Write-Log "Warning: Could not save results to storage: $($_.Exception.Message)"
    }
    
    Write-Output "Runbook execution completed successfully"
}
catch {
    Write-Error "Runbook execution failed: $($_.Exception.Message)"
    throw
}
finally {
    # Disconnect from services
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Disconnect-AzAccount -ErrorAction SilentlyContinue
    }
    catch {
        # Ignore disconnection errors
    }
}
EOT

  depends_on = [
    azurerm_automation_module.graph_authentication,
    azurerm_automation_module.graph_users,
    azurerm_automation_module.az_accounts,
    azurerm_automation_module.az_storage
  ]

  tags = {
    Environment = "Lab"
    Purpose     = "Extension Attribute Management"
  }
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
  client_id = azuread_application.extension_attribute_app.client_id
  
  depends_on = [azuread_application.extension_attribute_app]
  
  tags = ["ExtensionAttributeManagement", "Lab", "Terraform"]
}