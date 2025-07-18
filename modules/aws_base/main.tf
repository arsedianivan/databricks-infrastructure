# Cross-account IAM role for Databricks
resource "aws_iam_role" "databricks_cross_account" {
  name = "${var.prefix}-databricks-cross-account"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root" # Databricks AWS account
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.databricks_account_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

# S3 bucket for Databricks root storage
resource "aws_s3_bucket" "databricks_root" {
  bucket = "${var.prefix}-databricks-root-${var.environment}"
  
  tags = merge(var.tags, {
    Purpose = "Databricks root storage"
  })
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "databricks_root" {
  bucket = aws_s3_bucket.databricks_root.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "databricks_root" {
  bucket = aws_s3_bucket.databricks_root.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.databricks.arn
    }
  }
}

# KMS key for Databricks encryption
resource "aws_kms_key" "databricks" {
  description = "KMS key for Databricks ${var.environment}"
  
  tags = var.tags
}

# KMS key alias
resource "aws_kms_alias" "databricks" {
  name          = "alias/${var.prefix}-databricks-${var.environment}"
  target_key_id = aws_kms_key.databricks.key_id
}