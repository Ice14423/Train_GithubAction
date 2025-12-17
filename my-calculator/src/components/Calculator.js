// src/components/Calculator.js
import React, { useState } from 'react';
import { add, subtract, multiply, divide } from '../utils/Calculator';

const Calculator = () => {
  const [num1, setNum1] = useState('');
  const [num2, setNum2] = useState('');
  const [result, setResult] = useState(null);

  const handleCalculation = (operation) => {
    const n1 = parseFloat(num1);
    const n2 = parseFloat(num2);

    if (isNaN(n1) || isNaN(n2)) {
      setResult('Please enter valid numbers');
      return;
    }

    try {
      let res;
      switch (operation) {
        case '+':
          res = add(n1, n2);
          break;
        case '-':
          res = subtract(n1, n2);
          break;
        case '*':
          res = multiply(n1, n2);
          break;
        case '/':
          res = divide(n1, n2);
          break;
        default:
          return;
      }
      setResult(res);
    } catch (error) {
      setResult(error.message);
    }
  };

  return (
    <div style={{ padding: '20px', border: '1px solid #ccc', width: '300px' }}>
      <h2>React Calculator</h2>
      
      <div style={{ marginBottom: '10px' }}>
        <input
          type="number"
          value={num1}
          onChange={(e) => setNum1(e.target.value)}
          placeholder="Number 1"
          style={{ width: '100%', marginBottom: '5px' }}
        />
        <input
          type="number"
          value={num2}
          onChange={(e) => setNum2(e.target.value)}
          placeholder="Number 2"
          style={{ width: '100%' }}
        />
      </div>

      <div style={{ display: 'flex', gap: '5px', marginBottom: '10px' }}>
        <button onClick={() => handleCalculation('+')}>+</button>
        <button onClick={() => handleCalculation('-')}>-</button>
        <button onClick={() => handleCalculation('*')}>*</button>
        <button onClick={() => handleCalculation('/')}>/</button>
      </div>

      <div style={{ fontWeight: 'bold' }}>
        Result: {result !== null ? result : '-'}
      </div>
    </div>
  );
};

export default Calculator;