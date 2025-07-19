# Reference existing users instead of creating them
data "databricks_user" "existing_admin_team" {
  provider  = databricks.workspace
  user_name = "team@taughtlab.com"
}

# Create groups
resource "databricks_group" "admins" {
  count        = var.enable_user_management ? 1 : 0
  provider     = databricks.workspace
  display_name = "workspace-admins"
}

resource "databricks_group" "users" {
  count        = var.enable_user_management ? 1 : 0
  provider     = databricks.workspace
  display_name = "workspace-users"
}

# Add existing user to admin group
resource "databricks_group_member" "existing_admin_member" {
  count     = var.enable_user_management ? 1 : 0
  provider  = databricks.workspace
  group_id  = databricks_group.admins[0].id
  member_id = data.databricks_user.existing_admin_team.id
}

# Set entitlements for existing user
resource "databricks_entitlements" "existing_admin_entitlements" {
  count    = var.enable_user_management ? 1 : 0
  provider = databricks.workspace
  
  user_id = data.databricks_user.existing_admin_team.id
  
  workspace_access           = true
  databricks_sql_access      = true
  allow_cluster_create       = true
  allow_instance_pool_create = true
}

# Only create NEW users from the lists
resource "databricks_user" "new_admins" {
  # This will be empty if all admins already exist
  for_each = var.enable_user_management ? {
    for idx, user in var.workspace_admins : idx => user
    if user.email != "team@taughtlab.com"  # Skip existing user
  } : {}
  
  provider     = databricks.workspace
  user_name    = each.value.email
  display_name = each.value.display_name
}

resource "databricks_user" "new_users" {
  count    = var.enable_user_management ? length(var.workspace_users) : 0
  provider = databricks.workspace
  
  user_name    = var.workspace_users[count.index].email
  display_name = var.workspace_users[count.index].display_name
}