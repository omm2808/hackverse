export type WorkoutStatus = 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED';
export type SyncStatus = 'PENDING' | 'SYNCED' | 'FAILED';

export interface ExerciseResult {
  id: string;
  workoutSessionId: string;
  exerciseId: string;
  reps: number;
  durationSeconds: number;
  score: number;
  averageFormAccuracy: number;
  metrics?: Record<string, number | string | boolean>;
  createdAt: string;
}

export interface WorkoutSession {
  id: string;
  userId: string;
  startedAt: string;
  endedAt?: string | null;
  durationSeconds: number;
  status: WorkoutStatus;
  totalReps: number;
  totalScore: number;
  xpEarned: number;
  syncStatus: SyncStatus;
  results: ExerciseResult[];
  createdAt: string;
}
