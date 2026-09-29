import { calculateAngle } from '../math';
import {
  AnalysisResult,
  CalibrationResult,
  FormFeedback,
  NormalizedLandmarks,
  PoseLandmark,
} from '../types';
import { BaseExerciseAnalyzer } from './base-analyzer';

export class PlankAnalyzer extends BaseExerciseAnalyzer {
  readonly exerciseId = 'PLANK';
  readonly name = 'Plank';

  private holdStartMs: number | null = null;
  private totalHoldSeconds = 0;

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
      landmarks[PoseLandmark.LEFT_HIP],
      landmarks[PoseLandmark.LEFT_ANKLE],
    ];

    const avgVisibility =
      keyLandmarks.reduce((sum, p) => sum + (p?.visibility ?? 0), 0) / keyLandmarks.length;

    if (avgVisibility < 0.65) {
      return {
        isCalibrated: false,
        message: 'Ensure your full side profile is visible for plank tracking.',
        confidenceScore: avgVisibility,
      };
    }

    return {
      isCalibrated: true,
      message: 'Body calibrated. Ready for plank hold!',
      confidenceScore: avgVisibility,
    };
  }

  analyze(landmarks: NormalizedLandmarks, timestampMs: number): AnalysisResult {
    const feedback: FormFeedback[] = [];

    const shoulder = landmarks[PoseLandmark.LEFT_SHOULDER];
    const hip = landmarks[PoseLandmark.LEFT_HIP];
    const ankle = landmarks[PoseLandmark.LEFT_ANKLE];

    if (!shoulder || !hip || !ankle) {
      this.holdStartMs = null;
      return {
        reps: this.totalHoldSeconds,
        feedback: [{ type: 'WARNING', message: 'Side profile lost' }],
        currentState: 'LOST',
        confidence: 0,
        formScore: 0,
      };
    }

    // Spine angle should be approximately 160-180 degrees
    const bodyAngle = calculateAngle(shoulder, hip, ankle);
    const isGoodForm = bodyAngle >= 155 && bodyAngle <= 185;

    if (isGoodForm) {
      if (!this.holdStartMs) {
        this.holdStartMs = timestampMs;
      } else {
        const holdDelta = Math.floor((timestampMs - this.holdStartMs) / 1000);
        if (holdDelta > 0) {
          this.totalHoldSeconds += holdDelta;
          this.reps = this.totalHoldSeconds;
          this.holdStartMs = timestampMs;
        }
      }
      feedback.push({ type: 'SUCCESS', message: 'Hold steady! Good spine alignment.' });
    } else {
      this.holdStartMs = null;
      if (bodyAngle < 155) {
        feedback.push({ type: 'WARNING', message: 'Avoid sagging hips, keep core tight' });
      } else {
        feedback.push({ type: 'WARNING', message: 'Lower your hips slightly to align torso' });
      }
    }

    return {
      reps: this.totalHoldSeconds,
      feedback,
      currentState: isGoodForm ? 'HOLDING' : 'IMPROPER_FORM',
      confidence: hip.visibility ?? 1,
      formScore: isGoodForm ? 95 : 60,
    };
  }

  override reset(): void {
    super.reset();
    this.holdStartMs = null;
    this.totalHoldSeconds = 0;
  }
}
