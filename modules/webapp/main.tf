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

# Create deployment package
resource "null_resource" "package_app" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../../webapp
      npm install --production
      zip -r ../webapp.zip .
    EOT
  }
}

# Upload deployment package
resource "azurerm_storage_blob" "deployment_package" {
  name                   = "webapp.zip"
  storage_account_name   = azurerm_storage_account.deployment.name
  storage_container_name = azurerm_storage_container.deployment.name
  type                  = "Block"
  source                = "${path.module}/../../webapp.zip"
  depends_on            = [null_resource.package_app]
}

# Generate SAS token for deployment package
data "azurerm_storage_account_sas" "deployment" {
  connection_string = azurerm_storage_account.deployment.primary_connection_string
  https_only        = true
  signed_version    = "2019-12-12"

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = timestamp()
  expiry = timeadd(timestamp(), "24h")

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
  }
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
    "WEBSITE_RUN_FROM_PACKAGE"    = "https://${azurerm_storage_account.deployment.name}.blob.core.windows.net/${azurerm_storage_container.deployment.name}/${azurerm_storage_blob.deployment_package.name}${data.azurerm_storage_account_sas.deployment.sas}"
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