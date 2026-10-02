import 'landmark.dart';

/// Single video frame representation containing 33 pose landmarks.
class PoseFrame {
  final List<Landmark> landmarks;
  final double timestampSeconds;
  final bool isDetected;

  const PoseFrame({
    required this.landmarks,
    required this.timestampSeconds,
    required this.isDetected,
  });

  /// Factory for an undetected / occluded frame.
  factory PoseFrame.undetected(double timestampSeconds) {
    return PoseFrame(
      landmarks: List.generate(
        33,
        (i) => Landmark(index: i, x: 0.0, y: 0.0, z: 0.0, visibility: 0.0),
      ),
      timestampSeconds: timestampSeconds,
      isDetected: false,
    );
  }

  /// Verifies if core anatomical landmarks (shoulders, hips, knees) are visible.
  bool hasMinimumVisibility({double minConfidence = 0.5}) {
    if (!isDetected || landmarks.length < 33) return false;
    final coreIndices = [
      Landmark.leftShoulder,
      Landmark.rightShoulder,
      Landmark.leftHip,
      Landmark.rightHip,
      Landmark.leftKnee,
      Landmark.rightKnee,
    ];
    for (final idx in coreIndices) {
      if (landmarks[idx].visibility < minConfidence) {
        return false;
      }
    }
    return true;
  }
}
