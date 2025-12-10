pipeline {
    agent any

    stages {
        // 1. ขั้นตอนเตรียมเครื่องและลง Library
        stage('Install Dependencies') {
            steps {
                echo 'Installing requirements...'
                // ติดตั้ง pip (ถ้ายังไม่มี) และลง library ใน requirements.txt
                // ใช้ --break-system-packages กรณี container เป็น Linux รุ่นใหม่
                sh 'apt-get update && apt-get install -y python3-pip' 
                sh 'pip3 install -r requirements.txt --break-system-packages' 
            }
        }

        // 2. ขั้นตอนการรัน Test
        stage('Test with Pytest') {
            environment {
                // ชี้ไปที่ python/src เหมือนเดิมเพื่อให้หา app.py เจอ
                PYTHONPATH = "${env.WORKSPACE}/python/src"
            }
            steps {
                echo 'Running Pytest...'
                // ใช้คำสั่ง pytest โดยระบุโฟลเดอร์ test
                sh 'python3 -m pytest python/test'
            }
        }
    }
}