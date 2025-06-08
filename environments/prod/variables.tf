# =============================================================================
# PRODUCTION ENVIRONMENT VARIABLES
# =============================================================================

variable "environment" {
  description = "Environment name (e.g., prod, dev)"
  type        = string
  default     = "prod"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "location_code" {
  description = "Short code for the Azure region"
  type        = string
  default     = "eus"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "entra-management-prod-rg"
}

variable "storage_account_name" {
  description = "Name of the storage account"
  type        = string
  default     = "entramgmtprodst"
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be between 3 and 24 characters long and can only contain lowercase letters and numbers."
  }
}

variable "file_share_name" {
  description = "Name of the file share for configuration and logs"
  type        = string
  default     = "entra-management-files"
}

variable "file_share_quota_gb" {
  description = "File share quota in GB"
  type        = number
  default     = 5
  validation {
    condition     = var.file_share_quota_gb >= 1 && var.file_share_quota_gb <= 102400
    error_message = "File share quota must be between 1 and 102400 GB."
  }
}

variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS"], var.storage_replication_type)
    error_message = "Storage replication type must be one of: LRS, GRS, RAGRS, ZRS."
  }
}

variable "web_app_name" {
  description = "Name of the web application"
  type        = string
  default     = "entra-management-prod"
}

variable "web_app_client_secret" {
  description = "Client secret for the web application. If not provided, it will be generated."
  type        = string
  sensitive   = true
  default     = null
}

variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
  default     = "entra-management-prod-plan"
}

variable "app_service_plan_sku" {
  description = "SKU for the App Service Plan"
  type        = string
  default     = "P1v2"
  validation {
    condition     = contains(["B1", "B2", "B3", "P1v2", "P2v2", "P3v2"], var.app_service_plan_sku)
    error_message = "App Service Plan SKU must be one of: B1, B2, B3, P1v2, P2v2, P3v2."
  }
}

variable "key_vault_name" {
  description = "Name of the Key Vault"
  type        = string
  default     = "entra-management-prod-kv"
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{3,24}$", var.key_vault_name))
    error_message = "Key Vault name must be between 3 and 24 characters long and can only contain letters, numbers, and hyphens."
  }
}

variable "enable_ip_restrictions" {
  description = "Enable IP restrictions for the web application"
  type        = bool
  default     = true
}

variable "allowed_ip_address" {
  description = "Allowed IP address for web app access"
  type        = string
  default     = null
}

variable "application_insights_type" {
  description = "Application type for Application Insights"
  type        = string
  default     = "web"
  validation {
    condition     = contains(["web", "other"], var.application_insights_type)
    error_message = "Application Insights type must be either 'web' or 'other'."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
} 