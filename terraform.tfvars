# This file contains your actual values (add to .gitignore!)

# Found from Account Console URL or Account Settings
databricks_account_id = "<ACCOUNT_ID>"

# From Service Principal creation
client_id            = "<CLIENT_ID>"
client_secret        = "<CLIENT_SECRET>"

# Your chosen values
workspace_name       = "<WORKSPACE_NAME>"
environment          = "<ENVIRONMENT>"
aws_region           = "<REGION>"

# Optional: Add tags
tags = {
  Project     = "<Project Name>"
  Owner       = "<Owner Name>"
  Environment = "<Env Name>"
  ManagedBy   = "Terraform"
}

# Add to your existing terraform.tfvars
enable_user_management = true

workspace_admins = [
  {
    email        = "<Email>"
    display_name = "<Display_Name>"
  }
]

# Leave empty or add only NEW users
workspace_users = []
