import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/landmark.dart';
import '../models/pose_frame.dart';

/// Thin adapter mapping Google ML Kit BlazePose output into Fit Odyssey PoseFrame.
/// Isolates native ML Kit types from the core biomechanical engine.
class MlKitPoseAdapter {
  /// Converts ML Kit PoseLandmarkType to standard 0-32 BlazePose index.
  static const Map<PoseLandmarkType, int> _landmarkIndexMap = {
    PoseLandmarkType.nose: 0,
    PoseLandmarkType.leftEyeInner: 1,
    PoseLandmarkType.leftEye: 2,
    PoseLandmarkType.leftEyeOuter: 3,
    PoseLandmarkType.rightEyeInner: 4,
    PoseLandmarkType.rightEye: 5,
    PoseLandmarkType.rightEyeOuter: 6,
    PoseLandmarkType.leftEar: 7,
    PoseLandmarkType.rightEar: 8,
    PoseLandmarkType.leftMouth: 9,
    PoseLandmarkType.rightMouth: 10,
    PoseLandmarkType.leftShoulder: 11,
    PoseLandmarkType.rightShoulder: 12,
    PoseLandmarkType.leftElbow: 13,
    PoseLandmarkType.rightElbow: 14,
    PoseLandmarkType.leftWrist: 15,
    PoseLandmarkType.rightWrist: 16,
    PoseLandmarkType.leftPinky: 17,
    PoseLandmarkType.rightPinky: 18,
    PoseLandmarkType.leftIndex: 19,
    PoseLandmarkType.rightIndex: 20,
    PoseLandmarkType.leftThumb: 21,
    PoseLandmarkType.rightThumb: 22,
    PoseLandmarkType.leftHip: 23,
    PoseLandmarkType.rightHip: 24,
    PoseLandmarkType.leftKnee: 25,
    PoseLandmarkType.rightKnee: 26,
    PoseLandmarkType.leftAnkle: 27,
    PoseLandmarkType.rightAnkle: 28,
    PoseLandmarkType.leftHeel: 29,
    PoseLandmarkType.rightHeel: 30,
    PoseLandmarkType.leftFootIndex: 31,
    PoseLandmarkType.rightFootIndex: 32,
  };

  /// Converts an ML Kit Pose object into a domain PoseFrame.
  static PoseFrame adaptPose(
    Pose? pose, {
    required double timestampSeconds,
    double imageWidth = 1.0,
    double imageHeight = 1.0,
  }) {
    if (pose == null || pose.landmarks.isEmpty) {
      return PoseFrame.undetected(timestampSeconds);
    }

    final landmarks = List<Landmark>.generate(33, (i) {
      return Landmark(
        index: i,
        x: 0.0,
        y: 0.0,
        z: 0.0,
        visibility: 0.0,
      );
    });

    int detectedCount = 0;
    for (final entry in pose.landmarks.entries) {
      final mlIndex = _landmarkIndexMap[entry.key];
      if (mlIndex != null && mlIndex < 33) {
        final lm = entry.value;
        // Normalize 2D image coordinates to [0.0, 1.0] if pixel dimensions provided
        final normX = imageWidth > 1.0 ? lm.x / imageWidth : lm.x;
        final normY = imageHeight > 1.0 ? lm.y / imageHeight : lm.y;
        final normZ = imageHeight > 1.0 ? lm.z / imageHeight : lm.z;

        landmarks[mlIndex] = Landmark(
          index: mlIndex,
          x: normX,
          y: normY,
          z: normZ,
          visibility: lm.likelihood,
        );
        if (lm.likelihood > 0.4) {
          detectedCount++;
        }
      }
    }

    final isDetected = detectedCount >= 18; // At least core body visible

    return PoseFrame(
      landmarks: landmarks,
      timestampSeconds: timestampSeconds,
      isDetected: isDetected,
    );
  }
}
