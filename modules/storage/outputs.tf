# =============================================================================
# STORAGE MODULE OUTPUTS
# =============================================================================

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_primary_access_key" {
  description = "Primary access key for the storage account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "file_share_id" {
  description = "ID of the file share"
  value       = azurerm_storage_share.attribute_management.id
}

output "file_share_name" {
  description = "Name of the file share"
  value       = azurerm_storage_share.attribute_management.name
}

output "webfiles_container_name" {
  description = "Name of the web files container"
  value       = azurerm_storage_container.webfiles.name
}

output "storage_account_endpoint" {
  description = "Primary endpoint for the storage account"
  value       = azurerm_storage_account.main.primary_blob_endpoint
} 