// src/components/Calculator.js
import React, { useState } from 'react';
import { add, subtract, multiply, divide } from '../utils/calculator';
import './Calculator.css'; // อย่าลืม import ไฟล์ CSS ที่สร้างเมื่อกี้

const Calculator = () => {
  const [num1, setNum1] = useState('');
  const [num2, setNum2] = useState('');
  const [result, setResult] = useState(null);

  const handleCalculation = (operation) => {
    const n1 = parseFloat(num1);
    const n2 = parseFloat(num2);

    if (isNaN(n1) || isNaN(n2)) {
      setResult('Invalid Input');
      return;
    }

    try {
      let res;
      switch (operation) {
        case '+': res = add(n1, n2); break;
        case '-': res = subtract(n1, n2); break;
        case '*': res = multiply(n1, n2); break;
        case '/': res = divide(n1, n2); break;
        default: return;
      }
      // ปัดเศษทศนิยมไม่ให้ยาวเกินไป (ถ้าจำเป็น)
      setResult(Number.isInteger(res) ? res : res.toFixed(4)); 
    } catch (error) {
      setResult('Error');
    }
  };

  return (
    <div className="calculator-card">
      <h2 className="calculator-title">REACT CALC</h2>
      
      <div className="input-group">
        <input
          className="input-field"
          type="number"
          value={num1}
          onChange={(e) => setNum1(e.target.value)}
          placeholder="Enter 1st number"
        />
        <input
          className="input-field"
          type="number"
          value={num2}
          onChange={(e) => setNum2(e.target.value)}
          placeholder="Enter 2nd number"
        />
      </div>

      <div className="button-group">
        <button className="calc-btn" onClick={() => handleCalculation('+')}>+</button>
        <button className="calc-btn" onClick={() => handleCalculation('-')}>−</button>
        <button className="calc-btn" onClick={() => handleCalculation('*')}>×</button>
        <button className="calc-btn" onClick={() => handleCalculation('/')}>÷</button>
      </div>

      <div className="result-box">
        <span className="result-label">RESULT</span>
        <div className="result-value">
          {result !== null ? result : '0'}
        </div>
      </div>
    </div>
  );
};

export default Calculator;