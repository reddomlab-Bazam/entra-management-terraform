# =============================================================================
# WEBAPP MODULE OUTPUTS
# =============================================================================

output "web_app_id" {
  description = "ID of the web application"
  value       = azurerm_linux_web_app.main.id
}

output "web_app_name" {
  description = "Name of the web application"
  value       = azurerm_linux_web_app.main.name
}

output "web_app_default_hostname" {
  description = "Default hostname of the web application"
  value       = azurerm_linux_web_app.main.default_hostname
}

output "web_app_identity" {
  description = "Managed identity of the web application"
  value       = azurerm_linux_web_app.main.identity
}

output "app_service_plan_id" {
  description = "ID of the App Service Plan"
  value       = azurerm_service_plan.main.id
}

output "app_insights_id" {
  description = "ID of the Application Insights instance"
  value       = azurerm_application_insights.main.id
}

output "app_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "app_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
} 