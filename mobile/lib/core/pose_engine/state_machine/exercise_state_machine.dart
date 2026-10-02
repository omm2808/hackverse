import '../models/pose_frame.dart';
import '../models/prediction_result.dart';

/// Base interface for deterministic biomechanical exercise state machines.
abstract class ExerciseStateMachine {
  String get exerciseName;
  int get repCount;
  ExerciseState get currentState;
  RepAnalysisResult? get latestRepResult;

  /// Processes incoming frame and returns newly completed rep analysis if a rep completed.
  RepAnalysisResult? processFrame(
    PoseFrame frame,
    List<double> features,
  );

  /// Resets state machine counters and state.
  void reset();
}
