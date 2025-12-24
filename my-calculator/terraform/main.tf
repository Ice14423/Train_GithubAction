# terraform/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # ส่วนนี้สำคัญ! เอาไว้เก็บ State เพื่อไม่ให้สร้างซ้ำซ้อน
  # คุณต้องสร้าง S3 Bucket ชื่อนี้ด้วยมือใน AWS Console ก่อน 1 ครั้ง
  # ตั้งชื่อให้ไม่ซ้ำใคร เช่น "my-terraform-state-store-999"
  backend "s3" {
    bucket = "my-calculator-tf-state-store" 
    key    = "react-app/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

provider "aws" {
  region = "ap-southeast-2" # สิงคโปร์ (ใกล้ไทยสุด)
}

# --- 1. สร้าง S3 Bucket สำหรับเว็บไซต์ ---
resource "aws_s3_bucket" "react_bucket" {
  # ตั้งชื่อ Bucket เว็บไซต์ (ต้องไม่ซ้ำกับใครในโลก)
  bucket = "my-calculator-react-app-production" 
}

# --- 2. ตั้งค่าให้เป็น Web Hosting ---
resource "aws_s3_bucket_website_configuration" "react_website" {
  bucket = aws_s3_bucket.react_bucket.id

  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "index.html"
  }
}

# --- 3. เปิด Public Access (เพื่อให้คนทั่วโลกเข้าเว็บได้) ---
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.react_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# --- 4. อนุญาตให้ทุกคนอ่านไฟล์ได้ (Read Only) ---
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

# ส่งค่าชื่อ Bucket ออกมาให้ GitHub Actions ใช้
output "s3_bucket_name" {
  value = aws_s3_bucket.react_bucket.id
}