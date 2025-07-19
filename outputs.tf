# This file defines what information to show after deployment

output "workspace_url" {
  description = "URL to access the Databricks workspace"
  value       = databricks_mws_workspaces.this.workspace_url
}

output "workspace_id" {
  description = "The ID of the Databricks workspace"
  value       = databricks_mws_workspaces.this.workspace_id
}

output "workspace_token" {
  description = "Token for accessing the workspace (save this securely!)"
  value       = databricks_mws_workspaces.this.token[0].token_value
  sensitive   = true
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket used for root storage"
  value       = aws_s3_bucket.root_storage.id
}

output "vpc_id" {
  description = "ID of the VPC created for Databricks"
  value       = aws_vpc.databricks.id
}

output "deployment_instructions" {
  description = "Next steps after deployment"
  value = <<-EOT
  
  Databricks workspace successfully created!
  
  To access your workspace:
  1. Navigate to: ${databricks_mws_workspaces.this.workspace_url}
  2. Log in with your Databricks account credentials
  
  To get the workspace token for API access:
  terraform output -raw workspace_token
  
  To add workspace resources, create a new file called workspace_resources.tf
  EOT
}