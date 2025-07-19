# This file tells Terraform what services we're using

terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.38.0"  # This allows any version 1.38.0 or higher
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Configure the Databricks Provider for account-level operations
# Note: Starting with provider version 1.50+, you must also specify
# account_id in each MWS resource, not just here in the provider
provider "databricks" {
  alias         = "mws"
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.databricks_account_id
  client_id     = var.client_id
  client_secret = var.client_secret
}