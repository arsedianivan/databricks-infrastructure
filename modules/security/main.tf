locals {
  prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(
    var.tags,
    {
      Module      = "security"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

data "aws_caller_identity" "current" {}

# Cross-account role for Databricks
resource "aws_iam_role" "cross_account" {
  name = "${local.prefix}-databricks-cross-account"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root"
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
      Name = "${local.prefix}-databricks-cross-account"
    }
  )
}

# Policy for cross-account role
resource "aws_iam_role_policy" "cross_account" {
  name = "${local.prefix}-databricks-cross-account-policy"
  role = aws_iam_role.cross_account.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetBucketLocation",
          "s3:GetBucketAcl",
          "s3:GetBucketVersioning"
        ]
        Resource = concat(
          ["arn:aws:s3:::${var.root_storage_bucket}"],
          ["arn:aws:s3:::${var.root_storage_bucket}/*"],
          values(var.data_buckets),
          [for arn in values(var.data_buckets) : "${arn}/*"]
        )
      },
      {
        Sid    = "AssumeRoleAccess"
        Effect = "Allow"
        Action = ["sts:AssumeRole"]
        Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.prefix}-*"]
      },
      {
        Sid    = "EC2Permissions"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVolumes",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcEndpoints",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMServiceLinkedRole"
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole",
          "iam:PassRole"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot"
        Condition = {
          StringLike = {
            "iam:AWSServiceName" = "spot.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Unity Catalog role (optional)
resource "aws_iam_role" "unity_catalog" {
  count = var.enable_unity_catalog ? 1 : 0
  
  name = "${local.prefix}-unity-catalog"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.cross_account.arn,
            "arn:aws:iam::414351767826:root"
          ]
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
      Name = "${local.prefix}-unity-catalog"
    }
  )
}

# Unity Catalog policy
resource "aws_iam_role_policy" "unity_catalog" {
  count = var.enable_unity_catalog ? 1 : 0
  
  name = "${local.prefix}-unity-catalog-policy"
  role = aws_iam_role.unity_catalog[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration"
        ]
        Resource = concat(
          values(var.data_buckets),
          [for arn in values(var.data_buckets) : "${arn}/*"]
        )
      },
      {
        Effect = "Allow"
        Action = ["sts:AssumeRole"]
        Resource = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.prefix}-*"]
      }
    ]
  })
}

# Wait for IAM propagation
resource "time_sleep" "iam_propagation" {
  depends_on = [
    aws_iam_role_policy.cross_account,
    aws_iam_role_policy.unity_catalog
  ]
  
  create_duration = "60s"
}

# Databricks credential configuration
resource "databricks_mws_credentials" "this" {
  credentials_name = "${local.prefix}-credentials"
  role_arn        = aws_iam_role.cross_account.arn
  
  depends_on = [time_sleep.iam_propagation]
}