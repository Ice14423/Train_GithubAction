// src/utils/calculator.test.js
import { add, subtract, multiply, divide } from './calculator';

// เทียบเท่า def test_add():
test('adds 1 + 2 to equal 3', () => {
  expect(add(1, 2)).toBe(3);
});

// เทียบเท่า def test_subtract():
test('subtracts 4 - 2 to equal 2', () => {
  expect(subtract(4, 2)).toBe(2);
});

// เทียบเท่า def test_multiply():
test('multiplies 9 * 5 to equal 45', () => {
  expect(multiply(9, 5)).toBe(45);
});

// เทียบเท่า def test_divide():
test('divides 7 / 2 to equal 3.5', () => {
  expect(divide(7, 2)).toBe(3.5);
});