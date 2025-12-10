pipeline {
    agent any

    stages {
        // ขั้นตอนนี้แก้ใหม่: ไม่ต้อง apt-get แล้ว สั่ง pip install ได้เลย
        stage('Install Dependencies') {
            steps {
                echo 'Installing requirements...'
                // สร้าง virtual environment เพื่อแก้ปัญหา permission ของ pip
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