terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # [NEW] เพิ่ม Grafana Provider
    grafana = {
      source  = "grafana/grafana"
      version = "~> 3.0"
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

# [NEW] ตั้งค่า Provider Grafana
provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_auth
}

# ==========================================
# PART 1: Database (DynamoDB)
# ==========================================
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

# ==========================================
# PART 2: Frontend (S3 + CloudFront)
# ==========================================
resource "aws_s3_bucket" "react_bucket" {
  bucket = "my-calculator-react-app-production" # ชื่อเดิมของคุณ
  # force_destroy = true # ถ้าอยากให้ลบถังได้แม้มีไฟล์อยู่ ให้เปิดบรรทัดนี้
}

resource "aws_s3_bucket_website_configuration" "react_website" {
  bucket = aws_s3_bucket.react_bucket.id
  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.react_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

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

# 3.1 สร้าง Role ให้ Lambda
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

# 3.2 อนุญาตให้ Lambda ยุ่งกับ DynamoDB และเขียน Logs
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_dynamo_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ],
        Resource = aws_dynamodb_table.grades_db.arn
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# 3.3 สร้าง Lambda Function
resource "aws_lambda_function" "backend" {
  filename      = "backend.zip"
  function_name = "grade-api-function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  source_code_hash = fileexists("backend.zip") ? filebase64sha256("backend.zip") : null

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.grades_db.name
    }
  }
}

# ==========================================
# PART 4: API Gateway (HTTP API)
# ==========================================

# 4.1 สร้าง API Gateway
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "grade-http-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["content-type"]
  }
}

# 4.2 สร้าง Stage
resource "aws_apigatewayv2_stage" "lambda_stage" {
  api_id = aws_apigatewayv2_api.lambda_api.id
  name   = "$default"
  auto_deploy = true
}

# 4.3 เชื่อม API Gateway เข้ากับ Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.lambda_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.backend.invoke_arn
  payload_format_version = "2.0"
}

# 4.4 สร้าง Route
resource "aws_apigatewayv2_route" "any_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# 4.5 อนุญาตให้ API Gateway เรียก Lambda ได้
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}

# ==========================================
# PART 5: Monitoring (Grafana + AWS IAM) - [NEW]
# ==========================================

# 5.1 สร้าง IAM User สำหรับ Grafana
resource "aws_iam_user" "grafana" {
  name = "grafana-cloudwatch-reader"
}

resource "aws_iam_access_key" "grafana" {
  user = aws_iam_user.grafana.name
}

resource "aws_iam_user_policy_attachment" "grafana_ro" {
  user       = aws_iam_user.grafana.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

# 5.2 เชื่อม Grafana Data Source
resource "grafana_data_source" "cloudwatch" {
  type = "cloudwatch"
  name = "AWS-CloudWatch-TF"
  
  json_data_encoded = jsonencode({
    defaultRegion = "ap-southeast-2" # ต้องตรงกับ Region AWS ของคุณ
    authType      = "keys"
  })

  secure_json_data_encoded = jsonencode({
    accessKey = aws_iam_access_key.grafana.id
    secretKey = aws_iam_access_key.grafana.secret
  })
}

# 5.3 สร้าง Dashboard
resource "grafana_dashboard" "grade_app_monitor" {
  config_json = jsonencode({
    "title": "Grade App Monitor (Terraform)",
    "panels": [
      {
        "type": "timeseries",
        "title": "Lambda Performance",
        "gridPos": { "h": 9, "w": 12, "x": 0, "y": 0 },
        "targets": [
          {
            "datasource": { "type": "cloudwatch", "uid": grafana_data_source.cloudwatch.uid },
            "namespace": "AWS/Lambda",
            "metricName": "Invocations",
            "dimensions": { "FunctionName": aws_lambda_function.backend.function_name },
            "region": "ap-southeast-2",
            "stat": "Sum",
            "refId": "A",
            "label": "Requests"
          },
          {
            "datasource": { "type": "cloudwatch", "uid": grafana_data_source.cloudwatch.uid },
            "namespace": "AWS/Lambda",
            "metricName": "Errors",
            "dimensions": { "FunctionName": aws_lambda_function.backend.function_name },
            "region": "ap-southeast-2",
            "stat": "Sum",
            "refId": "B",
            "color": { "fixedColor": "red", "mode": "fixed" },
            "label": "Errors"
          }
        ]
      }
    ]
  })
}

# ==========================================
# Variables & Outputs
# ==========================================

variable "grafana_url" {
  type        = string
  description = "Grafana URL e.g. https://my-stack.grafana.net"
}

variable "grafana_auth" {
  type        = string
  sensitive   = true
  description = "Grafana Service Account Token"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.react_bucket.id
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.s3_distribution.id
}

output "website_https_url" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.lambda_api.api_endpoint
}