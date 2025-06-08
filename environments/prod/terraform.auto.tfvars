# =============================================================================
# PRODUCTION ENVIRONMENT VARIABLES (AUTO-LOADED)
# =============================================================================
# This file is automatically loaded by Terraform
# Sensitive values should be set as Environment Variables in Terraform Cloud

# Environment configuration
environment = "lab"
location = "uksouth" 
location_code = "uks"

# Resource naming to match existing infrastructure
resource_group_name = "lab-uks-entra-rg"
storage_account_name = "labentraautomation"
file_share_name = "entra-management"
web_app_name = "lab-uks-entra-webapp"
app_service_plan_name = "lab-uks-entra-webapp-plan"
key_vault_name = "lab-uks-entra-kv"

# Storage configuration
file_share_quota_gb = 5
storage_replication_type = "LRS"

# App Service configuration
app_service_plan_sku = "P1v2"

# Security configuration
enable_ip_restrictions = false
# allowed_ip_address will be set as environment variable if needed

# Application Insights configuration
application_insights_type = "web"

# Additional tags (will be merged with common tags)
tags = {
  Owner = "IT Team"
  Purpose = "Entra ID Management"
  ManagedBy = "Terraform Cloud"
} 