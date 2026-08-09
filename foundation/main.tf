terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {
  }
  required_version = ">= 1.2.8"
}

provider "azurerm" {
  subscription_id = "269e3ad0-7234-4363-a62c-001f617cba7e" # Sub-DevOps-Prd-01
  features {}
  resource_provider_registrations = "all"
}

module "foundation" {
  # This is authenticated via the ACI container, the ssh config is set up to use a specific ssh key
  source = "git::ssh://ado-terraform-modules/v3/EnterpriseCloudSolutions/EnterpriseCommonSolutions/terraform-azurerm-ecs-foundation-dev-test-prod?ref=Legacy"

  name              = "DevOpsSbx"
  dev_subscription  = "Sub-DevOps-Sbx-01"
  test_subscription = "Sub-DevOps-Stg-01"
  prod_subscription = "Sub-DevOps-Prd-01"
}
