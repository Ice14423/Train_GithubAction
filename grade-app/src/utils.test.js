import { calculateGrade } from './utils';

describe('Grade Calculation Logic', () => {
  test('should return A for score 85', () => {
    expect(calculateGrade(85)).toBe('A');
  });

  test('should return F for score 40', () => {
    expect(calculateGrade(40)).toBe('F');
  });

  test('should return Invalid for negative score', () => {
    expect(calculateGrade(-5)).toBe('Invalid');
  });
});