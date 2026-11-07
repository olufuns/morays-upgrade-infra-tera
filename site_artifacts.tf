# Store immutable, versioned website releases published by the Ansible project.
# This bucket is private: only the EC2 instance profile receives read access.
resource "aws_s3_bucket" "website_artifacts" {
  bucket_prefix = "${var.project_name}-${var.environment}-site-"
  force_destroy = false # Never silently delete the website and its release history.

  tags = {
    Name = "${var.project_name}-website-artifacts-${var.environment}"
  }
}

resource "aws_s3_bucket_public_access_block" "website_artifacts" {
  bucket                  = aws_s3_bucket.website_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website_artifacts" {
  bucket = aws_s3_bucket.website_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "website_artifacts" {
  bucket = aws_s3_bucket.website_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}
