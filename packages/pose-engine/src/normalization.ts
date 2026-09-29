import { NormalizedLandmarks, PoseLandmark } from './types';

/**
 * Normalizes 33 pose landmarks relative to the mid-hip point and torso scale.
 * Ensures model features are invariant to camera distance, user height, and 2D translation.
 */
export function normalizeLandmarks(landmarks: NormalizedLandmarks): NormalizedLandmarks {
  if (landmarks.length < 33) return landmarks;

  const leftHip = landmarks[PoseLandmark.LEFT_HIP];
  const rightHip = landmarks[PoseLandmark.RIGHT_HIP];
  const leftShoulder = landmarks[PoseLandmark.LEFT_SHOULDER];
  const rightShoulder = landmarks[PoseLandmark.RIGHT_SHOULDER];

  if (!leftHip || !rightHip || !leftShoulder || !rightShoulder) {
    return landmarks;
  }

  const midHipX = (leftHip.x + rightHip.x) / 2;
  const midHipY = (leftHip.y + rightHip.y) / 2;
  const midHipZ = ((leftHip.z ?? 0) + (rightHip.z ?? 0)) / 2;

  const midShoulderX = (leftShoulder.x + rightShoulder.x) / 2;
  const midShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
  const midShoulderZ = ((leftShoulder.z ?? 0) + (rightShoulder.z ?? 0)) / 2;

  // Torso length scale factor
  const torsoLength = Math.sqrt(
    Math.pow(midShoulderX - midHipX, 2) +
    Math.pow(midShoulderY - midHipY, 2) +
    Math.pow(midShoulderZ - midHipZ, 2)
  );

  const scale = torsoLength > 1e-4 ? torsoLength : 1.0;

  return landmarks.map((lm) => ({
    x: (lm.x - midHipX) / scale,
    y: (lm.y - midHipY) / scale,
    z: ((lm.z ?? 0) - midHipZ) / scale,
    visibility: lm.visibility,
  }));
}
