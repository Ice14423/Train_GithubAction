terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # เพิ่ม Provider ของ Grafana
    grafana = {
      source  = "grafana/grafana"
      version = "~> 3.0"
    }
  }

  # Backend เดิมของคุณ
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

# รับค่า URL และ Auth ของ Grafana (ต้องใส่ใน Jenkins Credentials หรือ terraform.tfvars)
variable "grafana_url" { type = string }
variable "grafana_auth" { type = string }

provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_auth
}

# ==========================================
# PART 1: Database (DynamoDB)
# ==========================================
resource "aws_dynamodb_table" "grades_db" {
  name         = "StudentGrades"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "StudentID"
  
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
  bucket = "my-calculator-react-app-production"
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
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.lambda_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.backend.invoke_arn
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
# PART 5: Grafana Monitoring (เพิ่มใหม่)
# ==========================================

# 5.1 สร้าง User ให้ Grafana มาอ่าน CloudWatch
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

# 5.2 เชื่อมต่อ Grafana กับ AWS CloudWatch
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

# 5.3 สร้าง Dashboard (แก้ไข Region ให้ถูกต้องแล้ว)
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
            # ✅ จุดสำคัญที่แก้ให้แล้ว: บังคับ Region ให้ตรงกับ Lambda
            "region": "ap-southeast-2", 
            "stat": "Sum",
            "refId": "A"
          }
        ]
      }
    ]
  })
}

# ==========================================
# Outputs
# ==========================================
output "s3_bucket_name" { value = aws_s3_bucket.react_bucket.id }
output "cloudfront_distribution_id" { value = aws_cloudfront_distribution.s3_distribution.id }
output "website_https_url" { value = aws_cloudfront_distribution.s3_distribution.domain_name }
output "api_endpoint" { value = aws_apigatewayv2_api.lambda_api.api_endpoint }