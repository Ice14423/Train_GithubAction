pipeline {
    agent any

    tools {
        terraform 'Terraform'
    }

    environment {
        // --- AWS Credentials (ใช้แบบปลอดภัย ดึงจาก Jenkins) ---
       AWS_ACCESS_KEY_ID     = 'AKIAIMW6QF4U755UK27D' 

    // 2. Secret Key ต้องยาว 40 ตัวอักษร
        AWS_SECRET_ACCESS_KEY = '7xRa3xRa3xRa3xRa3xRa3xRa3xRa3xRa3xRa3xRa'
        AWS_DEFAULT_REGION    = 'ap-southeast-2'
        
        // --- Grafana Config ---
        GRAFANA_AUTH          = credentials('grafana-api-token') 
        GRAFANA_URL           = 'https://ice14423.grafana.net' 
        
        TF_IN_AUTOMATION      = 'true'
        PATH                  = "${WORKSPACE}/bin:${env.PATH}"
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
                        // Install Trivy
                        sh 'curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b .'
                        
                        // Install Gitleaks
                        sh 'curl -L -o gitleaks.tar.gz https://github.com/zricethezav/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz'
                        sh 'tar -xzf gitleaks.tar.gz gitleaks'
                        sh 'rm gitleaks.tar.gz'
                        
                        sh 'chmod +x trivy gitleaks'
                    }
                }
            }
        }

        // =========================================================
        // 🛡️ PART 2: ตรวจสอบความปลอดภัย (รันทุกอัน จบแล้วค่อย Fail)
        // =========================================================
        stage('🛡️ Security Checks') {
            steps {
                script {
                    // ลบ Plan เก่าทิ้งก่อน
                    sh 'rm -f terraform/tfplan terraform/tfplan.json'
                    
                    echo '============================================'
                    echo '🔍 STARTING SECURITY AUDIT (ALL CHECKS)'
                    echo '============================================'

                    // 1. ตรวจหา Secret (Gitleaks)
                    // returnStatus: true จะทำให้ไม่ Fail ทันที แต่เก็บผลลัพธ์ (0=ผ่าน, 1=ไม่ผ่าน) ไว้ในตัวแปร
                    echo '🔒 [1/3] Scanning for Secrets (Gitleaks)...'
                    def statusGitleaks = sh(script: 'gitleaks detect --no-git --source . -v', returnStatus: true)

                    // 2. ตรวจ Library (Trivy FS)
                    echo '📦 [2/3] Scanning Dependencies (Trivy FS)...'
                    def statusTrivyFS = sh(script: 'trivy fs --severity HIGH,CRITICAL --exit-code 1 --no-progress .', returnStatus: true)

                    // 3. ตรวจ Terraform (Trivy Config)
                    echo '☁️ [3/3] Scanning Terraform (Trivy IaC)...'
                    def statusTrivyIaC = sh(script: 'trivy config ./terraform --severity HIGH,CRITICAL --exit-code 1', returnStatus: true)

                    // --- สรุปผล ---
                    echo '============================================'
                    echo "📊 SECURITY REPORT SUMMARY"
                    echo "   - Gitleaks (Secrets): ${statusGitleaks == 0 ? '✅ PASS' : '❌ FAIL'}"
                    echo "   - Trivy FS (Deps)   : ${statusTrivyFS == 0 ? '✅ PASS' : '❌ FAIL'}"
                    echo "   - Trivy IaC (Terraform): ${statusTrivyIaC == 0 ? '✅ PASS' : '❌ FAIL'}"
                    echo '============================================'

                    // ถ้ามีอันใดอันหนึ่งไม่ผ่าน (ค่าไม่เท่ากับ 0) ให้สั่ง Error ตรงนี้
                    if (statusGitleaks != 0 || statusTrivyFS != 0 || statusTrivyIaC != 0) {
                        error("⛔ Security Check Failed! Please fix the vulnerabilities listed above.")
                    }
                }
            }
        }
        
        // ... (Stage Build Frontend/Backend เหมือนเดิม) ...
        stage('Frontend: Install & Build') {
            steps {
                dir('grade-app') {
                    sh 'npm ci'
                    sh 'npm run build' 
                }
            }
        }

        stage('Backend: Install & Zip') {
            steps {
                dir('backend-api') {
                    sh 'npm install'
                    sh 'zip -r backend.zip .'
                    sh 'mv backend.zip ../terraform/'
                }
            }
        }

        // --- Infrastructure (IaC) ---
        stage('Infrastructure (IaC)') {
            steps {
                dir('terraform') {
                    echo '🏗️ Provisioning AWS Resources & Monitoring...'
                    sh 'terraform init -upgrade'
                    
                    // ใช้ Single Quote และ $VAR เพื่อความปลอดภัย
                    sh 'terraform plan -out=tfplan -var="grafana_url=$GRAFANA_URL" -var="grafana_auth=$GRAFANA_AUTH"'
                    
                    sh 'terraform apply -auto-approve tfplan'
                    
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
                sh "aws s3 sync ./grade-app/dist s3://${env.BUCKET_NAME} --delete"
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
        cleanup {
            sh 'rm -f terraform/tfplan terraform/backend.zip'
        }
    }
}