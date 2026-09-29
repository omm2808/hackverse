import {
  AnalysisResult,
  CalibrationResult,
  ExerciseAnalyzer,
  NormalizedLandmarks,
} from '../types';

export abstract class BaseExerciseAnalyzer implements ExerciseAnalyzer {
  abstract readonly exerciseId: string;
  abstract readonly name: string;

  protected reps = 0;
  protected state = 'INITIAL';

  abstract checkCalibration(landmarks: NormalizedLandmarks): CalibrationResult;
  abstract analyze(landmarks: NormalizedLandmarks, timestampMs: number): AnalysisResult;

  reset(): void {
    this.reps = 0;
    this.state = 'INITIAL';
  }

  getReps(): number {
    return this.reps;
  }
}
