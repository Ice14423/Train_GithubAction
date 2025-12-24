terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Note: ต้องสร้าง Bucket ชื่อนี้ด้วยมือก่อนเพื่อเก็บ State
  backend "s3" {
    bucket = "my-calculator-tf-state-store" 
    key    = "react-app/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# --- 1. DynamoDB (Database เก็บเกรด) ---
resource "aws_dynamodb_table" "grades_db" {
  name           = "StudentGrades"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "StudentID"
  
  attribute {
    name = "StudentID"
    type = "S"
  }

  tags = {
    Environment = "Production"
    App         = "GradeCalculator"
  }
}

# --- 2. S3 Bucket (Web Hosting) ---
resource "aws_s3_bucket" "react_bucket" {
  bucket = "GradeCalculatorApp" # เปลี่ยนชื่อให้ไม่ซ้ำ!
}

resource "aws_s3_bucket_website_configuration" "react_website" {
  bucket = aws_s3_bucket.react_bucket.id
  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
}

# ปิด Public Access Block เพื่อให้ CloudFront เข้าถึงได้ (หรือตั้ง Policy)
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.react_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Policy ให้ CloudFront อ่านได้ (หรือ Public Read แบบง่าย)
resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.react_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.react_bucket.arn}/*"
      },
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.public_access]
}

# --- 3. CloudFront (HTTPS) ---
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.react_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.react_bucket.id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.react_bucket.id}"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "redirect-to-https" # บังคับ HTTPS
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  viewer_certificate {
    cloudfront_default_certificate = true # ใช้ HTTPS ฟรีของ AWS
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  price_class = "PriceClass_200"
}

# --- Outputs ---
output "s3_bucket_name" {
  value = aws_s3_bucket.react_bucket.id
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.s3_distribution.id
}

output "website_https_url" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}