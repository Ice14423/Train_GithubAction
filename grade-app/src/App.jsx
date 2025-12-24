// src/App.jsx
import { useState } from 'react';
import { calculateGrade } from './utils'; // เราต้องสร้างไฟล์นี้ในข้อ 2
import './App.css';

function App() {
  const [score, setScore] = useState('');
  const [grade, setGrade] = useState('');
  const [studentId, setStudentId] = useState('');

  const handleCalculate = () => {
    const result = calculateGrade(score);
    setGrade(result);
  };

  const handleSave = () => {
    // จำลองการส่งข้อมูล (ในอนาคตจะยิงไป AWS API Gateway ตรงนี้)
    const payload = {
      StudentID: studentId,
      Subject: 'Math',
      Score: score,
      Grade: grade
    };
    console.log("Saving to DynamoDB...", payload);
    alert(`Saved data for Student: ${studentId}\nGrade: ${grade}`);
  };

  return (
    <div className="App">
      <div className="card">
        <h1>Grade Calculator</h1>
        <div className="input-group">
          <input 
            placeholder="Student ID" 
            value={studentId} 
            onChange={(e) => setStudentId(e.target.value)} 
          />
          <input 
            type="number" 
            placeholder="Enter Score (0-100)" 
            value={score} 
            onChange={(e) => setScore(e.target.value)} 
          />
          <button onClick={handleCalculate}>Calculate Grade</button>
        </div>
        
        {grade && (
          <div className="result-section">
            <h2>Grade: <span className={`grade-${grade}`}>{grade}</span></h2>
            
            {grade !== 'Invalid' && (
              <button className="save-btn" onClick={handleSave}>
                Save to Database
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

export default App;