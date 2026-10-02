import '../models/prediction_result.dart';
import 'decision_forest.dart';

/// High-level Pose Classifier Service orchestrating exercise and form quality forests.
class PoseClassifierService {
  final DecisionForest exerciseForest;
  final DecisionForest? squatFormForest;
  final DecisionForest? pushupFormForest;

  const PoseClassifierService({
    required this.exerciseForest,
    this.squatFormForest,
    this.pushupFormForest,
  });

  /// Evaluates 140 features and returns structured PredictionResult.
  PredictionResult predict(
    List<double> features, {
    String? enforceExercise,
    Map<String, double>? biomechanics,
  }) {
    // 1. Exercise classification
    final String exercise;
    final double exConfidence;

    if (enforceExercise != null && enforceExercise.isNotEmpty) {
      exercise = enforceExercise;
      exConfidence = 1.0;
    } else {
      final exPred = exerciseForest.predict(features);
      exercise = exPred.predictedClass;
      exConfidence = exPred.confidence;
    }

    // 2. Form classification conditioned on exercise
    String formStatus = 'good';
    double formConfidence = 0.5;

    if (exercise == 'squat' && squatFormForest != null) {
      final formPred = squatFormForest!.predict(features);
      formStatus = formPred.predictedClass;
      formConfidence = formPred.confidence;
    } else if (exercise == 'push_up' && pushupFormForest != null) {
      final formPred = pushupFormForest!.predict(features);
      formStatus = formPred.predictedClass;
      formConfidence = formPred.confidence;
    }

    // 3. Biomechanics extraction from feature vector if not provided
    final bio = biomechanics ?? _extractBiomechanicsFromFeatures(features);

    // 4. Generate transparent coaching feedback
    final feedback = _generateFeedback(exercise, formStatus, bio);

    return PredictionResult(
      predictedClass: exercise,
      confidence: double.parse(exConfidence.toStringAsFixed(3)),
      exercise: exercise,
      formStatus: formStatus,
      formConfidence: double.parse(formConfidence.toStringAsFixed(3)),
      biomechanics: bio,
      feedback: feedback,
    );
  }

  Map<String, double> _extractBiomechanicsFromFeatures(List<double> features) {
    if (features.length < 112) return {};
    return {
      'kneeAngleLeft': double.parse(features[99].toStringAsFixed(1)),
      'kneeAngleRight': double.parse(features[100].toStringAsFixed(1)),
      'hipAngleLeft': double.parse(features[101].toStringAsFixed(1)),
      'hipAngleRight': double.parse(features[102].toStringAsFixed(1)),
      'elbowAngleLeft': double.parse(features[103].toStringAsFixed(1)),
      'elbowAngleRight': double.parse(features[104].toStringAsFixed(1)),
      'trunkInclination': double.parse(features[109].toStringAsFixed(1)),
    };
  }

  String _generateFeedback(
    String exercise,
    String formStatus,
    Map<String, double> bio,
  ) {
    if (exercise == 'squat') {
      final leftKnee = bio['kneeAngleLeft'] ?? 90.0;
      final rightKnee = bio['kneeAngleRight'] ?? 90.0;
      final avgKnee = (leftKnee + rightKnee) / 2.0;
      final trunk = bio['trunkInclination'] ?? 0.0;

      // When user is standing upright, prompt readiness instead of squat depth coaching
      if (avgKnee >= 140.0) {
        return 'Stand ready — Begin squat when prepared.';
      }

      if (formStatus == 'good') {
        return 'Good form — Maintain steady tempo!';
      }

      if (avgKnee > 105.0) {
        return 'Squat deeper — Strive to reach parallel thighs.';
      }
      if (trunk > 48.0) {
        return 'Keep your chest up — Avoid leaning too far forward.';
      }
      return 'Great form — Maintain steady tempo!';
    }

    if (formStatus == 'good') {
      return 'Good form — Maintain steady tempo!';
    }

    if (exercise == 'push_up') {
      final leftElbow = bio['elbowAngleLeft'] ?? 90.0;
      final rightElbow = bio['elbowAngleRight'] ?? 90.0;
      final avgElbow = (leftElbow + rightElbow) / 2.0;

      // In high plank ready position (arms extended)
      if (avgElbow >= 135.0) {
        return 'High plank ready — Begin push-up.';
      }

      if (formStatus == 'good') {
        return 'Good form — Maintain steady tempo!';
      }

      if (avgElbow > 105.0) {
        return 'Descend deeper — Aim for 90° elbow flexion.';
      }
      return 'Keep body straight and engage core.';
    }

    return 'Adjust your posture for optimal form.';
  }
}
