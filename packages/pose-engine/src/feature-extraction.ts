import { calculateAngle } from './math';
import { NormalizedLandmarks, PoseLandmark } from './types';

/**
 * Extracts a 16-dimensional feature vector from normalized landmarks
 * for consumption by Layer 2 custom trained ML models.
 */
export function extractLandmarkFeatures(normalizedLandmarks: NormalizedLandmarks): number[] {
  if (normalizedLandmarks.length < 33) {
    return new Array(16).fill(0);
  }

  const leftKneeAngle = calculateAngle(
    normalizedLandmarks[PoseLandmark.LEFT_HIP]!,
    normalizedLandmarks[PoseLandmark.LEFT_KNEE]!,
    normalizedLandmarks[PoseLandmark.LEFT_ANKLE]!
  );

  const rightKneeAngle = calculateAngle(
    normalizedLandmarks[PoseLandmark.RIGHT_HIP]!,
    normalizedLandmarks[PoseLandmark.RIGHT_KNEE]!,
    normalizedLandmarks[PoseLandmark.RIGHT_ANKLE]!
  );

  const leftHipAngle = calculateAngle(
    normalizedLandmarks[PoseLandmark.LEFT_SHOULDER]!,
    normalizedLandmarks[PoseLandmark.LEFT_HIP]!,
    normalizedLandmarks[PoseLandmark.LEFT_KNEE]!
  );

  const rightHipAngle = calculateAngle(
    normalizedLandmarks[PoseLandmark.RIGHT_SHOULDER]!,
    normalizedLandmarks[PoseLandmark.RIGHT_HIP]!,
    normalizedLandmarks[PoseLandmark.RIGHT_KNEE]!
  );

  const leftElbowAngle = calculateAngle(
    normalizedLandmarks[PoseLandmark.LEFT_SHOULDER]!,
    normalizedLandmarks[PoseLandmark.LEFT_ELBOW]!,
    normalizedLandmarks[PoseLandmark.LEFT_WRIST]!
  );

  const rightElbowAngle = calculateAngle(
    normalizedLandmarks[PoseLandmark.RIGHT_SHOULDER]!,
    normalizedLandmarks[PoseLandmark.RIGHT_ELBOW]!,
    normalizedLandmarks[PoseLandmark.RIGHT_WRIST]!
  );

  const leftShoulderAngle = calculateAngle(
    normalizedLandmarks[PoseLandmark.LEFT_ELBOW]!,
    normalizedLandmarks[PoseLandmark.LEFT_SHOULDER]!,
    normalizedLandmarks[PoseLandmark.LEFT_HIP]!
  );

  const rightShoulderAngle = calculateAngle(
    normalizedLandmarks[PoseLandmark.RIGHT_ELBOW]!,
    normalizedLandmarks[PoseLandmark.RIGHT_SHOULDER]!,
    normalizedLandmarks[PoseLandmark.RIGHT_HIP]!
  );

  return [
    leftKneeAngle / 180.0,
    rightKneeAngle / 180.0,
    leftHipAngle / 180.0,
    rightHipAngle / 180.0,
    leftElbowAngle / 180.0,
    rightElbowAngle / 180.0,
    leftShoulderAngle / 180.0,
    rightShoulderAngle / 180.0,
    normalizedLandmarks[PoseLandmark.LEFT_KNEE]?.y ?? 0,
    normalizedLandmarks[PoseLandmark.RIGHT_KNEE]?.y ?? 0,
    normalizedLandmarks[PoseLandmark.LEFT_HIP]?.y ?? 0,
    normalizedLandmarks[PoseLandmark.RIGHT_HIP]?.y ?? 0,
    normalizedLandmarks[PoseLandmark.LEFT_SHOULDER]?.y ?? 0,
    normalizedLandmarks[PoseLandmark.RIGHT_SHOULDER]?.y ?? 0,
    normalizedLandmarks[PoseLandmark.LEFT_WRIST]?.y ?? 0,
    normalizedLandmarks[PoseLandmark.RIGHT_WRIST]?.y ?? 0,
  ];
}
