import { XP_RULES } from '@fit-odyssey/config';

export function calculateWorkoutXP(totalReps: number): number {
  return XP_RULES.WORKOUT_COMPLETION_BASE + totalReps * XP_RULES.XP_PER_REP;
}

export function calculateLevelFromXP(totalXP: number): number {
  if (totalXP <= 0) return 1;
  return Math.floor(Math.sqrt(totalXP / 50)) + 1;
}
