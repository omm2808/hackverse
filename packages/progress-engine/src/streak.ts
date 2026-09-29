export interface StreakUpdateResult {
  newStreak: number;
  longestStreak: number;
  isIncremented: boolean;
}

export function evaluateStreak(
  currentStreak: number,
  longestStreak: number,
  lastActivityDateStr?: string | null,
  currentDate = new Date()
): StreakUpdateResult {
  if (!lastActivityDateStr) {
    return {
      newStreak: 1,
      longestStreak: Math.max(longestStreak, 1),
      isIncremented: true,
    };
  }

  const lastDate = new Date(lastActivityDateStr);
  const diffDays = Math.floor(
    (currentDate.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24)
  );

  if (diffDays === 0) {
    // Already worked out today
    return {
      newStreak: currentStreak,
      longestStreak,
      isIncremented: false,
    };
  } else if (diffDays === 1) {
    // Consecutive day
    const updated = currentStreak + 1;
    return {
      newStreak: updated,
      longestStreak: Math.max(longestStreak, updated),
      isIncremented: true,
    };
  } else {
    // Broken streak
    return {
      newStreak: 1,
      longestStreak,
      isIncremented: true,
    };
  }
}
