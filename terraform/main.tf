# =============================================================================
# PRIMARY BUCKET (us-east-1)
# =============================================================================

resource "aws_s3_bucket" "primary" {
  bucket        = "${var.bucket_prefix}-dr-primary"
  force_destroy = true

  tags = {
    Role      = "primary"
    Project   = "multi-region-dr"
    ManagedBy = "terraform"
  }
}

# Versioning is REQUIRED for cross-region replication
resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Turn off block public access so the bucket policy below can work
resource "aws_s3_bucket_public_access_block" "primary" {
  bucket = aws_s3_bucket.primary.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Allow any browser to read objects — needed for a public static website
resource "aws_s3_bucket_policy" "primary" {
  bucket     = aws_s3_bucket.primary.id
  depends_on = [aws_s3_bucket_public_access_block.primary]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadForWebsite"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.primary.arn}/*"
      }
    ]
  })
}

# Configure the bucket to serve a static website
resource "aws_s3_bucket_website_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# =============================================================================
# SECONDARY BUCKET (us-west-2)
# Note the provider = aws.secondary on every resource here
# =============================================================================

resource "aws_s3_bucket" "secondary" {
  provider      = aws.secondary
  bucket        = "${var.bucket_prefix}-dr-secondary"
  force_destroy = true

  tags = {
    Role      = "secondary"
    Project   = "multi-region-dr"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "secondary" {
  provider   = aws.secondary
  bucket     = aws_s3_bucket.secondary.id
  depends_on = [aws_s3_bucket_public_access_block.secondary]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadForWebsite"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.secondary.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_website_configuration" "secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# =============================================================================
# IAM ROLE FOR S3 REPLICATION
# S3 needs permission to read from primary and write to secondary
# =============================================================================

resource "aws_iam_role" "replication" {
  name = "${var.bucket_prefix}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project   = "multi-region-dr"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "replication" {
  name = "${var.bucket_prefix}-s3-replication-policy"
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.primary.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.primary.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.secondary.arn}/*"
      }
    ]
  })
}

# =============================================================================
# REPLICATION RULE
# =============================================================================

resource "aws_s3_bucket_replication_configuration" "primary_to_secondary" {
  bucket     = aws_s3_bucket.primary.id
  role       = aws_iam_role.replication.arn
  depends_on = [aws_s3_bucket_versioning.primary]

  rule {
    id     = "replicate-all-to-secondary"
    status = "Enabled"

    filter {}

    destination {
      bucket        = aws_s3_bucket.secondary.arn
      storage_class = "STANDARD"
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }
}

# =============================================================================
# ROUTE 53 FAILOVER (only created when enable_route53_failover = true)
# =============================================================================

resource "aws_route53_health_check" "primary" {
  count = var.enable_route53_failover ? 1 : 0

  fqdn              = aws_s3_bucket_website_configuration.primary.website_endpoint
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name      = "${var.bucket_prefix}-primary-health-check"
    Project   = "multi-region-dr"
    ManagedBy = "terraform"
  }
}

resource "aws_route53_record" "primary" {
  count = var.enable_route53_failover ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "CNAME"
  ttl     = 60

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary[0].id
  set_identifier  = "primary"
  records         = [aws_s3_bucket_website_configuration.primary.website_endpoint]
}

resource "aws_route53_record" "secondary" {
  count = var.enable_route53_failover ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "CNAME"
  ttl     = 60

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "secondary"
  records        = [aws_s3_bucket_website_configuration.secondary.website_endpoint]
}