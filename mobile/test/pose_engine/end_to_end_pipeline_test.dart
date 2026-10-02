import 'dart:io';
import 'dart:math' as math;
import 'package:fit_odyssey/core/pose_engine/models/landmark.dart';
import 'package:fit_odyssey/core/pose_engine/models/pose_frame.dart';
import 'package:fit_odyssey/core/pose_engine/models/prediction_result.dart';
import 'package:fit_odyssey/core/pose_engine/pose_intelligence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

List<Landmark> createSyntheticSquatPose({
  required double kneeAngle,
  required double hipAngle,
  required double trunkAngle,
}) {
  final lms = List.generate(33, (i) => Landmark(index: i, x: 0.5, y: 0.5, z: 0.0, visibility: 0.99));

  // Set mid-hip at (0.5, 0.6, 0.0)
  lms[Landmark.leftHip] = const Landmark(index: 23, x: 0.45, y: 0.6, z: 0.0, visibility: 0.99);
  lms[Landmark.rightHip] = const Landmark(index: 24, x: 0.55, y: 0.6, z: 0.0, visibility: 0.99);

  // Set mid-shoulder at (0.5, 0.25, 0.0) -> Torso length = 0.35
  lms[Landmark.leftShoulder] = const Landmark(index: 11, x: 0.43, y: 0.25, z: 0.0, visibility: 0.99);
  lms[Landmark.rightShoulder] = const Landmark(index: 12, x: 0.57, y: 0.25, z: 0.0, visibility: 0.99);

  final rad = kneeAngle * math.pi / 180.0;
  const thighLength = 0.25;
  const shinLength = 0.25;

  final thighAngleFromVert = (math.pi - rad) * 0.7;
  final kneeY = 0.6 + thighLength * math.cos(thighAngleFromVert);
  final kneeZ = thighLength * math.sin(thighAngleFromVert);

  lms[Landmark.leftKnee] = Landmark(index: 25, x: 0.45, y: kneeY, z: kneeZ, visibility: 0.99);
  lms[Landmark.rightKnee] = Landmark(index: 26, x: 0.55, y: kneeY, z: kneeZ, visibility: 0.99);

  final ankleY = kneeY + shinLength * math.cos((math.pi - rad) * 0.3);
  final ankleZ = kneeZ - shinLength * math.sin((math.pi - rad) * 0.3);

  lms[Landmark.leftAnkle] = Landmark(index: 27, x: 0.45, y: ankleY, z: ankleZ, visibility: 0.99);
  lms[Landmark.rightAnkle] = Landmark(index: 28, x: 0.55, y: ankleY, z: ankleZ, visibility: 0.99);

  lms[Landmark.leftFootIndex] = Landmark(index: 31, x: 0.45, y: ankleY, z: ankleZ + 0.1, visibility: 0.99);
  lms[Landmark.rightFootIndex] = Landmark(index: 32, x: 0.55, y: ankleY, z: ankleZ + 0.1, visibility: 0.99);

  // Arms and nose
  lms[Landmark.leftElbow] = const Landmark(index: 13, x: 0.40, y: 0.40, z: 0.0, visibility: 0.99);
  lms[Landmark.rightElbow] = const Landmark(index: 14, x: 0.60, y: 0.40, z: 0.0, visibility: 0.99);
  lms[Landmark.leftWrist] = const Landmark(index: 15, x: 0.40, y: 0.55, z: 0.0, visibility: 0.99);
  lms[Landmark.rightWrist] = const Landmark(index: 16, x: 0.60, y: 0.55, z: 0.0, visibility: 0.99);
  lms[Landmark.nose] = const Landmark(index: 0, x: 0.50, y: 0.15, z: 0.0, visibility: 0.99);

  // Ground anchor: translate pose vertically so ankles stay planted at 0.90
  // and hips descend realistically
  const groundAnkleY = 0.90;
  final yShift = groundAnkleY - ankleY;
  for (int i = 0; i < lms.length; i++) {
    final lm = lms[i];
    lms[i] = Landmark(
      index: lm.index,
      x: lm.x,
      y: lm.y + yShift,
      z: lm.z,
      visibility: lm.visibility,
      presence: lm.presence,
    );
  }

  return lms;
}

void main() {
  test('Complete end-to-end workout pipeline tracks repetitions, form, and depth', () {
    final exJson = File('assets/models/exercise_classifier.json').readAsStringSync();
    final sqJson = File('assets/models/squat_form_classifier.json').readAsStringSync();
    final puJson = File('assets/models/pushup_form_classifier.json').readAsStringSync();

    final engine = PoseIntelligenceEngine.fromModelJsonStrings(
      exerciseClassifierJson: exJson,
      squatFormJson: sqJson,
      pushupFormJson: puJson,
      defaultExercise: 'squat',
    );

    expect(engine.activeExercise, equals('squat'));

    // Simulate a 3-rep squat workout sequence across 38 frames
    final kneeAngleProfile = [
      // Rep 1: Good Deep Squat
      170.0, 165.0, 155.0, 140.0, 125.0, 105.0, 88.0, 85.0, 92.0, 110.0, 130.0, 150.0, 168.0,
      // Idle pause
      168.0, 170.0,
      // Rep 2: Another Deep Squat
      165.0, 150.0, 135.0, 115.0, 95.0, 82.0, 82.0, 90.0, 108.0, 128.0, 148.0, 165.0,
      // Idle pause
      165.0, 165.0,
      // Rep 3: Shallow Squat (Bad form depth)
      160.0, 145.0, 132.0, 122.0, 120.0, 122.0, 135.0, 150.0, 165.0,
    ];

    final completedReps = <RepAnalysisResult>[];

    for (int i = 0; i < kneeAngleProfile.length; i++) {
      final kneeAngle = kneeAngleProfile[i];
      final timestamp = i * (1.0 / 15.0);

      final lms = createSyntheticSquatPose(
        kneeAngle: kneeAngle,
        hipAngle: kneeAngle + 10.0,
        trunkAngle: 25.0,
      );

      final frame = PoseFrame(
        landmarks: lms,
        timestampSeconds: timestamp,
        isDetected: true,
      );

      final repResult = engine.processFrame(frame);
      if (repResult != null) {
        completedReps.add(repResult);
      }
    }

    expect(completedReps.length, equals(3), reason: 'Expected 3 completed reps');
    expect(completedReps[0].formStatus, equals('good'), reason: 'Rep 1 must be good form');
    expect(completedReps[1].formStatus, equals('good'), reason: 'Rep 2 must be good form');
    expect(completedReps[2].formStatus, equals('bad'), reason: 'Rep 3 (shallow) must be bad form');
    expect(completedReps[2].activeFlags.contains('SHALLOW_DEPTH'), isTrue, reason: 'Rep 3 must flag SHALLOW_DEPTH');
  });
}
