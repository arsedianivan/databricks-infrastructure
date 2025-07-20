locals {
  prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(
    var.tags,
    {
      Module      = "workspace"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# Create the workspace
resource "databricks_mws_workspaces" "this" {
  workspace_name = var.workspace_name
  aws_region     = var.aws_region
  
  credentials_id           = var.credentials_id
  storage_configuration_id = var.storage_configuration_id
  network_id              = var.network_id
  pricing_tier            = var.pricing_tier

  # Customer managed keys (optional)
  dynamic "managed_services_customer_managed_key_id" {
    for_each = var.enable_customer_managed_keys && var.managed_services_cmk_key_id != null ? [1] : []
    content {
      managed_services_customer_managed_key_id = var.managed_services_cmk_key_id
    }
  }

  dynamic "storage_customer_managed_key_id" {
    for_each = var.enable_customer_managed_keys && var.storage_cmk_key_id != null ? [1] : []
    content {
      storage_customer_managed_key_id = var.storage_cmk_key_id
    }
  }

  token {
    comment = "Terraform deployment token"
  }
}

# Wait for workspace to be ready
resource "time_sleep" "workspace_creation" {
  depends_on = [databricks_mws_workspaces.this]
  
  create_duration = "30s"
}

# Workspace configuration
resource "databricks_workspace_conf" "this" {
  depends_on = [time_sleep.workspace_creation]
  
  custom_config = {
    "enableIpAccessLists" = "true"
    "enableTokensConfig"  = "true"
  }
}

# Default cluster policy
resource "databricks_cluster_policy" "default" {
  depends_on = [time_sleep.workspace_creation]
  
  name = "${local.prefix}-default-policy"
  
  definition = jsonencode({
    "spark_version" : {
      "type" : "fixed",
      "value" : "13.3.x-scala2.12"
    },
    "autotermination_minutes" : {
      "type" : "range",
      "minValue" : 10,
      "maxValue" : 120,
      "defaultValue" : 60
    },
    "custom_tags.Environment" : {
      "type" : "fixed",
      "value" : var.environment
    }
  })
}

# Instance profile (if needed)
resource "databricks_instance_profile" "default" {
  depends_on = [time_sleep.workspace_creation]
  
  instance_profile_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/${local.prefix}-instance-profile"
  
  skip_validation = true
}

data "aws_caller_identity" "current" {}

# Default secret scope
resource "databricks_secret_scope" "default" {
  depends_on = [time_sleep.workspace_creation]
  
  name = "${local.prefix}-secrets"
}

# Workspace settings
resource "databricks_global_init_script" "default" {
  depends_on = [time_sleep.workspace_creation]
  
  name     = "${local.prefix}-init"
  enabled  = true
  position = 1
  
  content_base64 = base64encode(<<-EOT
    #!/bin/bash
    # Global init script
    echo "Environment: ${var.environment}"
    echo "Workspace initialized at: $(date)"
    
    # Set environment variables
    export ENVIRONMENT="${var.environment}"
    export PROJECT="${var.project_name}"
  EOT
  )
}