// src/App.test.js
import { render, screen } from '@testing-library/react';
import App from './App';

test('renders calculator app', () => {
  render(<App />);
  // เปลี่ยนจากหาคำว่า /learn react/ เป็น /React Calculator/ แทน
  // เพราะใน Calculator.js เรามี <h2>React Calculator</h2> อยู่
  const linkElement = screen.getByText(/React Calculator/i);
  expect(linkElement).toBeInTheDocument();
});