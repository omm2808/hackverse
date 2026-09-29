export interface BadgeEvaluationContext {
  totalWorkouts: number;
  totalReps: number;
  currentStreak: number;
  completedCheckpoints: number;
}

export function evaluateEligibleBadges(context: BadgeEvaluationContext): string[] {
  const eligibleBadges: string[] = [];

  if (context.totalWorkouts >= 1) {
    eligibleBadges.push('FIRST_WORKOUT');
  }
  if (context.currentStreak >= 7) {
    eligibleBadges.push('7_DAY_STREAK');
  }
  if (context.totalReps >= 100) {
    eligibleBadges.push('100_REPS');
  }
  if (context.totalReps >= 500) {
    eligibleBadges.push('500_REPS');
  }
  if (context.completedCheckpoints >= 1) {
    eligibleBadges.push('FIRST_HERITAGE_CHECKPOINT');
  }

  return eligibleBadges;
}
