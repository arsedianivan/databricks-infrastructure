locals {
  prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(
    var.tags,
    {
      Module      = "storage"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

# Random suffix for bucket uniqueness
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket for logs
resource "aws_s3_bucket" "logs" {
  count = var.enable_logging ? 1 : 0
  
  bucket = "${local.prefix}-logs-${var.account_id}-${random_string.suffix.result}"
  
  tags = merge(
    local.common_tags,
    {
      Name    = "${local.prefix}-logs"
      Purpose = "Access logs for all buckets"
    }
  )
}

# Root storage bucket for Databricks
resource "aws_s3_bucket" "root_storage" {
  bucket = "${local.prefix}-databricks-root-${var.account_id}-${random_string.suffix.result}"
  
  tags = merge(
    local.common_tags,
    {
      Name    = "${local.prefix}-databricks-root"
      Purpose = "Databricks root storage"
    }
  )
}

# Public access block for root storage
resource "aws_s3_bucket_public_access_block" "root_storage" {
  bucket = aws_s3_bucket.root_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning for root storage
resource "aws_s3_bucket_versioning" "root_storage" {
  bucket = aws_s3_bucket.root_storage.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption for root storage
resource "aws_s3_bucket_server_side_encryption_configuration" "root_storage" {
  bucket = aws_s3_bucket.root_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Logging for root storage
resource "aws_s3_bucket_logging" "root_storage" {
  count = var.enable_logging ? 1 : 0
  
  bucket = aws_s3_bucket.root_storage.id

  target_bucket = aws_s3_bucket.logs[0].id
  target_prefix = "root-storage/"
}

# Bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "root_storage" {
  bucket = aws_s3_bucket.root_storage.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Bucket policy for Databricks access
resource "aws_s3_bucket_policy" "root_storage" {
  bucket = aws_s3_bucket.root_storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DatabricksBucketAccess"
        Effect = "Allow"
        Principal = {
          AWS = [
            var.cross_account_role_arn,
            "arn:aws:iam::414351767826:root"
          ]
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObjectVersion",
          "s3:PutObjectAcl",
          "s3:GetObjectAcl"
        ]
        Resource = [
          aws_s3_bucket.root_storage.arn,
          "${aws_s3_bucket.root_storage.arn}/*"
        ]
      }
    ]
  })
  
  depends_on = [
    aws_s3_bucket_public_access_block.root_storage,
    aws_s3_bucket_ownership_controls.root_storage
  ]
}

# Additional data buckets
resource "aws_s3_bucket" "data" {
  for_each = { for bucket in var.data_buckets : bucket.name => bucket }
  
  bucket = "${local.prefix}-${each.value.name}-${var.account_id}-${random_string.suffix.result}"
  
  tags = merge(
    local.common_tags,
    {
      Name    = "${local.prefix}-${each.value.name}"
      Purpose = each.value.purpose
    }
  )
}

# Public access block for data buckets
resource "aws_s3_bucket_public_access_block" "data" {
  for_each = aws_s3_bucket.data
  
  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning for data buckets
resource "aws_s3_bucket_versioning" "data" {
  for_each = { 
    for bucket in var.data_buckets : bucket.name => bucket 
    if bucket.versioning_enabled 
  }
  
  bucket = aws_s3_bucket.data[each.key].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption for data buckets
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  for_each = aws_s3_bucket.data
  
  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.data_buckets[index(var.data_buckets[*].name, each.key)].encryption.algorithm
      kms_master_key_id = var.data_buckets[index(var.data_buckets[*].name, each.key)].encryption.algorithm == "aws:kms" ? var.data_buckets[index(var.data_buckets[*].name, each.key)].encryption.kms_key_id : null
    }
  }
}

# Lifecycle configuration for data buckets
resource "aws_s3_bucket_lifecycle_configuration" "data" {
  for_each = {
    for bucket in var.data_buckets : bucket.name => bucket
    if length(bucket.lifecycle_rules) > 0
  }
  
  bucket = aws_s3_bucket.data[each.key].id

  dynamic "rule" {
    for_each = each.value.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.status

      dynamic "transition" {
        for_each = rule.value.transition_days > 0 ? [1] : []
        content {
          days          = rule.value.transition_days
          storage_class = rule.value.transition_storage_class
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days > 0 ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }

      abort_incomplete_multipart_upload {
        days_after_initiation = 7
      }
    }
  }
}

# Bucket policies for data buckets
resource "aws_s3_bucket_policy" "data" {
  for_each = aws_s3_bucket.data
  
  bucket = each.value.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DatabricksDataAccess"
        Effect = "Allow"
        Principal = {
          AWS = [
            var.cross_account_role_arn,
            "arn:aws:iam::414351767826:root"
          ]
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          each.value.arn,
          "${each.value.arn}/*"
        ]
      }
    ]
  })
  
  depends_on = [
    aws_s3_bucket_public_access_block.data
  ]
}

# CloudWatch metric alarms
resource "aws_cloudwatch_metric_alarm" "bucket_size" {
  for_each = var.enable_monitoring ? aws_s3_bucket.data : {}
  
  alarm_name          = "${each.value.id}-size-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name        = "BucketSizeBytes"
  namespace          = "AWS/S3"
  period             = "86400"
  statistic          = "Average"
  threshold          = 1099511627776  # 1TB
  alarm_description  = "Alert when bucket size exceeds 1TB"
  
  dimensions = {
    BucketName = each.value.id
    StorageType = "StandardStorage"
  }
  
  tags = local.common_tags
}