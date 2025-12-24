// บันทึกไฟล์ชื่อ: src/utils.js
export function calculateGrade(score) {
  const numScore = Number(score);

  if (score === '' || isNaN(numScore) || numScore < 0 || numScore > 100) {
    return 'Invalid';
  }

  if (numScore >= 80) return 'A';
  if (numScore >= 75) return 'B+';
  if (numScore >= 70) return 'B';
  if (numScore >= 65) return 'C+';
  if (numScore >= 60) return 'C';
  if (numScore >= 55) return 'D+';
  if (numScore >= 50) return 'D';

  return 'F';
}