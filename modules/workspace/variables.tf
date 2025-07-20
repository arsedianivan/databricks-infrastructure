variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "workspace_name" {
  description = "Databricks workspace name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "credentials_id" {
  description = "Databricks credentials ID"
  type        = string
}

variable "storage_configuration_id" {
  description = "Databricks storage configuration ID"
  type        = string
}

variable "network_id" {
  description = "Databricks network ID"
  type        = string
}

variable "pricing_tier" {
  description = "Databricks pricing tier"
  type        = string
  default     = "STANDARD"
}

variable "enable_customer_managed_keys" {
  description = "Enable customer managed keys"
  type        = bool
  default     = false
}

variable "managed_services_cmk_key_id" {
  description = "KMS key ID for managed services"
  type        = string
  default     = null
}

variable "storage_cmk_key_id" {
  description = "KMS key ID for storage"
  type        = string
  default     = null
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}