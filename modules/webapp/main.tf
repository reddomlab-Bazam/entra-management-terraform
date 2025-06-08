# =============================================================================
# WEBAPP MODULE - Azure Web App Configuration
# =============================================================================

# Storage Account for deployment package
resource "azurerm_storage_account" "deployment" {
  name                     = replace("${var.web_app_name}deploy", "-", "")
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version         = "TLS1_2"

  tags = var.tags
}

resource "azurerm_storage_container" "deployment" {
  name                  = "deployment"
  storage_account_name  = azurerm_storage_account.deployment.name
  container_access_type = "private"
}

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
      node_version = "18-lts"
    }

    always_on = true

    # Only apply IP restrictions if enabled and IP address is provided
    dynamic "ip_restriction" {
      for_each = var.enable_ip_restrictions && var.allowed_ip_address != null ? [1] : []
      content {
        action     = "Allow"
        priority   = 100
        name       = "Allow specific IP"
        ip_address = var.allowed_ip_address
      }
    }
  }

  app_settings = {
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "AZURE_CLIENT_ID"            = var.web_app_client_id
    "AZURE_CLIENT_SECRET"        = var.web_app_client_secret
    "AZURE_TENANT_ID"           = var.tenant_id
    "AZURE_SUBSCRIPTION_ID"      = var.subscription_id
    "RESOURCE_GROUP_NAME"        = var.resource_group_name
    "AUTOMATION_ACCOUNT_NAME"    = var.automation_account_name
    "KEY_VAULT_URI"             = var.key_vault_uri
    "SESSION_TIMEOUT_MINUTES"    = "60"
    "NODE_ENV"                  = "production"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.main.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "WEBSITE_WEBSOCKET_ENABLED" = "1"
    "WEBSITE_HTTPLOGGING_RETENTION_DAYS" = "7"
    "WEBSITE_HTTPLOGGING_ENABLED" = "1"
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
  }

  auth_settings {
    enabled = true
    default_provider = "AzureActiveDirectory"
    active_directory {
      client_id = var.web_app_client_id
      client_secret = var.web_app_client_secret
      allowed_audiences = ["api://${var.web_app_name}"]
    }
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

# Create deployment package
resource "null_resource" "package_app" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../../webapp
      # Clean up any existing zip
      rm -f ../webapp.zip
      # Install production dependencies
      npm install --production
      # Create the zip file
      zip -r ../webapp.zip .
    EOT
  }
}

# Deploy the application using Azure CLI
resource "null_resource" "deploy_app" {
  depends_on = [null_resource.package_app, azurerm_linux_web_app.main]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      az webapp deployment source config-zip \
        --resource-group ${var.resource_group_name} \
        --name ${var.web_app_name} \
        --src ${path.module}/../../webapp.zip
    EOT
  }
} 