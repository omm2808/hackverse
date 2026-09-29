export type ExerciseType = 'SQUAT' | 'PUSHUP' | 'PLANK';

export interface ExerciseDefinition {
  id: string;
  type: ExerciseType;
  name: string;
  description: string;
  targetMuscles: string[];
  defaultRepGoal: number;
  xpPerRep: number;
}
