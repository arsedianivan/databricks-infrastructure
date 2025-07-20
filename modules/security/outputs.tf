output "cross_account_role_arn" {
  description = "Cross-account role ARN"
  value       = aws_iam_role.cross_account.arn
}

output "cross_account_role_name" {
  description = "Cross-account role name"
  value       = aws_iam_role.cross_account.name
}

output "unity_catalog_role_arn" {
  description = "Unity Catalog role ARN"
  value       = var.enable_unity_catalog ? aws_iam_role.unity_catalog[0].arn : null
}

output "credentials_id" {
  description = "Databricks credentials ID"
  value       = databricks_mws_credentials.this.credentials_id
}

output "credentials_name" {
  description = "Databricks credentials name"
  value       = databricks_mws_credentials.this.credentials_name
}

output "account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}