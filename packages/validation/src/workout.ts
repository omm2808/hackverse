import { z } from 'zod';

export const startWorkoutSchema = z.object({
  id: z.string().uuid().optional(),
  startedAt: z.string().datetime().optional(),
});

export type StartWorkoutInput = z.infer<typeof startWorkoutSchema>;

export const submitExerciseResultSchema = z.object({
  exerciseId: z.string().min(1),
  reps: z.number().int().nonnegative(),
  durationSeconds: z.number().nonnegative(),
  score: z.number().nonnegative().default(0),
  averageFormAccuracy: z.number().min(0).max(100).default(100),
  metrics: z.record(z.union([z.number(), z.string(), z.boolean()])).optional(),
});

export type SubmitExerciseResultInput = z.infer<typeof submitExerciseResultSchema>;

export const completeWorkoutSchema = z.object({
  endedAt: z.string().datetime().optional(),
  results: z.array(submitExerciseResultSchema),
});

export type CompleteWorkoutInput = z.infer<typeof completeWorkoutSchema>;
