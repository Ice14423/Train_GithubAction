pipeline {
    agent any  // เปลี่ยนจาก docker {...} เป็น any

    // บอก Jenkins ว่างานนี้ขอใช้เครื่องมือชื่อ node-20 (ที่เราตั้งไว้ในขั้นตอนที่ 2)
    tools {
        nodejs 'node-20'
    }

    environment {
        RENDER_HOOK_URL = credentials('render-deploy-hook')
        CI = 'true' 
    }

    stages {
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
            when {
                branch 'set/dev'
            }
            steps {
                echo '🚀 Deploying to Render (set/dev)...'
                sh "curl -X POST ${RENDER_HOOK_URL}"
            }
        }
    }
    
    post {
        success { echo '✅ Success!' }
        failure { echo '❌ Failed' }
    }
}