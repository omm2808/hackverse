import 'dart:math' as math;
import '../classifier/pose_classifier_service.dart';
import '../models/pose_frame.dart';
import '../models/prediction_result.dart';
import 'exercise_state_machine.dart';

/// Deterministic state machine for Push-up tracking with inflection-point form classification.
class PushupStateMachine implements ExerciseStateMachine {
  final PoseClassifierService classifierService;

  @override
  String get exerciseName => 'push_up';

  int _repCount = 0;
  @override
  int get repCount => _repCount;

  ExerciseState _currentState = ExerciseState.plankHigh;
  @override
  ExerciseState get currentState => _currentState;

  RepAnalysisResult? _latestRepResult;
  @override
  RepAnalysisResult? get latestRepResult => _latestRepResult;

  // Thresholds (degrees)
  static const double highPlankElbowThreshold = 140.0;
  static const double descendingThreshold = 130.0;
  static const double bottomDepthThreshold = 100.0;
  static const double maxAcceptableDepth = 108.0;
  static const double ascendingThreshold = 115.0;

  // Rep tracking state
  double? _repStartTimeSeconds;
  double _minElbowAngleInRep = 180.0;
  double _maxElbowInAscending = 0.0;
  PredictionResult? _bottomPrediction;
  List<double>? _bottomFeatures;
  double? _lastRepCompletionTime;

  PushupStateMachine({required this.classifierService});

  @override
  void reset() {
    _repCount = 0;
    _currentState = ExerciseState.plankHigh;
    _latestRepResult = null;
    _repStartTimeSeconds = null;
    _minElbowAngleInRep = 180.0;
    _maxElbowInAscending = 0.0;
    _bottomPrediction = null;
    _bottomFeatures = null;
    _lastRepCompletionTime = null;
  }

  @override
  RepAnalysisResult? processFrame(PoseFrame frame, List<double> features) {
    if (!frame.hasMinimumVisibility()) {
      return null;
    }

    // Extract elbow angles from feature vector (Indices 103 & 104)
    final leftElbow = features[103];
    final rightElbow = features[104];

    // Compute effective elbow angle:
    // In side-camera view, the far arm is occluded behind the torso and BlazePose
    // falsely reports it near 150°-170°. The camera-facing arm flexes to ~90°.
    // If the asymmetry is significant (> 20°), trust the flexing arm (min angle)
    // which accurately reflects true chest-to-floor descent.
    final double effectiveElbow;
    if ((leftElbow - rightElbow).abs() > 20.0) {
      effectiveElbow = math.min(leftElbow, rightElbow);
    } else {
      effectiveElbow = (leftElbow + rightElbow) / 2.0;
    }

    // Trunk inclination (Index 109) — push-ups are performed horizontally (~40°-95°)
    final trunkAngle = features[109];
    // Hip alignment (Indices 101 & 102: hip flexion angle)
    final leftHipAngle = features[101];
    final rightHipAngle = features[102];
    final avgHipAngle = (leftHipAngle + rightHipAngle) / 2.0;

    final t = frame.timestampSeconds;

    switch (_currentState) {
      case ExerciseState.plankHigh:
      case ExerciseState.standing:
        // Debounce cooldown
        if (_lastRepCompletionTime != null && (t - _lastRepCompletionTime!) < 0.35) {
          return null;
        }

        // Push-ups require horizontal body alignment (trunk inclination >= 30 deg from vertical)
        // Standing upright (0°-20°) is rejected.
        if (trunkAngle >= 30.0 && effectiveElbow < descendingThreshold) {
          _currentState = ExerciseState.descending;
          _repStartTimeSeconds = t;
          _minElbowAngleInRep = effectiveElbow;
          _maxElbowInAscending = 0.0;
          _bottomPrediction = null;
          _bottomFeatures = null;
        }
        break;

      case ExerciseState.descending:
        if (effectiveElbow < _minElbowAngleInRep) {
          _minElbowAngleInRep = effectiveElbow;
        }

        // Check if bottom depth reached or inflection reached
        if (effectiveElbow <= bottomDepthThreshold) {
          _currentState = ExerciseState.bottom;
          _bottomFeatures = List<double>.from(features);

          // Evaluate form specifically at the BOTTOM inflection point!
          _bottomPrediction = classifierService.predict(
            _bottomFeatures!,
            enforceExercise: 'push_up',
          );
        } else if (effectiveElbow > _minElbowAngleInRep + 7.0) {
          // Rebound before reaching parallel bottomDepthThreshold
          if (_minElbowAngleInRep <= maxAcceptableDepth) {
            // Reached acceptable push-up depth (<= 108 deg)
            _currentState = ExerciseState.bottom;
            _bottomFeatures = List<double>.from(features);
            _bottomPrediction = classifierService.predict(
              _bottomFeatures!,
              enforceExercise: 'push_up',
            );
          } else if (effectiveElbow >= highPlankElbowThreshold) {
            // Arm bounce in plank without descending to push-up depth
            _currentState = ExerciseState.plankHigh;
            _minElbowAngleInRep = 180.0;
            _bottomPrediction = null;
            _bottomFeatures = null;
            return null;
          }
        }
        break;

      case ExerciseState.bottom:
        if (effectiveElbow < _minElbowAngleInRep) {
          _minElbowAngleInRep = effectiveElbow;
          _bottomFeatures = List<double>.from(features);
          _bottomPrediction = classifierService.predict(
            _bottomFeatures!,
            enforceExercise: 'push_up',
          );
        }

        if (effectiveElbow >= highPlankElbowThreshold) {
          // Rapid push straight to high plank
          _repCount++;
          _lastRepCompletionTime = t;
          _currentState = ExerciseState.plankHigh;
          return _generateCompletedRepResult(t, trunkAngle, avgHipAngle);
        } else if (effectiveElbow >= ascendingThreshold) {
          _currentState = ExerciseState.ascending;
          _maxElbowInAscending = effectiveElbow;
        }
        break;

      case ExerciseState.ascending:
        _maxElbowInAscending = math.max(_maxElbowInAscending, effectiveElbow);

        // Returns to high plank lockout -> Rep completed!
        if (effectiveElbow >= highPlankElbowThreshold) {
          _repCount++;
          _lastRepCompletionTime = t;
          _currentState = ExerciseState.plankHigh;
          return _generateCompletedRepResult(t, trunkAngle, avgHipAngle);
        } else if (_maxElbowInAscending >= 132.0 && effectiveElbow < _maxElbowInAscending - 8.0) {
          // Continuous fluid reps: ascended near lockout and immediately started next descent
          _repCount++;
          _lastRepCompletionTime = t;
          _currentState = ExerciseState.descending;
          _repStartTimeSeconds = t;
          final completed = _generateCompletedRepResult(t, trunkAngle, avgHipAngle);
          _minElbowAngleInRep = effectiveElbow;
          _maxElbowInAscending = 0.0;
          return completed;
        }
        break;

      default:
        _currentState = ExerciseState.plankHigh;
    }

    return null;
  }

  RepAnalysisResult _generateCompletedRepResult(
    double t,
    double trunkAngle,
    double avgHipAngle,
  ) {
    final durationMs = _repStartTimeSeconds != null
        ? math.max(200, ((t - _repStartTimeSeconds!) * 1000).toInt())
        : 1500;

    final activeFlags = <String>[];
    String finalFormStatus = 'good';
    double finalConfidence = _bottomPrediction?.formConfidence ?? 0.90;

    // Biomechanical verification: depth
    if (_minElbowAngleInRep > 105.0) {
      finalFormStatus = 'bad';
      activeFlags.add('INSUFFICIENT_DEPTH');
    }

    // Biomechanical verification: hip sag or pike
    if (avgHipAngle < 140.0) {
      finalFormStatus = 'bad';
      activeFlags.add('HIP_SAG_OR_PIKE');
    }

    String feedback;
    if (activeFlags.contains('INSUFFICIENT_DEPTH') && activeFlags.contains('HIP_SAG_OR_PIKE')) {
      feedback = 'Descend deeper and keep body in a straight line.';
    } else if (activeFlags.contains('INSUFFICIENT_DEPTH')) {
      feedback = 'Descend deeper — reach 90° elbow flexion.';
    } else if (activeFlags.contains('HIP_SAG_OR_PIKE')) {
      feedback = 'Keep your body in a straight line — engage core.';
    } else {
      finalFormStatus = 'good';
      feedback = _minElbowAngleInRep <= 85.0
          ? 'Deep push-up! Excellent chest depth.'
          : 'Solid push-up form!';
    }

    final repResult = RepAnalysisResult(
      repNumber: _repCount,
      exercise: 'push_up',
      formStatus: finalFormStatus,
      formConfidence: finalConfidence,
      activeFlags: activeFlags,
      feedback: feedback,
      durationMs: durationMs,
      peakMetrics: {
        'minElbowAngle': double.parse(_minElbowAngleInRep.toStringAsFixed(1)),
        'trunkInclination': double.parse(trunkAngle.toStringAsFixed(1)),
        'hipAlignment': double.parse(avgHipAngle.toStringAsFixed(1)),
      },
    );

    _latestRepResult = repResult;
    _minElbowAngleInRep = 180.0;
    return repResult;
  }
}
