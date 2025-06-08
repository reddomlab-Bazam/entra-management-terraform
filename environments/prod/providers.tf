# =============================================================================
# PROVIDER CONFIGURATION
# =============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Terraform Cloud - VCS-driven workflow required for modules
  cloud {
    organization = "reddomelabproject"
    workspaces {
      name = "entra-management-prod"
    }
  }
  
  # Uncomment below and comment cloud block above to use local backend
  # backend "local" {
  #   path = "terraform.tfstate"
  # }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {
  # Configuration options
} 