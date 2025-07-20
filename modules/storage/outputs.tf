output "root_storage_bucket" {
  description = "Root storage bucket name"
  value       = aws_s3_bucket.root_storage.id
}

output "root_storage_bucket_arn" {
  description = "Root storage bucket ARN"
  value       = aws_s3_bucket.root_storage.arn
}

output "data_buckets" {
  description = "Data bucket details"
  value = {
    for k, v in aws_s3_bucket.data : k => {
      name = v.id
      arn  = v.arn
    }
  }
}

output "log_bucket" {
  description = "Log bucket name"
  value       = var.enable_logging ? aws_s3_bucket.logs[0].id : null
}

output "bucket_endpoints" {
  description = "S3 endpoints for all buckets"
  value = merge(
    {
      root_storage = "s3://${aws_s3_bucket.root_storage.id}"
    },
    {
      for k, v in aws_s3_bucket.data : k => "s3://${v.id}"
    }
  )
}