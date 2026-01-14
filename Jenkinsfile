pipeline {
    agent any

    tools {
        // ใช้ Node และ Terraform ที่ตั้งค่าไว้ใน Jenkins Global Tool Configuration
        terraform 'Terraform'
        // (แนะนำ) ควรระบุชื่อ NodeJS ที่ตั้งไว้ใน Jenkins ด้วย ถ้ามี
    }

    environment {
        // --- AWS Credentials ---
        AWS_ACCESS_KEY_ID     = 'AKIAIMW6QF4U755UK27D' 

    // 2. Secret Key ต้องยาว 40 ตัวอักษร
        AWS_SECRET_ACCESS_KEY = '7xRa3xRa3xRa3xRa3xRa3xRa3xRa3xRa3xRa3xRa'
       /* AWS_ACCESS_KEY_ID   = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')*/
        AWS_DEFAULT_REGION    = 'ap-southeast-2'
        
        // --- Grafana Config (เพิ่มใหม่) ---
        // 1. ดึง Token จาก Credentials ที่เราเพิ่งสร้าง
        GRAFANA_AUTH          = credentials('grafana-api-token') 
        // 2. ใส่ URL ของคุณตรงนี้ (แก้เป็น URL ของคุณเอง!)
        GRAFANA_URL           = 'https://ice14423.grafana.net' 
        
        TF_IN_AUTOMATION      = 'true'
        PATH = "${WORKSPACE}/bin:${env.PATH}"
    }

    stages {
        stage('Check Environment') {
             steps {
                 sh 'node -v'
                 sh 'terraform -version'
                 sh 'aws --version'
                 sh 'zip -v' 
             }
        }


        // =========================================================
        // 🛡️ PART 1: ติดตั้งเครื่องมือ Security (แทรกตรงนี้)
        // =========================================================
        stage('🛠️ Setup Security Tools') {
            steps {
                script {
                    sh 'mkdir -p bin' // สร้างโฟลเดอร์ชั่วคราว
                    dir('bin') {
                        echo '⬇️ Installing Security Scanners...'
                        
                        // 1. Install Trivy
                        sh 'curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b .'
                        
                        // 2. Install Gitleaks (Linux amd64)
                        sh 'curl -L -o gitleaks.tar.gz https://github.com/zricethezav/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz'
                        sh 'tar -xzf gitleaks.tar.gz gitleaks'
                        sh 'rm gitleaks.tar.gz'
                        
                        sh 'chmod +x trivy gitleaks'
                    }
                }
            }
        }

        // =========================================================
        // 🛡️ PART 2: ตรวจสอบความปลอดภัย (แทรกตรงนี้)
        // =========================================================
        stage('🛡️ Security Checks') {
            steps {
                // 1. ตรวจหา Secret
                echo '🔒 [1/3] Scanning for Secrets...'
                
                sh 'gitleaks detect --no-git --source . -v'

                // 2. ตรวจ Library (SCA)
                echo '📦 [2/3] Scanning Dependencies...'
                sh 'trivy fs --severity HIGH,CRITICAL --exit-code 1 --no-progress .'

                // 3. ตรวจ Terraform (IaC)
                echo '☁️ [3/3] Scanning Terraform...'
                sh 'trivy config ./terraform --severity HIGH,CRITICAL --exit-code 1'
            }
        }
        
//test
        // --- ส่วน Frontend ---
        stage('Frontend: Install & Build') {
            steps {
                dir('grade-app') {
                    echo '📦 Frontend: Installing...'
                    sh 'npm ci'
                    echo '🔨 Frontend: Building...'
                    sh 'npm run build' 
                }
            }
        }

        // --- ส่วน Backend ---
        stage('Backend: Install & Zip') {
            steps {
                dir('backend-api') {
                    echo '📦 Backend: Installing dependencies...'
                    sh 'npm install'
                    
                    echo '🗜️ Backend: Zipping for Lambda...'
                    // Zip ไฟล์ทั้งหมด (อย่าลืมจุด . ข้างหลัง)
                    sh 'zip -r backend.zip .'
                    
                    // ย้ายไฟล์ zip ไปไว้ในโฟลเดอร์ terraform
                    sh 'mv backend.zip ../terraform/'
                }
            }
        }

        // --- Infrastructure (IaC) ---
        stage('Infrastructure (IaC)') {
            steps {
                dir('terraform') {
                    echo '🏗️ Provisioning AWS Resources & Monitoring...'
                    
                    sh 'terraform init'
                    
                    // [UPDATED] ส่งค่าตัวแปร Grafana เข้าไปตอน Plan
                    sh """
                        terraform plan -out=tfplan \
                        -var="grafana_url=${GRAFANA_URL}" \
                        -var="grafana_auth=${GRAFANA_AUTH}"
                    """
                    
                    // ตอน Apply ไม่ต้องส่งตัวแปรซ้ำ เพราะมันถูกฝังอยู่ใน tfplan แล้ว
                    sh 'terraform apply -auto-approve tfplan'
                    
                    // ดึง Output ค่าต่างๆ ออกมาใช้งาน
                    script {
                        env.BUCKET_NAME   = sh(script: "terraform output -raw s3_bucket_name", returnStdout: true).trim()
                        env.CLOUDFRONT_ID = sh(script: "terraform output -raw cloudfront_distribution_id", returnStdout: true).trim()
                        env.WEB_URL       = sh(script: "terraform output -raw website_https_url", returnStdout: true).trim()
                        env.API_URL       = sh(script: "terraform output -raw api_endpoint", returnStdout: true).trim()
                    }
                }
            }
        }

        // --- Deploy Frontend ---
        stage('Deploy Frontend to AWS') {
            steps {
                // (Optional) ในอนาคตถ้าจะแก้ Frontend ให้ยิง API ได้จริง 
                // เราอาจจะต้อง Replace URL ในไฟล์ JS ก่อน Sync แต่วันนี้เอาแค่นี้ก่อน
                
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
            echo "📊 Grafana Dashboard: ${env.GRAFANA_URL}/dashboards"
        }
        failure { 
            echo "❌ Pipeline Failed" 
        }
    }
}