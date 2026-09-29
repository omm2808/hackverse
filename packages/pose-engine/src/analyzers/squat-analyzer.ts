import { calculateAngle } from '../math';
import {
  AnalysisResult,
  CalibrationResult,
  FormFeedback,
  NormalizedLandmarks,
  PoseLandmark,
} from '../types';
import { BaseExerciseAnalyzer } from './base-analyzer';

export type SquatState = 'STANDING' | 'DESCENDING' | 'BOTTOM' | 'ASCENDING';

export class SquatAnalyzer extends BaseExerciseAnalyzer {
  readonly exerciseId = 'SQUAT';
  readonly name = 'Squat';

  private squatState: SquatState = 'STANDING';

  checkCalibration(landmarks: NormalizedLandmarks): CalibrationResult {
    if (landmarks.length < 33) {
      return {
        isCalibrated: false,
        message: 'Full body landmarks not detected.',
        confidenceScore: 0,
      };
    }

    const keyLandmarks = [
      landmarks[PoseLandmark.LEFT_HIP],
      landmarks[PoseLandmark.RIGHT_HIP],
      landmarks[PoseLandmark.LEFT_KNEE],
      landmarks[PoseLandmark.RIGHT_KNEE],
      landmarks[PoseLandmark.LEFT_ANKLE],
      landmarks[PoseLandmark.RIGHT_ANKLE],
    ];

    const avgVisibility =
      keyLandmarks.reduce((sum, p) => sum + (p?.visibility ?? 0), 0) / keyLandmarks.length;

    if (avgVisibility < 0.65) {
      return {
        isCalibrated: false,
        message: 'Ensure your hips, knees, and ankles are fully visible to the camera.',
        confidenceScore: avgVisibility,
      };
    }

    return {
      isCalibrated: true,
      message: 'Body calibrated. Ready to begin squats!',
      confidenceScore: avgVisibility,
    };
  }

  analyze(landmarks: NormalizedLandmarks, _timestampMs: number): AnalysisResult {
    const feedback: FormFeedback[] = [];

    const leftHip = landmarks[PoseLandmark.LEFT_HIP];
    const leftKnee = landmarks[PoseLandmark.LEFT_KNEE];
    const leftAnkle = landmarks[PoseLandmark.LEFT_ANKLE];

    if (!leftHip || !leftKnee || !leftAnkle) {
      return {
        reps: this.reps,
        feedback: [{ type: 'WARNING', message: 'Tracking confidence low' }],
        currentState: this.squatState,
        confidence: 0,
        formScore: 0,
      };
    }

    const kneeAngle = calculateAngle(leftHip, leftKnee, leftAnkle);

    // State machine transitions
    // Standing: angle > 160 deg
    // Descending: 100 < angle <= 160
    // Bottom: angle <= 100 deg (good depth)
    switch (this.squatState) {
      case 'STANDING':
        if (kneeAngle < 150) {
          this.squatState = 'DESCENDING';
        }
        break;

      case 'DESCENDING':
        if (kneeAngle <= 100) {
          this.squatState = 'BOTTOM';
          feedback.push({ type: 'SUCCESS', message: 'Good depth!' });
        } else if (kneeAngle > 160) {
          // Returned before reaching depth
          this.squatState = 'STANDING';
          feedback.push({ type: 'INFO', message: 'Go slightly lower' });
        }
        break;

      case 'BOTTOM':
        if (kneeAngle > 110) {
          this.squatState = 'ASCENDING';
        }
        break;

      case 'ASCENDING':
        if (kneeAngle >= 160) {
          this.squatState = 'STANDING';
          this.reps += 1;
          feedback.push({ type: 'SUCCESS', message: 'Great repetition!' });
        }
        break;
    }

    return {
      reps: this.reps,
      feedback,
      currentState: this.squatState,
      confidence: leftKnee.visibility ?? 1,
      formScore: Math.round(Math.max(0, Math.min(100, 100 - Math.abs(kneeAngle - 90)))),
    };
  }

  override reset(): void {
    super.reset();
    this.squatState = 'STANDING';
  }
}
