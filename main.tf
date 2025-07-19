# This file contains our actual infrastructure

# Local variables for consistent naming
locals {
  prefix = "${var.workspace_name}-${var.environment}"
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Workspace   = var.workspace_name
    }
  )
}

# IMPORTANT: Starting with Databricks provider 1.50+, these resources require account_id:
# - databricks_mws_credentials
# - databricks_mws_storage_configurations  
# - databricks_mws_networks
# - databricks_mws_workspaces

# Create a unique S3 bucket for Databricks root storage
resource "aws_s3_bucket" "root_storage" {
  bucket = "${local.prefix}-databricks-root-${data.aws_caller_identity.current.account_id}"
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-databricks-root-storage"
    }
  )
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Block all public access to the bucket
resource "aws_s3_bucket_public_access_block" "root_storage" {
  bucket = aws_s3_bucket.root_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for data protection
resource "aws_s3_bucket_versioning" "root_storage" {
  bucket = aws_s3_bucket.root_storage.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Create IAM role for Databricks to access AWS resources
resource "aws_iam_role" "databricks_cross_account" {
  name = "${local.prefix}-databricks-cross-account-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root"  # Databricks AWS account
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.databricks_account_id
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-databricks-cross-account-role"
    }
  )
}

# Attach policy to the role
resource "aws_iam_role_policy" "databricks_cross_account" {
  name = "${local.prefix}-databricks-cross-account-policy"
  role = aws_iam_role.databricks_cross_account.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.root_storage.arn,
          "${aws_s3_bucket.root_storage.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.prefix}-databricks-*"
        ]
      }
    ]
  })
}

# Wait for IAM role to be ready
resource "time_sleep" "wait_for_role" {
  depends_on = [
    aws_iam_role_policy.databricks_cross_account
  ]
  create_duration = "20s"
}

# Create Databricks credential configuration
resource "databricks_mws_credentials" "this" {
  provider         = databricks.mws
  credentials_name = "${local.prefix}-credentials"
  role_arn        = aws_iam_role.databricks_cross_account.arn
  
  depends_on = [time_sleep.wait_for_role]
}

# Create Databricks storage configuration
resource "databricks_mws_storage_configurations" "this" {
  provider                   = databricks.mws
  account_id                 = var.databricks_account_id
  storage_configuration_name = "${local.prefix}-storage"
  bucket_name               = aws_s3_bucket.root_storage.id
}

# Create VPC for Databricks (required for production use)
resource "aws_vpc" "databricks" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-databricks-vpc"
    }
  )
}

# Create subnets for Databricks
resource "aws_subnet" "databricks" {
  count = 2

  vpc_id            = aws_vpc.databricks.id
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-databricks-subnet-${count.index + 1}"
    }
  )
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Create Internet Gateway
resource "aws_internet_gateway" "databricks" {
  vpc_id = aws_vpc.databricks.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-databricks-igw"
    }
  )
}

# Create route table
resource "aws_route_table" "databricks" {
  vpc_id = aws_vpc.databricks.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.databricks.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-databricks-rt"
    }
  )
}

# Associate route table with subnets
resource "aws_route_table_association" "databricks" {
  count = 2

  subnet_id      = aws_subnet.databricks[count.index].id
  route_table_id = aws_route_table.databricks.id
}

# Create security group for Databricks
resource "aws_security_group" "databricks" {
  name        = "${local.prefix}-databricks-sg"
  description = "Security group for Databricks workspace"
  vpc_id      = aws_vpc.databricks.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.prefix}-databricks-sg"
    }
  )
}

# Create Databricks network configuration
resource "databricks_mws_networks" "this" {
  provider           = databricks.mws
  account_id         = var.databricks_account_id
  network_name       = "${local.prefix}-network"
  security_group_ids = [aws_security_group.databricks.id]
  subnet_ids         = aws_subnet.databricks[*].id
  vpc_id             = aws_vpc.databricks.id
}

# Create the Databricks workspace
resource "databricks_mws_workspaces" "this" {
  provider       = databricks.mws
  account_id     = var.databricks_account_id
  workspace_name = var.workspace_name
  aws_region     = var.aws_region

  credentials_id            = databricks_mws_credentials.this.credentials_id
  storage_configuration_id  = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id

  token {
    comment = "Terraform deployment token"
  }
}

# Configure provider for workspace-level resources
provider "databricks" {
  alias = "workspace"
  host  = databricks_mws_workspaces.this.workspace_url
  token = databricks_mws_workspaces.this.token[0].token_value
}