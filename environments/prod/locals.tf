# =============================================================================
# PRODUCTION ENVIRONMENT LOCALS
# =============================================================================

locals {
  # Common tags for all resources
  common_tags = {
    Environment     = var.environment
    ManagedBy      = "Terraform"
    Project        = "Entra Management Console"
    CostCenter     = "IT"
    DataClassification = "Internal"
  }

  # Merge common tags with user-provided tags
  tags_all = merge(local.common_tags, var.tags)

  # Naming convention for resources
  name_prefix = "${var.environment}-${var.location_code}"
} 