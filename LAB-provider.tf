terraform {
  required_version = "~> 1.0"
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0"
    }
  }
  cloud {
    organization = "reddomelabproject"
    workspaces {
      name = "entra-management-terraform"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}