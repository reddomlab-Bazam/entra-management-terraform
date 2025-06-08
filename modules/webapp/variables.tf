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

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
} 