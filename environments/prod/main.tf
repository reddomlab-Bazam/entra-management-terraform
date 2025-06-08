# =============================================================================
# ENTRA MANAGEMENT CONSOLE - PRODUCTION ENVIRONMENT
# =============================================================================

# Data source for current Azure configuration
data "azurerm_client_config" "current" {}

# Create Azure AD application instead of using data source
resource "azuread_application" "web_app" {
  display_name = var.web_app_name
  
  web {
    homepage_url  = "https://${var.web_app_name}.azurewebsites.net"
    redirect_uris = ["https://${var.web_app_name}.azurewebsites.net/.auth/login/aad/callback"]
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }

  tags = ["terraform", "entra-management"]
}

# Generate a random password if client secret is not provided
resource "random_password" "web_app_client_secret" {
  count   = var.web_app_client_secret == null ? 1 : 0
  length  = 32
  special = true
}

locals {
  web_app_client_secret = var.web_app_client_secret != null ? var.web_app_client_secret : random_password.web_app_client_secret[0].result
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = local.tags_all
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.environment}-${var.location_code}-entra-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                = "PerGB2018"
  retention_in_days   = 30

  tags = local.tags_all
}

# Storage Module
module "storage" {
  source = "../../modules/storage"

  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  storage_account_name     = var.storage_account_name
  file_share_name         = var.file_share_name
  file_share_quota_gb     = var.file_share_quota_gb
  storage_replication_type = var.storage_replication_type
  tags                    = local.tags_all
}

# Web App Module
module "webapp" {
  source = "../../modules/webapp"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  web_app_name              = var.web_app_name
  app_service_plan_name     = var.app_service_plan_name
  app_service_plan_sku      = var.app_service_plan_sku
  web_app_client_id         = azuread_application.web_app.client_id
  web_app_client_secret     = local.web_app_client_secret
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  enable_ip_restrictions    = var.enable_ip_restrictions
  allowed_ip_address        = var.allowed_ip_address
  application_insights_type = var.application_insights_type
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                      = local.tags_all
}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name           = "standard"

  purge_protection_enabled   = true
  soft_delete_retention_days = 90

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.enable_ip_restrictions && var.allowed_ip_address != null ? [var.allowed_ip_address] : []
  }

  tags = local.tags_all
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
    "Purge",
    "Recover"
  ]
}

resource "azurerm_key_vault_access_policy" "webapp" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.webapp.web_app_identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Store sensitive values in Key Vault
resource "azurerm_key_vault_secret" "storage_key" {
  name         = "storage-account-key"
  value        = module.storage.storage_account_primary_access_key
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "webapp_client_secret" {
  name         = "webapp-client-secret"
  value        = local.web_app_client_secret
  key_vault_id = azurerm_key_vault.main.id
} 