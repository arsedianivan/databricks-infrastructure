output "workspace_id" {
  description = "Workspace ID"
  value       = databricks_mws_workspaces.this.workspace_id
}

output "workspace_url" {
  description = "Workspace URL"
  value       = databricks_mws_workspaces.this.workspace_url
}

output "workspace_token" {
  description = "Workspace token"
  value       = databricks_mws_workspaces.this.token[0].token_value
  sensitive   = true
}

output "workspace_status" {
  description = "Workspace status"
  value       = databricks_mws_workspaces.this.workspace_status
}

output "cluster_policy_id" {
  description = "Default cluster policy ID"
  value       = databricks_cluster_policy.default.id
}

output "secret_scope_name" {
  description = "Default secret scope name"
  value       = databricks_secret_scope.default.name
}