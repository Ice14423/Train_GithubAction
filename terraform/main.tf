terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    grafana = {
      source  = "grafana/grafana"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket = "my-calculator-tf-state-store"
    key    = "react-app/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

# ==========================================
# PART 0: Providers & Variables
# ==========================================
provider "aws" {
  region = "ap-southeast-2"
}

# [FIX] WAF สำหรับ CloudFront ต้องสร้างที่ us-east-1 เท่านั้น
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

variable "grafana_url" { type = string }
variable "grafana_auth" { type = string }

provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_auth
}

# ==========================================
# PART 1: Database (DynamoDB)
# ==========================================
# [FIX] เพิ่มการเข้ารหัส (แม้ DynamoDB จะเข้ารหัสโดย Default แต่ระบุให้ชัดเจนดีกว่า)
resource "aws_dynamodb_table" "grades_db" {
  name         = "StudentGrades"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "StudentID"

  attribute {
    name = "StudentID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Environment = "Production"
    App         = "GradeCalculator"
  }
}

# ==========================================
# PART 2: Frontend (S3 + CloudFront + WAF)
# ==========================================

# [FIX] สร้าง KMS Key สำหรับเข้ารหัส S3 (แก้ AVD-AWS-0132)
resource "aws_kms_key" "s3_key" {
  description             = "Key for S3 encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_s3_bucket" "react_bucket" {
  bucket = "my-calculator-react-app-production"
}

# [FIX] เปิดใช้งาน Encryption ด้วย KMS Key (แก้ AVD-AWS-0088)
resource "aws_s3_bucket_server_side_encryption_configuration" "react_bucket_encryption" {
  bucket = aws_s3_bucket.react_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_key.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_website_configuration" "react_website" {
  bucket = aws_s3_bucket.react_bucket.id
  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
}

# [FIX] Block Public Access 100% (แก้ AVD-AWS-0086, 0087, 0091, 0093)
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.react_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# [FIX] ใช้ Origin Access Control (OAC) แทนวิธีเก่า เพื่อความปลอดภัย
resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "react-app-oac"
  description                       = "OAC for React App"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# [FIX] Update Policy ให้อนุญาตเฉพาะ CloudFront OAC นี้เท่านั้น (ไม่ต้องเปิด Public *)
resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = aws_s3_bucket.react_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.react_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}

# [FIX] สร้าง WAF ขั้นพื้นฐาน (แก้ AVD-AWS-0011)
resource "aws_wafv2_web_acl" "cloudfront_waf" {
  provider    = aws.us_east_1 # ต้องสร้างที่ US-East-1
  name        = "react-app-waf"
  description = "Basic WAF for React App"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "react-app-waf"
    sampled_requests_enabled   = true
  }
  
  # ตัวอย่าง Rule: ป้องกัน Common Attacks (AWSManagedRulesCommonRuleSet)
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common-rules"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.react_bucket.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.react_bucket.id}"
    # [FIX] ใช้ OAC
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  
  # [FIX] ใส่ WAF ID
  web_acl_id = aws_wafv2_web_acl.cloudfront_waf.arn

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.react_bucket.id}"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  price_class = "PriceClass_200"
}

# ==========================================
# PART 3: Backend (Lambda + IAM)
# ==========================================
resource "aws_iam_role" "lambda_role" {
  name = "serverless_lambda_grade_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_dynamo_policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Scan",
          "dynamodb:Query", "dynamodb:UpdateItem"
        ],
        Resource = aws_dynamodb_table.grades_db.arn
      },
      {
        Effect = "Allow",
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "backend" {
  filename         = "backend.zip"
  function_name    = "grade-api-function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  source_code_hash = fileexists("backend.zip") ? filebase64sha256("backend.zip") : null

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.grades_db.name
    }
  }
  
  # [FIX] เพิ่ม Tracing เพื่อความปลอดภัยและการตรวจสอบ (Optional แต่ดีต่อ Security Audit)
  tracing_config {
    mode = "Active"
  }
}

# ==========================================
# PART 4: API Gateway
# ==========================================
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "grade-http-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["content-type"]
  }
}

resource "aws_apigatewayv2_stage" "lambda_stage" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = "$default"
  auto_deploy = true
  
  # [FIX] ควรเปิด Access Log สำหรับ API Gateway (Best Practice)
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_log.arn
    format          = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId"
  }
}

resource "aws_cloudwatch_log_group" "api_gw_log" {
  name              = "/aws/api-gateway/grade-http-api"
  retention_in_days = 7
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.lambda_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.backend.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "any_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}

# ==========================================
# PART 5: Grafana Monitoring
# ==========================================
resource "aws_iam_user" "grafana" {
  name = "grafana-cloudwatch-reader-tf"
}

resource "aws_iam_access_key" "grafana" {
  user = aws_iam_user.grafana.name
}

resource "aws_iam_user_policy_attachment" "grafana_ro" {
  user       = aws_iam_user.grafana.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

resource "grafana_data_source" "cloudwatch" {
  type = "cloudwatch"
  name = "AWS-CloudWatch-TF"
  
  json_data_encoded = jsonencode({
    defaultRegion = "ap-southeast-2"
    authType      = "keys"
  })

  secure_json_data_encoded = jsonencode({
    accessKey = aws_iam_access_key.grafana.id
    secretKey = aws_iam_access_key.grafana.secret
  })
}
//dashboard for monitoring lambda invocationsSFSFD
resource "grafana_dashboard" "grade_app_monitor" {
  config_json = jsonencode({
    "title": "Grade App Monitor (Terraform)",
    "panels": [
      {
        "type": "timeseries",
        "title": "Lambda Invocations (Real-time)",
        "gridPos": { "h": 8, "w": 12, "x": 0, "y": 0 },
        "targets": [
          {
            "datasource": { "type": "cloudwatch", "uid": grafana_data_source.cloudwatch.uid },
            "namespace": "AWS/Lambda",
            "metricName": "Invocations",
            "dimensions": { "FunctionName": aws_lambda_function.backend.function_name },
            "region": "ap-southeast-2",
            "stat": "Sum",
            "refId": "A"
          }
        ]
      }
    ]
  })
}
//
# ==========================================
# Outputs
# ==========================================
output "s3_bucket_name" { value = aws_s3_bucket.react_bucket.id }
output "cloudfront_distribution_id" { value = aws_cloudfront_distribution.s3_distribution.id }
output "website_https_url" { value = aws_cloudfront_distribution.s3_distribution.domain_name }
output "api_endpoint" { value = aws_apigatewayv2_api.lambda_api.api_endpoint }