// src/App.test.js
import { render, screen } from '@testing-library/react';
import App from './App';

test('renders calculator app', () => {
  render(<App />);
  // เปลี่ยนคำค้นหาให้ตรงกับที่เราเขียนใน Calculator.js ("REACT CALC")
  const linkElement = screen.getByText(/REACT CALC/i);
  expect(linkElement).toBeInTheDocument();
});