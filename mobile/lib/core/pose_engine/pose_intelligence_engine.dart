import 'classifier/decision_forest.dart';
import 'classifier/pose_classifier_service.dart';
import 'feature_extraction/pose_feature_extractor.dart';
import 'models/pose_frame.dart';
import 'models/prediction_result.dart';
import 'smoothing/pose_smoother.dart';
import 'state_machine/exercise_state_machine.dart';
import 'state_machine/plank_state_machine.dart';
import 'state_machine/pushup_state_machine.dart';
import 'state_machine/squat_state_machine.dart';

/// Complete on-device Pose Intelligence Pipeline for Fit Odyssey.
/// Integrates:
/// Camera / ML Kit → PoseFrame → EMA Smoother → 140 Features → Decision Forest → State Machine → Rep & Form Coaching
class PoseIntelligenceEngine {
  final PoseClassifierService classifierService;
  final PoseSmoother smoother;
  final PoseFeatureExtractor featureExtractor;

  late final Map<String, ExerciseStateMachine> _stateMachines;
  String _activeExercise;

  // Real-time telemetry
  PredictionResult? _latestFramePrediction;
  RepAnalysisResult? _latestRepResult;
  List<double> _latestFeatures = const [];

  PoseIntelligenceEngine({
    required this.classifierService,
    String defaultExercise = 'squat',
    double smoothingAlpha = 0.65,
  })  : smoother = PoseSmoother(alpha: smoothingAlpha),
        featureExtractor = PoseFeatureExtractor(),
        _activeExercise = defaultExercise {
    _stateMachines = {
      'squat': SquatStateMachine(classifierService: classifierService),
      'push_up': PushupStateMachine(classifierService: classifierService),
      'plank': PlankStateMachine(),
    };
  }

  /// Factory loading models from JSON strings (e.g. from rootBundle or test files).
  factory PoseIntelligenceEngine.fromModelJsonStrings({
    required String exerciseClassifierJson,
    String? squatFormJson,
    String? pushupFormJson,
    String defaultExercise = 'squat',
  }) {
    final exForest = DecisionForest.fromJsonString(exerciseClassifierJson);
    final sqForest = squatFormJson != null ? DecisionForest.fromJsonString(squatFormJson) : null;
    final puForest = pushupFormJson != null ? DecisionForest.fromJsonString(pushupFormJson) : null;

    final service = PoseClassifierService(
      exerciseForest: exForest,
      squatFormForest: sqForest,
      pushupFormForest: puForest,
    );

    return PoseIntelligenceEngine(
      classifierService: service,
      defaultExercise: defaultExercise,
    );
  }

  String get activeExercise => _activeExercise;

  void setActiveExercise(String exercise) {
    if (_stateMachines.containsKey(exercise)) {
      _activeExercise = exercise;
      reset();
    }
  }

  ExerciseStateMachine get activeStateMachine =>
      _stateMachines[_activeExercise] ?? _stateMachines['squat']!;

  int get repCount => activeStateMachine.repCount;
  ExerciseState get currentState => activeStateMachine.currentState;
  PredictionResult? get latestFramePrediction => _latestFramePrediction;
  RepAnalysisResult? get latestRepResult => _latestRepResult;
  List<double> get latestFeatures => _latestFeatures;

  void reset() {
    smoother.reset();
    featureExtractor.reset();
    for (final sm in _stateMachines.values) {
      sm.reset();
    }
    _latestFramePrediction = null;
    _latestRepResult = null;
    _latestFeatures = const [];
  }

  /// Processes a single PoseFrame through the complete pipeline.
  /// Returns a new RepAnalysisResult if a repetition completed on this frame.
  RepAnalysisResult? processFrame(PoseFrame rawFrame) {
    if (!rawFrame.isDetected) {
      return null;
    }

    // 1. EMA Smoothing
    final smoothedFrame = smoother.smooth(rawFrame);

    // 2. Extract 140 features
    _latestFeatures = featureExtractor.extractFeatures(
      smoothedFrame.landmarks,
      timestampSeconds: smoothedFrame.timestampSeconds,
    );

    // 3. Evaluate custom ML classifier on current frame
    _latestFramePrediction = classifierService.predict(
      _latestFeatures,
    );

    // 4. Pass into deterministic state machine (form evaluated at BOTTOM)
    final repCompleted = activeStateMachine.processFrame(
      smoothedFrame,
      _latestFeatures,
    );

    if (repCompleted != null) {
      _latestRepResult = repCompleted;
      return repCompleted;
    }

    return null;
  }
}
