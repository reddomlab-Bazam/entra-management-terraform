locals {
  # Resource naming convention: lab-uks-entra-<resource-type>
  naming_prefix = "${var.environment}-${var.location_code}-${var.service_name}"
  
  default_tags = {
    environment = var.environment
    location    = var.location_code
    service     = var.service_name
    criticality = "low"
    managed     = "Terraform"
    owner       = "lab-admin@reddomelabproject.com"
    repo        = "https://github.com/reddomelabproject/entra-management-terraform"
    project     = "EntraManagement"
    component   = "Lab"
    workload    = "entra-automation"
    purpose     = "azure-ad-management"
  }
  
  tags_all = merge(local.default_tags, {
    # Add any additional tags specific to lab environment
    automation_type = "unified-management"
    compliance_scope = "identity-governance"
    data_classification = "internal"
    cost_center = "lab"
  })
  
  # Resource names using naming convention
  resource_names = {
    storage_account     = var.storage_account_name # Exception: storage accounts don't support hyphens
    automation_account  = var.automation_account_name
    app_service_plan    = var.app_service_plan_name
    web_app            = var.web_app_name
    key_vault          = "${local.naming_prefix}-kv"
    application_insights = "${local.naming_prefix}-ai"
  }
}