import '../models/landmark.dart';
import '../models/pose_frame.dart';

/// Exponential Moving Average (EMA) smoother for landmark coordinates.
/// Suppresses high-frequency sensor noise and landmark jitter.
class PoseSmoother {
  final double alpha; // Smoothing factor in [0.0, 1.0]. Lower = smoother.
  List<Landmark>? _smoothedLandmarks;

  PoseSmoother({this.alpha = 0.65});

  void reset() {
    _smoothedLandmarks = null;
  }

  PoseFrame smooth(PoseFrame frame) {
    if (!frame.isDetected || frame.landmarks.length < 33) {
      _smoothedLandmarks = null;
      return frame;
    }

    if (_smoothedLandmarks == null || _smoothedLandmarks!.length < 33) {
      _smoothedLandmarks = List<Landmark>.from(frame.landmarks);
      return frame;
    }

    final smoothed = List<Landmark>.generate(33, (i) {
      final curr = frame.landmarks[i];
      final prev = _smoothedLandmarks![i];

      final smoothedX = alpha * curr.x + (1.0 - alpha) * prev.x;
      final smoothedY = alpha * curr.y + (1.0 - alpha) * prev.y;
      final smoothedZ = alpha * curr.z + (1.0 - alpha) * prev.z;

      return Landmark(
        index: i,
        x: smoothedX,
        y: smoothedY,
        z: smoothedZ,
        visibility: curr.visibility,
        presence: curr.presence,
      );
    });

    _smoothedLandmarks = smoothed;

    return PoseFrame(
      landmarks: smoothed,
      timestampSeconds: frame.timestampSeconds,
      isDetected: frame.isDetected,
    );
  }
}
