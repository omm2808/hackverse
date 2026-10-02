import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:fit_odyssey/core/pose_engine/classifier/decision_forest.dart';
import 'package:fit_odyssey/core/pose_engine/feature_extraction/pose_feature_extractor.dart';
import 'package:fit_odyssey/core/pose_engine/models/landmark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Dart Decision Forest models maintain mathematical parity with exported Python models', () {
    final testVectorsFile = File('assets/models/parity_test_vectors.json');
    expect(testVectorsFile.existsSync(), isTrue, reason: 'parity_test_vectors.json must exist');

    final testVectors = json.decode(testVectorsFile.readAsStringSync()) as List<dynamic>;
    expect(testVectors.isNotEmpty, isTrue, reason: 'Test vectors should not be empty');

    // Load decision forest models
    final exJson = File('assets/models/exercise_classifier.json').readAsStringSync();
    final sqJson = File('assets/models/squat_form_classifier.json').readAsStringSync();
    final puJson = File('assets/models/pushup_form_classifier.json').readAsStringSync();

    final exForest = DecisionForest.fromJsonString(exJson);
    final sqForest = DecisionForest.fromJsonString(sqJson);
    final puForest = DecisionForest.fromJsonString(puJson);

    int passedExMatches = 0;
    int passedSqMatches = 0;
    int passedPuMatches = 0;
    double maxExProbDiff = 0.0;
    double maxSqProbDiff = 0.0;
    double maxPuProbDiff = 0.0;

    for (int i = 0; i < testVectors.length; i++) {
      final v = testVectors[i] as Map<String, dynamic>;
      final features = (v['features'] as List<dynamic>).map((f) => (f as num).toDouble()).toList();

      // 1. Test Exercise Classifier Parity
      final exPred = exForest.predict(features);
      final expectedExClass = v['expected_exercise_pred'] as String;
      final expectedExProbs = (v['expected_exercise_probs'] as List<dynamic>).map((p) => (p as num).toDouble()).toList();
      final expectedExClasses = (v['expected_exercise_classes'] as List<dynamic>).map((c) => c.toString()).toList();

      if (exPred.predictedClass == expectedExClass) {
        passedExMatches++;
      }

      for (int c = 0; c < expectedExClasses.length; c++) {
        final className = expectedExClasses[c];
        final actualProb = exPred.classProbabilities[className] ?? 0.0;
        final expectedProb = expectedExProbs[c];
        final diff = (actualProb - expectedProb).abs();
        maxExProbDiff = math.max(maxExProbDiff, diff);
      }

      // 2. Test Squat Form Classifier Parity
      final sqPred = sqForest.predict(features);
      final expectedSqClass = v['expected_squat_form_pred'] as String;
      final expectedSqProbs = (v['expected_squat_form_probs'] as List<dynamic>).map((p) => (p as num).toDouble()).toList();
      final expectedSqClasses = (v['expected_squat_form_classes'] as List<dynamic>).map((c) => c.toString()).toList();

      if (sqPred.predictedClass == expectedSqClass) {
        passedSqMatches++;
      }

      for (int c = 0; c < expectedSqClasses.length; c++) {
        final className = expectedSqClasses[c];
        final actualProb = sqPred.classProbabilities[className] ?? 0.0;
        final expectedProb = expectedSqProbs[c];
        final diff = (actualProb - expectedProb).abs();
        maxSqProbDiff = math.max(maxSqProbDiff, diff);
      }

      // 3. Test Push-up Form Classifier Parity
      final puPred = puForest.predict(features);
      final expectedPuClass = v['expected_pushup_form_pred'] as String;
      final expectedPuProbs = (v['expected_pushup_form_probs'] as List<dynamic>).map((p) => (p as num).toDouble()).toList();
      final expectedPuClasses = (v['expected_pushup_form_classes'] as List<dynamic>).map((c) => c.toString()).toList();

      if (puPred.predictedClass == expectedPuClass) {
        passedPuMatches++;
      }

      for (int c = 0; c < expectedPuClasses.length; c++) {
        final className = expectedPuClasses[c];
        final actualProb = puPred.classProbabilities[className] ?? 0.0;
        final expectedProb = expectedPuProbs[c];
        final diff = (actualProb - expectedProb).abs();
        maxPuProbDiff = math.max(maxPuProbDiff, diff);
      }

      // 4. Test Feature Extraction static features parity
      final rawLms = (v['landmarks'] as List<dynamic>).map((lmMap) {
        final m = lmMap as Map<String, dynamic>;
        return Landmark(
          index: 0,
          x: (m['x'] as num).toDouble(),
          y: (m['y'] as num).toDouble(),
          z: (m['z'] as num).toDouble(),
          visibility: (m['visibility'] as num).toDouble(),
        );
      }).toList();

      final extractor = PoseFeatureExtractor();
      final extractedFeats = extractor.extractFeatures(rawLms, isNormalized: true);

      // Verify static feature tolerance
      for (int f = 0; f < 123; f++) {
        final diff = (extractedFeats[f] - features[f]).abs();
        expect(diff < 1e-3, isTrue, reason: 'Feature $f diverged by $diff');
      }
    }

    expect(passedExMatches, equals(testVectors.length), reason: 'All exercise predictions must match');
    expect(passedSqMatches, equals(testVectors.length), reason: 'All squat form predictions must match');
    expect(passedPuMatches, equals(testVectors.length), reason: 'All pushup form predictions must match');
    expect(maxExProbDiff < 1e-5, isTrue, reason: 'Exercise probabilities must be numerically identical');
    expect(maxSqProbDiff < 1e-5, isTrue, reason: 'Squat probabilities must be numerically identical');
    expect(maxPuProbDiff < 1e-5, isTrue, reason: 'Push-up probabilities must be numerically identical');
  });
}
