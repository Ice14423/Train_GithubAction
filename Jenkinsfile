pipeline {
    agent any

    tools {
        // ต้องไปตั้งชื่อใน Global Tool Config ให้ตรงกัน
        nodejs 'NodeJS 20' 
        terraform 'Terraform'
    }

    environment {
        // ID นี้ต้องไปสร้างใน Jenkins Credentials (ชนิด AWS Credentials)
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        AWS_DEFAULT_REGION    = 'ap-southeast-2'
        TF_IN_AUTOMATION      = 'true'
    }

    stages {
        stage('Check Environment') {
             steps {
                 sh 'node -v'
                 sh 'terraform -version'
             }
        }

        stage('Verify AWS CLI') {
             steps {
                sh 'aws --version'
        // ลองเช็ค S3 (ถ้าตั้งค่า Credentials แล้ว)
                sh 'aws s3 ls' 
            }
        }

        stage('Install Dependencies') {
            steps {
                dir('grade-app') {
                    echo '📦 Installing dependencies...'
                    sh 'npm ci'
                }
            }
        }

        stage('Test Logic') {
            steps {
                dir('grade-app') {
                    echo '🧪 Running Tests (Jest)...'
                    // รัน test ที่เราเขียนไว้ใน utils.test.js
                    sh 'npm test -- --watchAll=false' 
                }
            }
        }

        stage('Infrastructure (IaC)') {
            steps {
                dir('terraform') {
                    echo '🏗️ Provisioning AWS Resources...'
                    sh 'terraform init'
                    sh 'terraform plan -out=tfplan'
                    sh 'terraform apply -auto-approve tfplan'
                    
                    // เก็บชื่อ Bucket และ CloudFront ID ไว้ใช้ในขั้นตอน Deploy
                    script {
                        env.BUCKET_NAME = sh(script: "terraform output -raw s3_bucket_name", returnStdout: true).trim()
                        env.CLOUDFRONT_ID = sh(script: "terraform output -raw cloudfront_distribution_id", returnStdout: true).trim()
                        env.WEB_URL = sh(script: "terraform output -raw website_https_url", returnStdout: true).trim()
                    }
                }
            }
        }

        stage('Build React App') {
            steps {
                dir('grade-app') {
                    echo '🔨 Building Project...'
                    sh 'npm run build'
                }
            }
        }

        stage('Deploy to AWS') {
            steps {
                echo '🚀 Deploying to S3...'
                // อัปโหลดไฟล์จากโฟลเดอร์ dist ขึ้น S3
                sh "aws s3 sync ./grade-app/dist s3://${env.BUCKET_NAME} --delete"

                echo '🔄 Invalidating CloudFront Cache...'
                // ล้าง Cache เพื่อให้เว็บอัปเดตทันที
                sh "aws cloudfront create-invalidation --distribution-id ${env.CLOUDFRONT_ID} --paths '/*'"
            }
        }
    }
    
    post {
        success { 
            echo "✅ Deployment Success!" 
            echo "🌐 Website URL: https://${env.WEB_URL}"
        }
        failure { 
            echo "❌ Pipeline Failed" 
        }
    }
}