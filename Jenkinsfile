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
            
            steps {
                echo '🚀 Deploying to Render...'
               
                sh 'curl -X POST $RENDER_HOOK_URL'
            }
        }
    }
    
    post {
        success { echo '✅ Success!' }
        failure { echo '❌ Failed' }
    }
}