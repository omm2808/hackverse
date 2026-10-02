import '../models/pose_frame.dart';
import '../models/prediction_result.dart';
import 'exercise_state_machine.dart';

/// Isometric state machine for Plank tracking.
/// Measures hold duration and spine alignment angle (155°–185°).
class PlankStateMachine implements ExerciseStateMachine {
  @override
  String get exerciseName => 'plank';

  int _holdDurationSeconds = 0;
  @override
  int get repCount => _holdDurationSeconds; // Displays hold seconds as primary metric

  ExerciseState _currentState = ExerciseState.plankHigh;
  @override
  ExerciseState get currentState => _currentState;

  RepAnalysisResult? _latestRepResult;
  @override
  RepAnalysisResult? get latestRepResult => _latestRepResult;

  double? _holdStartTimeSeconds;
  double? _lastSecondMark;

  @override
  void reset() {
    _holdDurationSeconds = 0;
    _currentState = ExerciseState.plankHigh;
    _latestRepResult = null;
    _holdStartTimeSeconds = null;
    _lastSecondMark = null;
  }

  @override
  RepAnalysisResult? processFrame(PoseFrame frame, List<double> features) {
    if (!frame.hasMinimumVisibility()) {
      return null;
    }

    final t = frame.timestampSeconds;
    // Trunk inclination (index 109)
    final trunkAngle = features[109];
    // Hip alignment (indices 101 & 102)
    final avgHipAngle = (features[101] + features[102]) / 2.0;

    // Plank is active when body is horizontal (trunk ~70°-95°) and body is straight
    final isStraightBody = avgHipAngle >= 155.0 && avgHipAngle <= 195.0;
    final isHorizontal = trunkAngle >= 70.0 && trunkAngle <= 98.0;

    if (isHorizontal && isStraightBody) {
      _currentState = ExerciseState.plankHold;
      _holdStartTimeSeconds ??= t;
      _lastSecondMark ??= t;

      if (t - _lastSecondMark! >= 1.0) {
        _holdDurationSeconds += (t - _lastSecondMark!).floor();
        _lastSecondMark = t;

        _latestRepResult = RepAnalysisResult(
          repNumber: _holdDurationSeconds,
          exercise: 'plank',
          formStatus: 'good',
          formConfidence: 0.95,
          activeFlags: const [],
          feedback: 'Hold steady! Core engaged.',
          durationMs: ((t - _holdStartTimeSeconds!) * 1000).toInt(),
          peakMetrics: {
            'hipAlignment': double.parse(avgHipAngle.toStringAsFixed(1)),
            'trunkInclination': double.parse(trunkAngle.toStringAsFixed(1)),
          },
        );
        return _latestRepResult;
      }
    } else {
      _currentState = ExerciseState.plankHigh;
      _holdStartTimeSeconds = null;
      _lastSecondMark = null;

      final flags = <String>[];
      if (avgHipAngle < 155.0) flags.add('HIP_SAG');
      if (avgHipAngle > 195.0) flags.add('HIP_PIKE');

      if (flags.isNotEmpty) {
        _latestRepResult = RepAnalysisResult(
          repNumber: _holdDurationSeconds,
          exercise: 'plank',
          formStatus: 'bad',
          formConfidence: 0.85,
          activeFlags: flags,
          feedback: flags.contains('HIP_SAG')
              ? 'Lift your hips — avoid sagging.'
              : 'Lower your hips — flatten your back.',
          durationMs: 0,
          peakMetrics: {
            'hipAlignment': double.parse(avgHipAngle.toStringAsFixed(1)),
          },
        );
      }
    }

    return null;
  }
}
