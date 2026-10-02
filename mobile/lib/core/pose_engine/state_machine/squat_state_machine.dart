import 'dart:math' as math;
import '../classifier/pose_classifier_service.dart';
import '../models/pose_frame.dart';
import '../models/prediction_result.dart';
import 'exercise_state_machine.dart';
import 'squat_rep_gate.dart';

/// Deterministic state machine for Squat tracking with multi-signal candidate gating
/// and inflection-point form classification.
class SquatStateMachine implements ExerciseStateMachine {
  final PoseClassifierService classifierService;
  final SquatGateConfig gateConfig;
  late final SquatRepGate _gate;

  @override
  String get exerciseName => 'squat';

  int _repCount = 0;
  @override
  int get repCount => _repCount;

  ExerciseState _currentState = ExerciseState.standing;
  @override
  ExerciseState get currentState => _currentState;

  RepAnalysisResult? _latestRepResult;
  @override
  RepAnalysisResult? get latestRepResult => _latestRepResult;

  // Thresholds (degrees)
  static const double standingKneeThreshold = 150.0;
  static const double descendingThreshold = 140.0;
  static const double bottomDepthThreshold = 105.0; // Parallel/deep squat depth
  static const double ascendingThreshold = 120.0;

  // Candidate tracking state
  BodyMetrics? _lastStandingMetrics;
  SquatCandidateTracker? _candidateTracker;
  double? _repStartTimeSeconds;
  double _minKneeAngleInRep = 180.0;
  double _maxTrunkAngleInRep = 0.0;
  PredictionResult? _bottomPrediction;
  List<double>? _bottomFeatures;
  double? _lastRepCompletionTime;
  String? _lastRejectionReason;

  /// Diagnostic telemetry of most recent candidate rejection reason.
  String? get lastRejectionReason => _lastRejectionReason;

  SquatStateMachine({
    required this.classifierService,
    SquatGateConfig? gateConfig,
  })  : gateConfig = gateConfig ?? const SquatGateConfig(),
        _gate = SquatRepGate(config: gateConfig ?? const SquatGateConfig());

  @override
  void reset() {
    _repCount = 0;
    _currentState = ExerciseState.standing;
    _latestRepResult = null;
    _repStartTimeSeconds = null;
    _minKneeAngleInRep = 180.0;
    _maxTrunkAngleInRep = 0.0;
    _bottomPrediction = null;
    _bottomFeatures = null;
    _candidateTracker = null;
    _lastStandingMetrics = null;
    _lastRepCompletionTime = null;
    _lastRejectionReason = null;
  }

  void _resetCandidate() {
    _currentState = ExerciseState.standing;
    _candidateTracker = null;
    _minKneeAngleInRep = 180.0;
    _maxTrunkAngleInRep = 0.0;
    _bottomPrediction = null;
    _bottomFeatures = null;
  }

  @override
  RepAnalysisResult? processFrame(PoseFrame frame, List<double> features) {
    if (!frame.hasMinimumVisibility()) {
      return null;
    }

    // Extract knee angles from feature vector (Indices 99 & 100)
    final leftKnee = features[99];
    final rightKnee = features[100];
    final avgKnee = (leftKnee + rightKnee) / 2.0;
    final trunkAngle = features[109]; // Index 109 = angle_trunk_inclination

    final t = frame.timestampSeconds;

    switch (_currentState) {
      case ExerciseState.standing:
        // Continually track standing reference pose while knees are extended
        if (avgKnee >= descendingThreshold) {
          _lastStandingMetrics = BodyMetrics.fromFrame(frame);
        }

        if (avgKnee < descendingThreshold) {
          // Check debounce cooldown
          if (_lastRepCompletionTime != null &&
              (t - _lastRepCompletionTime!) < gateConfig.cooldownSeconds) {
            return null;
          }

          // A. Bilateral Knee Participation check before initiating candidate
          final kneeDiff = (leftKnee - rightKnee).abs();
          if (kneeDiff > gateConfig.maxBilateralKneeDiff ||
              leftKnee >= gateConfig.maxSingleKneeDescentThreshold ||
              rightKnee >= gateConfig.maxSingleKneeDescentThreshold) {
            _lastRejectionReason = 'INIT_REJECT_UNILATERAL_OR_ASYMMETRIC';
            return null;
          }

          // Valid bilateral descent initiation
          _currentState = ExerciseState.descending;
          _repStartTimeSeconds = t;
          _minKneeAngleInRep = avgKnee;
          _bottomPrediction = null;
          _bottomFeatures = null;

          final startMetrics = _lastStandingMetrics ?? BodyMetrics.fromFrame(frame);

          _candidateTracker = SquatCandidateTracker(
            startTime: t,
            startMetrics: startMetrics,
          );

          _candidateTracker!.recordFrame(
            frame: frame,
            leftKnee: leftKnee,
            rightKnee: rightKnee,
            state: ExerciseState.descending,
            descentThreshold: descendingThreshold,
          );

          // Evaluate unconstrained exercise classifier
          final exPred = classifierService.predict(features);
          _candidateTracker!.recordClassifierPrediction(
            exPred.predictedClass,
            exPred.confidence,
          );
        }
        break;

      case ExerciseState.descending:
        _maxTrunkAngleInRep = math.max(_maxTrunkAngleInRep, trunkAngle);

        // Timeout safeguard
        if (_candidateTracker != null &&
            (t - _candidateTracker!.startTime) > gateConfig.maxRepDurationSeconds) {
          _lastRejectionReason = 'REJECT_DURATION_TIMEOUT';
          _resetCandidate();
          return null;
        }

        _candidateTracker?.recordFrame(
          frame: frame,
          leftKnee: leftKnee,
          rightKnee: rightKnee,
          state: ExerciseState.descending,
          descentThreshold: descendingThreshold,
        );

        final exPred = classifierService.predict(features);
        _candidateTracker?.recordClassifierPrediction(
          exPred.predictedClass,
          exPred.confidence,
        );

        if (avgKnee < _minKneeAngleInRep) {
          _minKneeAngleInRep = avgKnee;
        }

        // Check if bottom depth reached or inflection reached
        if (avgKnee <= bottomDepthThreshold) {
          _currentState = ExerciseState.bottom;
          _bottomFeatures = List<double>.from(features);

          // Evaluate form specifically at the BOTTOM inflection point
          _bottomPrediction = classifierService.predict(
            _bottomFeatures!,
            enforceExercise: 'squat',
          );

          _candidateTracker?.recordBottomInflection(
            exPred.predictedClass,
            exPred.confidence,
          );
        } else if (avgKnee > _minKneeAngleInRep + 6.0) {
          // Rebound before reaching parallel bottomDepthThreshold
          if (_minKneeAngleInRep <= gateConfig.maxKneeDepthThreshold) {
            // Reached acceptable squat depth (e.g. shallow squat <= 118 deg)
            _currentState = ExerciseState.bottom;
            _bottomFeatures = List<double>.from(features);

            _bottomPrediction = classifierService.predict(
              _bottomFeatures!,
              enforceExercise: 'squat',
            );

            _candidateTracker?.recordBottomInflection(
              exPred.predictedClass,
              exPred.confidence,
            );
          } else {
            // Rebounded while still essentially standing (walking step / weight shift)
            _lastRejectionReason = 'REJECT_INSUFFICIENT_KNEE_DEPTH';
            _resetCandidate();
            return null;
          }
        }
        break;

      case ExerciseState.bottom:
        _maxTrunkAngleInRep = math.max(_maxTrunkAngleInRep, trunkAngle);

        if (_candidateTracker != null &&
            (t - _candidateTracker!.startTime) > gateConfig.maxRepDurationSeconds) {
          _lastRejectionReason = 'REJECT_DURATION_TIMEOUT';
          _resetCandidate();
          return null;
        }

        _candidateTracker?.recordFrame(
          frame: frame,
          leftKnee: leftKnee,
          rightKnee: rightKnee,
          state: ExerciseState.bottom,
          descentThreshold: descendingThreshold,
        );

        final exPredBottom = classifierService.predict(features);
        _candidateTracker?.recordClassifierPrediction(
          exPredBottom.predictedClass,
          exPredBottom.confidence,
        );

        if (avgKnee < _minKneeAngleInRep) {
          _minKneeAngleInRep = avgKnee;
          // Refresh prediction if user descends even deeper
          _bottomFeatures = List<double>.from(features);
          _bottomPrediction = classifierService.predict(
            _bottomFeatures!,
            enforceExercise: 'squat',
          );
          _candidateTracker?.recordBottomInflection(
            exPredBottom.predictedClass,
            exPredBottom.confidence,
          );
        }

        if (avgKnee >= standingKneeThreshold) {
          // Rapid ascension straight to standing -> Gate validation
          return _attemptCompleteRep(frame, t, trunkAngle);
        } else if (avgKnee >= ascendingThreshold) {
          _currentState = ExerciseState.ascending;
        }
        break;

      case ExerciseState.ascending:
        _maxTrunkAngleInRep = math.max(_maxTrunkAngleInRep, trunkAngle);

        if (_candidateTracker != null &&
            (t - _candidateTracker!.startTime) > gateConfig.maxRepDurationSeconds) {
          _lastRejectionReason = 'REJECT_DURATION_TIMEOUT';
          _resetCandidate();
          return null;
        }

        _candidateTracker?.recordFrame(
          frame: frame,
          leftKnee: leftKnee,
          rightKnee: rightKnee,
          state: ExerciseState.ascending,
          descentThreshold: descendingThreshold,
        );

        final exPredAsc = classifierService.predict(features);
        _candidateTracker?.recordClassifierPrediction(
          exPredAsc.predictedClass,
          exPredAsc.confidence,
        );

        // Returns to standing lockout -> Candidate completed!
        if (avgKnee >= standingKneeThreshold) {
          return _attemptCompleteRep(frame, t, trunkAngle);
        }
        break;

      default:
        _currentState = ExerciseState.standing;
    }

    return null;
  }

  /// Evaluates the candidate through the multi-signal SquatRepGate.
  /// If valid, increments rep count and evaluates form. If invalid, candidate is rejected.
  RepAnalysisResult? _attemptCompleteRep(
    PoseFrame frame,
    double t,
    double trunkAngle,
  ) {
    _currentState = ExerciseState.standing;

    if (_candidateTracker == null) {
      _resetCandidate();
      return null;
    }

    // 1. REP VALIDATION & EXERCISE VALIDATION (Multi-signal gate)
    final validation = _gate.validate(_candidateTracker!);
    _lastRejectionReason = validation.rejectionReason;

    if (!validation.isValid) {
      _resetCandidate();
      return null;
    }

    // 2. FORM EVALUATION (Only on validated squat candidates)
    _repCount++;
    _lastRepCompletionTime = t;
    final repResult = _generateCompletedRepResult(t, trunkAngle);
    _resetCandidate();
    return repResult;
  }

  RepAnalysisResult _generateCompletedRepResult(double t, double trunkAngle) {
    final durationMs = _repStartTimeSeconds != null
        ? math.max(200, ((t - _repStartTimeSeconds!) * 1000).toInt())
        : 1500;

    final activeFlags = <String>[];
    String finalFormStatus = 'good';
    double finalConfidence = _bottomPrediction?.formConfidence ?? 0.90;

    // 1. Biomechanical verification: depth check
    if (_minKneeAngleInRep > 105.0) {
      finalFormStatus = 'bad';
      activeFlags.add('SHALLOW_DEPTH');
    }

    // 2. Biomechanical verification: evaluate trunk lean (> 82 deg from vertical = excessive trunk collapse)
    final repTrunkAngle = (_bottomFeatures != null && _bottomFeatures!.length > 109)
        ? _bottomFeatures![109]
        : math.max(trunkAngle, _maxTrunkAngleInRep);

    if (repTrunkAngle > 82.0) {
      finalFormStatus = 'bad';
      activeFlags.add('FORWARD_LEAN');
    }

    // 3. Bilateral Knee Symmetry (tolerant to camera side-angle perspective occlusion)
    if (_candidateTracker != null && _candidateTracker!.maxKneeDiff > 45.0) {
      finalFormStatus = 'bad';
      activeFlags.add('ASYMMETRIC_KNEES');
    }

    // Dynamic, truthful feedback matching user's actual movement
    String feedback;
    if (activeFlags.contains('SHALLOW_DEPTH') && activeFlags.contains('FORWARD_LEAN')) {
      feedback = 'Squat deeper and keep your chest proud.';
    } else if (activeFlags.contains('SHALLOW_DEPTH')) {
      feedback = 'Squat deeper — get thighs parallel to floor.';
    } else if (activeFlags.contains('FORWARD_LEAN')) {
      feedback = 'Keep chest proud — avoid excessive forward lean.';
    } else if (activeFlags.contains('ASYMMETRIC_KNEES')) {
      feedback = 'Keep knees aligned and descend evenly.';
    } else {
      finalFormStatus = 'good';
      feedback = _minKneeAngleInRep <= 90.0
          ? 'Deep squat! Excellent form and posture.'
          : 'Great depth and form!';
    }

    final repResult = RepAnalysisResult(
      repNumber: _repCount,
      exercise: 'squat',
      formStatus: finalFormStatus,
      formConfidence: finalConfidence,
      activeFlags: activeFlags,
      feedback: feedback,
      durationMs: durationMs,
      peakMetrics: {
        'minKneeAngle': double.parse(_minKneeAngleInRep.toStringAsFixed(1)),
        'trunkInclination': double.parse(repTrunkAngle.toStringAsFixed(1)),
      },
    );

    _latestRepResult = repResult;
    _minKneeAngleInRep = 180.0;
    return repResult;
  }
}
