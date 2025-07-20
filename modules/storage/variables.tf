variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "databricks_account_id" {
  description = "Databricks account ID"
  type        = string
}

variable "cross_account_role_arn" {
  description = "Databricks cross-account role ARN"
  type        = string
}

variable "data_buckets" {
  description = "Additional data buckets to create"
  type = list(object({
    name               = string
    purpose            = string
    versioning_enabled = bool
    lifecycle_rules    = list(object({
      id                     = string
      status                 = string
      transition_days        = number
      transition_storage_class = string
      expiration_days        = number
    }))
    encryption = object({
      algorithm = string
      kms_key_id = optional(string)
    })
  }))
  default = []
}

variable "enable_logging" {
  description = "Enable S3 access logging"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}