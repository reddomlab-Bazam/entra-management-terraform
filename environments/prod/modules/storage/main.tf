# =============================================================================
# STORAGE MODULE - Azure Storage Account and File Share Configuration
# =============================================================================

# Storage Account
resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type
  min_tls_version         = "TLS1_2"
  
  # Use the new property instead of deprecated one
  https_traffic_only_enabled = true
  
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }
  
  tags = var.tags
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
  container_access_type = "private"
} 