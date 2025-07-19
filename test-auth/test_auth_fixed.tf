terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = ">= 1.38.0"
    }
  }
}

provider "databricks" {
  alias         = "mws"
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.databricks_account_id
  client_id     = var.client_id
  client_secret = var.client_secret
}

variable "databricks_account_id" {
  type      = string
  sensitive = true
}

variable "client_id" {
  type      = string
  sensitive = true
}

variable "client_secret" {
  type      = string
  sensitive = true
}

# Declare other variables to avoid warnings
variable "workspace_name" {
  type    = string
  default = ""
}

variable "environment" {
  type    = string
  default = ""
}

variable "aws_region" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}

# Test account-level access
data "databricks_service_principals" "all" {
  provider = databricks.mws
}

output "auth_test" {
  value = "✅ SUCCESS: Authentication is working! Your Service Principal credentials are correct."
}

output "service_principals" {
  value     = data.databricks_service_principals.all
  sensitive = true
}
