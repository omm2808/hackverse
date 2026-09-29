export interface Streak {
  id: string;
  userId: string;
  currentStreak: number;
  longestStreak: number;
  lastActivityDate: string;
}

export interface UserGoal {
  id: string;
  userId: string;
  exerciseType: string;
  currentTarget: number;
  previousTarget: number;
  adjustmentReason: string;
  updatedAt: string;
}

export interface ProgressSummary {
  totalWorkouts: number;
  totalReps: number;
  totalActiveMinutes: number;
  currentStreak: number;
  totalXP: number;
  level: number;
  completedChallengesCount: number;
  heritageDistanceKm: number;
}
