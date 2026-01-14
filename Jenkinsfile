pipeline {
    agent any

    tools {
        // ต้องมั่นใจว่าตั้งชื่อ 'Terraform' ใน Jenkins Global Tool Configuration ตรงกัน
        terraform 'Terraform'
        // nodejs 'NodeJS' // (แนะนำ) ถ้าใน Jenkins มีการตั้งค่า Node ไว้ควรเปิดใช้
    }

    environment {
        // --- AWS Credentials (ดึงจาก Jenkins Credentials เท่านั้น!) ---
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        AWS_DEFAULT_REGION    = 'ap-southeast-2'
        
        // --- Grafana Config ---
        // 1. ดึง Token จาก Credentials
        GRAFANA_AUTH          = credentials('grafana-api-token') 
        // 2. URL ของ Grafana
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
        // 🛡️ PART 1: ติดตั้งเครื่องมือ Security
        // =========================================================
        stage('🛠️ Setup Security Tools') {
            steps {
                script {
                    sh 'mkdir -p bin'
                    dir('bin') {
                        echo '⬇️ Installing Security Scanners...'
                        // 1. Install Trivy
                        sh 'curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b .'
                        
                        // 2. Install Gitleaks
                        sh 'curl -L -o gitleaks.tar.gz https://github.com/zricethezav/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz'
                        sh 'tar -xzf gitleaks.tar.gz gitleaks'
                        sh 'rm gitleaks.tar.gz'
                        
                        sh 'chmod +x trivy gitleaks'
                    }
                }
            }
        }

        // =========================================================
        // 🛡️ PART 2: ตรวจสอบความปลอดภัย
        // =========================================================
        stage('🛡️ Security Checks') {
            steps {
                // 1. ตรวจหา Secret
                echo '🔒 [1/3] Scanning for Secrets...'
                sh 'gitleaks detect --source . -v'

                // 2. ตรวจ Library (SCA)
                echo '📦 [2/3] Scanning Dependencies...'
                sh 'trivy fs --severity HIGH,CRITICAL --exit-code 1 --no-progress .'

                // 3. ตรวจ Terraform (IaC)
                echo '☁️ [3/3] Scanning Terraform...'
                // หมายเหตุ: รอบนี้จะผ่าน เพราะเราแก้ main.tf แล้ว
                sh 'trivy config ./terraform --severity HIGH,CRITICAL --exit-code 1'
            }
        }
        

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
                    sh 'zip -r backend.zip .'
                    
                    // ย้ายไฟล์ zip ไปไว้ในโฟลเดอร์ terraform เพื่อให้ Terraform หาเจอ
                    sh 'mv backend.zip ../terraform/'
                }
            }
        }

        // --- Infrastructure (IaC) ---
        stage('Infrastructure (IaC)') {
            steps {
                dir('terraform') {
                    echo '🏗️ Provisioning AWS Resources & Monitoring...'
                    
                    // [UPDATED] เพิ่ม -upgrade เพื่อรองรับ provider ใหม่ (alias)
                    sh 'terraform init -upgrade'
                    
                    // ส่งค่าตัวแปร Grafana เข้าไปตอน Plan
                    sh """
                        terraform plan -out=tfplan \
                        -var="grafana_url=${GRAFANA_URL}" \
                        -var="grafana_auth=${GRAFANA_AUTH}"
                    """
                    
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