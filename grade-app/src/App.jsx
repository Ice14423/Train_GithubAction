import { useState } from 'react';
import { calculateGrade } from './utils';
import './App.css';

// ⚠️ สำคัญ: ตรงนี้คือที่อยู่ของ Backend API ของคุณ
// วิธีที่ 1: ใส่ URL ที่ได้จาก Jenkins/Terraform ตรงนี้เลย (วิธีทดสอบง่ายสุด)
// ตัวอย่าง: const API_URL = "https://abc12345.execute-api.ap-southeast-1.amazonaws.com";
const API_URL = import.meta.env.VITE_API_URL || "https://xotesrj772.execute-api.ap-southeast-2.amazonaws.com";

function App() {
  const [score, setScore] = useState('');
  const [grade, setGrade] = useState('');
  const [subject, setSubject] = useState('');
  const [studentId, setStudentId] = useState('');
  const [isSaving, setIsSaving] = useState(false); // เพิ่มสถานะการโหลด

  const handleCalculate = () => {
    const result = calculateGrade(score);
    setGrade(result);
  };

  const handleSave = async () => {
    if (!studentId || !score) {
      alert("Please enter Student ID and Score");
      return;
    }

    setIsSaving(true); // เริ่มหมุนติ้วๆ

    const payload = {
      StudentID: studentId,
      Subject: subject,
      Score: Number(score), // แปลงเป็นตัวเลขก่อนส่ง
      Grade: grade
    };

    console.log("Sending to Backend...", payload);

    try {
      // 🚀 ยิง Request ไปที่ AWS Lambda ผ่าน API Gateway
      const response = await fetch(`${API_URL}/grades`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        throw new Error(`Error: ${response.statusText}`);
      }

      const data = await response.json();
      console.log("Success:", data);
      alert(`✅ Success! Saved data for Student: ${studentId}`);

    } catch (error) {
      console.error("Save failed:", error);
      alert(`❌ Failed to save: ${error.message}\n(Check Console for details)`);
    } finally {
      setIsSaving(false); // หยุดหมุนไม่ว่าจะสำเร็จหรือไม่
    }
  };

  return (
    <div className="App">
      <div className="card">
        <h1> คำนวณเกรด</h1>
        
      

        <div className="input-group">
          <select 
            value={subject} 
            onChange={(e) => setSubject(e.target.value)}
            className="subject-select"
          >
            <option value="คณิตศาสตร์">คณิตศาสตร์</option>
            <option value="วิทยาศาสตร์">วิทยาศาสตร์</option>
            <option value="ภาษาอังกฤษ">ภาษาอังกฤษ</option>
            <option value="ภาษาไทย">ภาษาไทย</option>
            <option value="สังคมศึกษา">สังคมศึกษา</option>
          </select>
          <input 
            placeholder="ใส่รหัสนักศึกษา" 
            value={studentId} 
            onChange={(e) => setStudentId(e.target.value)} 
          />
          <input 
            type="number" 
            placeholder="ใส่คะแนน (0-100)" 
            value={score} 
            onChange={(e) => setScore(e.target.value)} 
          />
          <button onClick={handleCalculate}>คำนวณ</button>
        </div>
        
        {grade && (
          <div className="result-section">
            <h2>Grade: <span className={`grade-${grade}`}>{grade}</span></h2>
            
            {grade !== 'Invalid' && (
              <button 
                className="save-btn" 
                onClick={handleSave}
                disabled={isSaving} // ป้องกันการกดซ้ำ
                style={{ backgroundColor: isSaving ? '#ccc' : '#4CAF50' }}
              >
                {isSaving ? 'Saving...' : 'Save to DynamoDB'}
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

export default App;