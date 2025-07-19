# This file defines what configuration options we need

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "databricks_account_id" {
  description = "Databricks account ID (found in account console)"
  type        = string
  sensitive   = true
}

variable "client_id" {
  description = "Service principal Application ID for Databricks"
  type        = string
  sensitive   = true
}

variable "client_secret" {
  description = "Service principal client secret for Databricks"
  type        = string
  sensitive   = true
}

variable "workspace_name" {
  description = "Name for your Databricks workspace"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cidr_block" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Update these variables in your variables.tf
variable "workspace_admins" {
  description = "List of admin users for the workspace"
  type = list(object({
    email        = string
    display_name = string
  }))
  default = []
  # Remove sensitive = true
}

variable "workspace_users" {
  description = "List of regular users for the workspace"
  type = list(object({
    email        = string
    display_name = string
  }))
  default = []
  # Remove sensitive = true
}

variable "enable_user_management" {
  description = "Enable automatic user management via Terraform"
  type        = bool
  default     = false
}