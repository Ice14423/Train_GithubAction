pipeline {
    agent {
        docker {
            image 'node:20' 
            args '-u root:root' // แก้ปัญหา Permission ใน Docker
        }
    }

    environment {
        // ดึง URL จาก Jenkins Credentials
        RENDER_HOOK_URL = credentials('render-deploy-hook')
        CI = 'true' 
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                dir('my-calculator') {
                    echo '📦 Installing dependencies...'
                    // npm ci เร็วกว่า npm install และเหมาะสำหรับ CI server
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
            // เงื่อนไข: ทำเฉพาะเมื่ออยู่บน Branch 'set/dev' เท่านั้น
            when {
                branch 'set/dev'
            }
            steps {
                echo '🚀 Deploying to Render (set/dev)...'
                // ยิง Webhook บอก Render
                sh "curl -X POST ${RENDER_HOOK_URL}"
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline Succeeded!'
        }
        failure {
            echo '❌ Pipeline Failed!'
        }
    }
}