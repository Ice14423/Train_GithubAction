pipeline {
    agent any

    stages {
        
        stage('Install Dependencies') {
            steps {
                echo 'Installing requirements...'
              
                sh 'python3 -m venv venv'
                // Activate venv และลงของ
                sh '. venv/bin/activate && pip install -r requirements.txt' 
            }
        }

        stage('Test with Pytest') {
            environment {
                PYTHONPATH = "${env.WORKSPACE}/python/src"
            }
            steps {
                echo 'Running Pytest...'
                // ใช้ python ใน venv รัน test
                sh '. venv/bin/activate && python3 -m pytest python/test'
            }
        }
    }
}