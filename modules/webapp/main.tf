# =============================================================================
# WEBAPP MODULE - Azure Web App Configuration
# =============================================================================

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = var.app_service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type            = "Linux"
  sku_name           = var.app_service_plan_sku

  tags = var.tags
}

# Linux Web App
resource "azurerm_linux_web_app" "main" {
  name                = var.web_app_name
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    application_stack {
      node_version = "20-lts"
    }

    # Security settings
    http2_enabled = true
    min_tls_version = "1.2"
    
    # IP restrictions if enabled
    dynamic "ip_restriction" {
      for_each = var.enable_ip_restrictions ? [1] : []
      content {
        ip_address = var.allowed_ip_address
        action     = "Allow"
        priority   = 100
        name       = "Allowed IP"
      }
    }
  }

  # Authentication settings
  auth_settings {
    enabled = true
    issuer  = "https://sts.windows.net/${var.tenant_id}/"
    
    active_directory {
      client_id         = var.web_app_client_id
      client_secret     = var.web_app_client_secret
      allowed_audiences = ["api://${var.web_app_client_id}"]
    }

    default_provider = "AzureActiveDirectory"
    unauthenticated_client_action = "RedirectToLoginPage"
  }

  # Application settings
  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "~20"
    "NODE_ENV"                     = "production"
    "AZURE_CLIENT_ID"              = var.web_app_client_id
    "AZURE_TENANT_ID"              = var.tenant_id
    "APPINSIGHTS_INSTRUMENTATIONKEY" = var.app_insights_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = var.app_insights_connection_string
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${var.web_app_name}-insights"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = var.application_insights_type
  workspace_id        = var.log_analytics_workspace_id

  tags = var.tags
} 