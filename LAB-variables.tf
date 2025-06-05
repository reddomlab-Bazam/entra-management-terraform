variable "environment" {
  description = "Environment name"
  type        = string
  default     = "lab"
}

variable "location_code" {
  description = "Location code (e.g., uks for UK South)"
  type        = string
  default     = "uks"
}

variable "service_name" {
  description = "Service name"
  type        = string
  default     = "entra"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "lab-uks-entra-rg"
}

variable "storage_account_name" {
  description = "Name of the storage account for file share"
  type        = string
  default     = "labentraautomation"
  
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be between 3 and 24 characters long and contain only lowercase letters and numbers."
  }
}

variable "file_share_name" {
  description = "Name of the file share for configuration and logs"
  type        = string
  default     = "entra-management"
}

variable "automation_account_name" {
  description = "Name of the Azure Automation Account"
  type        = string
  default     = "lab-uks-entra-automation"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "UK South"
}

variable "enable_schedule" {
  description = "Enable scheduled execution of the runbook"
  type        = bool
  default     = false
}

variable "schedule_frequency" {
  description = "Frequency for scheduled execution (Week, Month)"
  type        = string
  default     = "Week"
  
  validation {
    condition     = contains(["Week", "Month"], var.schedule_frequency)
    error_message = "Schedule frequency must be either 'Week' or 'Month'."
  }
}

variable "schedule_timezone" {
  description = "Timezone for scheduled execution"
  type        = string
  default     = "Europe/London"
}

variable "schedule_start_time" {
  description = "Start time for scheduled execution (ISO 8601 format)"
  type        = string
  default     = "2025-06-08T02:00:00Z"
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

variable "automation_sku" {
  description = "SKU for the Automation Account"
  type        = string
  default     = "Basic"
  
  validation {
    condition     = contains(["Free", "Basic"], var.automation_sku)
    error_message = "Automation SKU must be either 'Free' or 'Basic'."
  }
}

# New variables for web interface
variable "web_app_name" {
  description = "Name of the web application"
  type        = string
  default     = "lab-uks-entra-webapp"
}

variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
  default     = "lab-uks-entra-asp"
}

variable "app_service_plan_sku" {
  description = "SKU for the App Service Plan"
  type        = string
  default     = "F1"
  
  validation {
    condition     = contains(["F1", "D1", "B1", "B2", "B3", "S1", "S2", "S3"], var.app_service_plan_sku)
    error_message = "App Service Plan SKU must be a valid SKU."
  }
}