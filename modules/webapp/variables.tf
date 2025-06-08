# =============================================================================
# WEBAPP MODULE VARIABLES
# =============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "web_app_name" {
  description = "Name of the web application"
  type        = string
}

variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
}

variable "app_service_plan_sku" {
  description = "SKU for the App Service Plan"
  type        = string
  default     = "F1"
  
  validation {
    condition     = contains(["F1", "D1", "B1", "B2", "B3", "S1", "S2", "S3", "P1v2", "P2v2", "P3v2"], var.app_service_plan_sku)
    error_message = "App Service Plan SKU must be a valid SKU."
  }
}

variable "web_app_client_id" {
  description = "Client ID of the web application for Entra ID authentication"
  type        = string
}

variable "web_app_client_secret" {
  description = "Client secret of the web application"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
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
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  type        = string
}

variable "app_insights_key" {
  description = "Application Insights instrumentation key"
  type        = string
  default     = null
}

variable "app_insights_connection_string" {
  description = "Application Insights connection string"
  type        = string
  default     = null
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "automation_account_name" {
  description = "Name of the Azure Automation Account (optional)"
  type        = string
  default     = null
}

variable "key_vault_uri" {
  description = "URI of the Key Vault"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
} 