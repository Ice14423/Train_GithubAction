pipeline {
    agent any

    environment {
        RENDER_HOOK_URL = credentials('render-deploy-hook')
        CI = 'true' 
    }

    stages {
        stage('Check Environment') {
             steps {
                 sh 'node -v'
                 sh 'npm -v'
             }
        }

        stage('Install Dependencies') {
            steps {
                dir('my-calculator') {
                    echo '📦 Installing dependencies...'
                    sh 'npm ci'
                }
            }
        }

        stage('Test') {
            steps {
                dir('my-calculator') {
                    echo '🧪 Running Tests...'
                    sh 'npm test'
                }
            }
        }

        stage('Build') {
            steps {
                dir('my-calculator') {
                    echo '🏗️ Building Project...'
                    sh 'npm run build'
                }
            }
        }

        stage('Deploy to Render') {
            // ❌ ลบส่วน when { branch 'set/dev' } ออกไปเลยครับ
            // เพราะเราตั้งค่าที่ตัว Job ให้ทำแค่ branch นี้อยู่แล้ว
            steps {
                echo '🚀 Deploying to Render...'
                // ยิง Webhook บอก Render ให้ Deploy
                sh "curl -X POST ${RENDER_HOOK_URL}"
            }
        }
    }
    
    post {
        success { echo '✅ Success!' }
        failure { echo '❌ Failed' }
    }
}