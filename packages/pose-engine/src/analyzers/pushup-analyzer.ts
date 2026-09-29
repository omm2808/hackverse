import { calculateAngle } from '../math';
import {
  AnalysisResult,
  CalibrationResult,
  FormFeedback,
  NormalizedLandmarks,
  PoseLandmark,
} from '../types';
import { BaseExerciseAnalyzer } from './base-analyzer';

export type PushUpState = 'PLANK_HIGH' | 'DESCENDING' | 'BOTTOM' | 'ASCENDING';

export class PushUpAnalyzer extends BaseExerciseAnalyzer {
  readonly exerciseId = 'PUSHUP';
  readonly name = 'Push-up';

  private pushUpState: PushUpState = 'PLANK_HIGH';

  checkCalibration(landmarks: NormalizedLandmarks): CalibrationResult {
    if (landmarks.length < 33) {
      return {
        isCalibrated: false,
        message: 'Full body landmarks not detected.',
        confidenceScore: 0,
      };
    }

    const keyLandmarks = [
      landmarks[PoseLandmark.LEFT_SHOULDER],
      landmarks[PoseLandmark.LEFT_ELBOW],
      landmarks[PoseLandmark.LEFT_WRIST],
      landmarks[PoseLandmark.LEFT_HIP],
      landmarks[PoseLandmark.LEFT_ANKLE],
    ];

    const avgVisibility =
      keyLandmarks.reduce((sum, p) => sum + (p?.visibility ?? 0), 0) / keyLandmarks.length;

    if (avgVisibility < 0.65) {
      return {
        isCalibrated: false,
        message: 'Ensure your upper body and arms are clearly visible from the side.',
        confidenceScore: avgVisibility,
      };
    }

    return {
      isCalibrated: true,
      message: 'Body calibrated. Ready for push-ups!',
      confidenceScore: avgVisibility,
    };
  }

  analyze(landmarks: NormalizedLandmarks, _timestampMs: number): AnalysisResult {
    const feedback: FormFeedback[] = [];

    const shoulder = landmarks[PoseLandmark.LEFT_SHOULDER];
    const elbow = landmarks[PoseLandmark.LEFT_ELBOW];
    const wrist = landmarks[PoseLandmark.LEFT_WRIST];

    if (!shoulder || !elbow || !wrist) {
      return {
        reps: this.reps,
        feedback: [{ type: 'WARNING', message: 'Arms not clearly visible' }],
        currentState: this.pushUpState,
        confidence: 0,
        formScore: 0,
      };
    }

    const elbowAngle = calculateAngle(shoulder, elbow, wrist);

    switch (this.pushUpState) {
      case 'PLANK_HIGH':
        if (elbowAngle < 150) {
          this.pushUpState = 'DESCENDING';
        }
        break;

      case 'DESCENDING':
        if (elbowAngle <= 95) {
          this.pushUpState = 'BOTTOM';
          feedback.push({ type: 'SUCCESS', message: 'Good depth on push-up!' });
        } else if (elbowAngle > 155) {
          this.pushUpState = 'PLANK_HIGH';
          feedback.push({ type: 'INFO', message: 'Lower chest closer to ground' });
        }
        break;

      case 'BOTTOM':
        if (elbowAngle > 105) {
          this.pushUpState = 'ASCENDING';
        }
        break;

      case 'ASCENDING':
        if (elbowAngle >= 155) {
          this.pushUpState = 'PLANK_HIGH';
          this.reps += 1;
          feedback.push({ type: 'SUCCESS', message: 'Rep counted!' });
        }
        break;
    }

    return {
      reps: this.reps,
      feedback,
      currentState: this.pushUpState,
      confidence: elbow.visibility ?? 1,
      formScore: Math.round(Math.max(0, Math.min(100, 100 - Math.abs(elbowAngle - 90)))),
    };
  }

  override reset(): void {
    super.reset();
    this.pushUpState = 'PLANK_HIGH';
  }
}
