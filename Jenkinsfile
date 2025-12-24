pipeline {
    agent any

    tools {
        // ใช้ Node และ Terraform ที่ตั้งค่าไว้
        
        terraform 'Terraform'
    }

    environment {
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
                 sh 'aws --version'
                 // เช็คว่ามี zip ไหม (จำเป็นสำหรับ backend)
                 sh 'zip -v' 
             }
        }

        // --- ส่วน Frontend ---
        stage('Frontend: Install & Build') {
            steps {
                dir('grade-app') {
                    echo '📦 Frontend: Installing...'
                    sh 'npm ci'
                    echo '🔨 Frontend: Building...'
                    // Build ปกติ (ในอนาคตเราจะเอา API URL มาใส่ตรงนี้แบบอัตโนมัติ)
                    sh 'npm run build' 
                }
            }
        }

        // --- ส่วน Backend (ใหม่!) ---
        stage('Backend: Install & Zip') {
            steps {
                dir('backend-api') {
                    echo '📦 Backend: Installing dependencies...'
                    sh 'npm install' // ติดตั้ง express และ aws-sdk
                    
                    echo '🗜️ Backend: Zipping for Lambda...'
                    // Zip ไฟล์ทั้งหมดเพื่อเตรียมส่งให้ Terraform
                    sh 'zip -r backend.zip .'
                    
                    // ย้ายไฟล์ zip ไปไว้ในโฟลเดอร์ terraform
                    sh 'mv backend.zip ../terraform/'
                }
            }
        }

        // --- Infrastructure ---
        stage('Infrastructure (IaC)') {
            steps {
                dir('terraform') {
                    echo '🏗️ Provisioning AWS Resources...'
                    sh 'terraform init'
                    sh 'terraform plan -out=tfplan'
                    sh 'terraform apply -auto-approve tfplan'
                    
                    script {
                        env.BUCKET_NAME = sh(script: "terraform output -raw s3_bucket_name", returnStdout: true).trim()
                        env.CLOUDFRONT_ID = sh(script: "terraform output -raw cloudfront_distribution_id", returnStdout: true).trim()
                        env.WEB_URL = sh(script: "terraform output -raw website_https_url", returnStdout: true).trim()
                        // ดึง API URL ออกมา
                        env.API_URL = sh(script: "terraform output -raw api_endpoint", returnStdout: true).trim()
                    }
                }
            }
        }

        // --- Deploy Frontend ---
        stage('Deploy Frontend to AWS') {
            steps {
                echo "🚀 Deploying to S3 Bucket: ${env.BUCKET_NAME}"
                sh "aws s3 sync ./grade-app/dist s3://${env.BUCKET_NAME} --delete"
                
                echo '🔄 Invalidating CloudFront Cache...'
                sh "aws cloudfront create-invalidation --distribution-id ${env.CLOUDFRONT_ID} --paths '/*'"
            }
        }
    }
    
    post {
        success { 
            echo "✅ Deployment Success!" 
            echo "🌐 Website URL: https://${env.WEB_URL}"
            echo "🔌 API URL: ${env.API_URL}"
        }
        failure { 
            echo "❌ Pipeline Failed" 
        }
    }
}