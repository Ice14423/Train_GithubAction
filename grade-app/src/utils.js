export const calculateGrade = (score) => {
  const numScore = parseFloat(score);
  if (isNaN(numScore) || numScore < 0 || numScore > 100) return 'Invalid';
  if (numScore >= 80) return 'A';
  if (numScore >= 70) return 'B';
  if (numScore >= 60) return 'C';
  if (numScore >= 50) return 'D';
  return 'F';
};