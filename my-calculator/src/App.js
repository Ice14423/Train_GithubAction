// src/App.js

// 1. ลบ import logo เดิมออก (ถ้าไม่ได้ใช้)
import './App.css'; 

// 2. เพิ่มบรรทัดนี้ เพื่อดึงไฟล์ Calculator ที่เราสร้างไว้มาใช้
import Calculator from './components/Calculator'; 

function App() {
  return (
    <div className="App">
      <header className="App-header">
        
        {/* 3. ลบ Code เดิม (img, p, a) ออก แล้วใส่ Tag ของเราลงไปแทน */}
        <Calculator />

      </header>
    </div>
  );
}

export default App;