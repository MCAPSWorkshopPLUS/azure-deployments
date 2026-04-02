terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  backend "azurerm" {
    resource_group_name  = "terraform-state"
    storage_account_name = "tfstate04022026olowosam"
    container_name       = "tsstate"
    key                  = "azure-deployments.tfstate"
  }
}

provider "azurerm" {
  features {}
  use_msi      = true
  msi_endpoint = "http://169.254.169.254/metadata/identity/oauth2/token"
}
