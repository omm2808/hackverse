import 'dart:math' as math;
import '../models/landmark.dart';

/// Result of landmark normalization containing normalized keypoints and torso reference metrics.
class NormalizedPose {
  final List<Landmark> landmarks;
  final List<double> midHip;
  final double scale;

  const NormalizedPose({
    required this.landmarks,
    required this.midHip,
    required this.scale,
  });
}

/// Normalizes 33 body landmarks relative to mid-hip anchor and torso length.
/// Mirrors Python `ml.preprocessing.normalize` exactly.
class LandmarkNormalizer {
  /// Computes mid-hip center (origin) and torso scale factor.
  static NormalizedPose normalize(List<Landmark> landmarks) {
    if (landmarks.length < 33) {
      return NormalizedPose(
        landmarks: landmarks,
        midHip: const [0.0, 0.0, 0.0],
        scale: 1.0,
      );
    }

    final leftHip = landmarks[Landmark.leftHip];
    final rightHip = landmarks[Landmark.rightHip];
    final leftShoulder = landmarks[Landmark.leftShoulder];
    final rightShoulder = landmarks[Landmark.rightShoulder];

    final midHipX = (leftHip.x + rightHip.x) / 2.0;
    final midHipY = (leftHip.y + rightHip.y) / 2.0;
    final midHipZ = (leftHip.z + rightHip.z) / 2.0;

    final midShoulderX = (leftShoulder.x + rightShoulder.x) / 2.0;
    final midShoulderY = (leftShoulder.y + rightShoulder.y) / 2.0;
    final midShoulderZ = (leftShoulder.z + rightShoulder.z) / 2.0;

    // Torso vector from mid-hip to mid-shoulder
    final dx = midShoulderX - midHipX;
    final dy = midShoulderY - midHipY;
    final dz = midShoulderZ - midHipZ;
    final torsoLen = math.sqrt(dx * dx + dy * dy + dz * dz);

    double scale;
    if (torsoLen > 1e-4) {
      scale = torsoLen;
    } else {
      // Fallback to shoulder width
      final sx = leftShoulder.x - rightShoulder.x;
      final sy = leftShoulder.y - rightShoulder.y;
      final sz = leftShoulder.z - rightShoulder.z;
      final shoulderWidth = math.sqrt(sx * sx + sy * sy + sz * sz);
      scale = shoulderWidth > 1e-4 ? shoulderWidth : 1.0;
    }

    final normalizedLandmarks = List<Landmark>.generate(33, (i) {
      final lm = landmarks[i];
      return Landmark(
        index: i,
        x: (lm.x - midHipX) / scale,
        y: (lm.y - midHipY) / scale,
        z: (lm.z - midHipZ) / scale,
        visibility: lm.visibility,
        presence: lm.presence,
      );
    });

    return NormalizedPose(
      landmarks: normalizedLandmarks,
      midHip: [midHipX, midHipY, midHipZ],
      scale: scale,
    );
  }
}
