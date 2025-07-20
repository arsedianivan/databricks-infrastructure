variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID"
  type        = string
}

variable "client_id" {
  description = "Service principal client ID"
  type        = string
  sensitive   = true
}

variable "client_secret" {
  description = "Service principal client secret"
  type        = string
  sensitive   = true
}

variable "root_storage_bucket" {
  description = "Root storage bucket name"
  type        = string
}

variable "data_buckets" {
  description = "Data bucket ARNs"
  type        = map(string)
  default     = {}
}

variable "enable_unity_catalog" {
  description = "Enable Unity Catalog IAM resources"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}