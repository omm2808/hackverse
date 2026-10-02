import 'dart:io';
import 'package:fit_odyssey/core/pose_engine/classifier/decision_forest.dart';
import 'package:fit_odyssey/core/pose_engine/classifier/pose_classifier_service.dart';
import 'package:fit_odyssey/core/pose_engine/models/landmark.dart';
import 'package:fit_odyssey/core/pose_engine/models/pose_frame.dart';
import 'package:fit_odyssey/core/pose_engine/models/prediction_result.dart';
import 'package:fit_odyssey/core/pose_engine/state_machine/pushup_state_machine.dart';
import 'package:fit_odyssey/core/pose_engine/state_machine/squat_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

List<Landmark> createSyntheticLandmarks({
  double kneeAngle = 170.0,
  double elbowAngle = 170.0,
  double hipAngle = 170.0,
  double visibility = 0.99,
  double ankleXOffset = 0.0,
  double ankleYOffset = 0.0,
  double scaleMultiplier = 1.0,
  double hipXOffset = 0.0,
  bool isSingleLegLift = false,
  double? dropOverride,
}) {
  final lms = List.generate(33, (i) => Landmark(
    index: i,
    x: 0.5,
    y: 0.5,
    z: 0.0,
    visibility: visibility,
  ));

  // Torso base geometry
  final torsoLen = 0.35 * scaleMultiplier;
  final drop = dropOverride ?? ((170.0 - kneeAngle) / 170.0 * 0.20);
  final hipY = 0.55 + drop;
  final shoulderY = hipY - torsoLen;

  // Planted ankles at 0.90
  final lAnkX = 0.45 + ankleXOffset;
  final lAnkY = 0.90 + ankleYOffset;
  const rAnkX = 0.55;
  const rAnkY = 0.90;

  lms[Landmark.leftAnkle] = Landmark(index: 27, x: lAnkX, y: lAnkY, z: 0.0, visibility: visibility);
  lms[Landmark.rightAnkle] = Landmark(index: 28, x: rAnkX, y: rAnkY, z: 0.0, visibility: visibility);
  lms[Landmark.leftHeel] = Landmark(index: 29, x: lAnkX, y: lAnkY + 0.02, z: 0.0, visibility: visibility);
  lms[Landmark.rightHeel] = Landmark(index: 30, x: rAnkX, y: rAnkY + 0.02, z: 0.0, visibility: visibility);
  lms[Landmark.leftFootIndex] = Landmark(index: 31, x: lAnkX, y: lAnkY + 0.04, z: 0.1, visibility: visibility);
  lms[Landmark.rightFootIndex] = Landmark(index: 32, x: rAnkX, y: rAnkY + 0.04, z: 0.1, visibility: visibility);

  // Hips
  final midHX = 0.50 + hipXOffset;
  lms[Landmark.leftHip] = Landmark(index: 23, x: midHX - 0.08, y: isSingleLegLift ? 0.55 : hipY, z: 0.0, visibility: visibility);
  lms[Landmark.rightHip] = Landmark(index: 24, x: midHX + 0.08, y: isSingleLegLift ? 0.55 : hipY, z: 0.0, visibility: visibility);

  // Knees
  final kneeY = (hipY + 0.90) / 2.0;
  lms[Landmark.leftKnee] = Landmark(index: 25, x: 0.45, y: kneeY, z: 0.1, visibility: visibility);
  lms[Landmark.rightKnee] = Landmark(index: 26, x: 0.55, y: isSingleLegLift ? 0.72 : kneeY, z: 0.1, visibility: visibility);

  // Shoulders
  lms[Landmark.leftShoulder] = Landmark(index: 11, x: midHX - 0.12, y: isSingleLegLift ? (0.55 - torsoLen) : shoulderY, z: 0.0, visibility: visibility);
  lms[Landmark.rightShoulder] = Landmark(index: 12, x: midHX + 0.12, y: isSingleLegLift ? (0.55 - torsoLen) : shoulderY, z: 0.0, visibility: visibility);

  // Arms and head
  lms[Landmark.leftElbow] = Landmark(index: 13, x: 0.35, y: shoulderY + 0.15, z: 0.0, visibility: visibility);
  lms[Landmark.rightElbow] = Landmark(index: 14, x: 0.65, y: shoulderY + 0.15, z: 0.0, visibility: visibility);
  lms[Landmark.leftWrist] = Landmark(index: 15, x: 0.35, y: shoulderY + 0.30, z: 0.0, visibility: visibility);
  lms[Landmark.rightWrist] = Landmark(index: 16, x: 0.65, y: shoulderY + 0.30, z: 0.0, visibility: visibility);
  lms[Landmark.nose] = Landmark(index: 0, x: midHX, y: shoulderY - 0.10, z: 0.0, visibility: visibility);

  return lms;
}

List<double> createSyntheticFeatures({
  required double leftKneeAngle,
  required double rightKneeAngle,
  required double leftElbowAngle,
  required double rightElbowAngle,
  double trunkInclination = 25.0,
  double hipAngle = 170.0,
}) {
  final feats = List<double>.filled(140, 0.0);
  // Indices 99 & 100: knee angles
  feats[99] = leftKneeAngle;
  feats[100] = rightKneeAngle;
  // Indices 101 & 102: hip angles
  feats[101] = hipAngle;
  feats[102] = hipAngle;
  // Indices 103 & 104: elbow angles
  feats[103] = leftElbowAngle;
  feats[104] = rightElbowAngle;
  // Index 109: trunk inclination
  feats[109] = trunkInclination;
  return feats;
}

void main() {
  late PoseClassifierService service;

  setUpAll(() {
    final exJson = File('assets/models/exercise_classifier.json').readAsStringSync();
    final sqJson = File('assets/models/squat_form_classifier.json').readAsStringSync();
    final puJson = File('assets/models/pushup_form_classifier.json').readAsStringSync();

    service = PoseClassifierService(
      exerciseForest: DecisionForest.fromJsonString(exJson),
      squatFormForest: DecisionForest.fromJsonString(sqJson),
      pushupFormForest: DecisionForest.fromJsonString(puJson),
    );
  });

  group('Squat State Machine & Multi-Signal Gate', () {
    test('1. Normal squat -> counts 1 rep with good form', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Frame 1: Standing (165 deg)
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      var res = squatSM.processFrame(frame, feats);
      expect(res, isNull);
      expect(squatSM.currentState, equals(ExerciseState.standing));
      expect(squatSM.repCount, equals(0));

      // Frame 2: Descending (130 deg)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 130), timestampSeconds: 0.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 130, rightKneeAngle: 130, leftElbowAngle: 165, rightElbowAngle: 165);
      res = squatSM.processFrame(frame, feats);
      expect(res, isNull);
      expect(squatSM.currentState, equals(ExerciseState.descending));

      // Frame 3: BOTTOM Inflection point reached (88 deg deep squat)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 88), timestampSeconds: 1.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 88, rightKneeAngle: 88, leftElbowAngle: 165, rightElbowAngle: 165);
      res = squatSM.processFrame(frame, feats);
      expect(res, isNull);
      expect(squatSM.currentState, equals(ExerciseState.bottom));

      // Frame 4: Ascending (125 deg)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 125), timestampSeconds: 1.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 125, rightKneeAngle: 125, leftElbowAngle: 165, rightElbowAngle: 165);
      res = squatSM.processFrame(frame, feats);
      expect(res, isNull);
      expect(squatSM.currentState, equals(ExerciseState.ascending));

      // Frame 5: Standing Lockout (165 deg) -> +1 Rep!
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 2.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      res = squatSM.processFrame(frame, feats);
      expect(res, isNotNull, reason: 'Rep must be completed on return to standing');
      expect(squatSM.repCount, equals(1));
      expect(res!.repNumber, equals(1));
      expect(res.exercise, equals('squat'));
      expect(res.formStatus, equals('good'));
      expect(res.activeFlags.contains('SHALLOW_DEPTH'), isFalse);
    });

    test('2. Walking forward -> counts 0 squat reps (rejected by translation / foot movement)', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Standing frame
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Walking forward: scale increases dramatically (person gets closer), ankles step forward
      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 135, scaleMultiplier: 1.35, ankleYOffset: 0.15),
        timestampSeconds: 0.4,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 135, rightKneeAngle: 135, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 100, scaleMultiplier: 1.45, ankleYOffset: 0.25),
        timestampSeconds: 0.8,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 100, rightKneeAngle: 100, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 125, scaleMultiplier: 1.50, ankleYOffset: 0.30),
        timestampSeconds: 1.2,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 125, rightKneeAngle: 125, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Steps back up to standing
      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 165, scaleMultiplier: 1.50, ankleYOffset: 0.30),
        timestampSeconds: 1.6,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final res = squatSM.processFrame(frame, feats);

      expect(res, isNull, reason: 'Walking forward must not count as squat rep');
      expect(squatSM.repCount, equals(0));
    });

    test('3. Walking backward -> counts 0 squat reps (rejected by scale change)', () {
      final squatSM = SquatStateMachine(classifierService: service);

      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Walking backward: scale drops (person gets smaller as they move away)
      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 135, scaleMultiplier: 0.70, ankleYOffset: -0.15),
        timestampSeconds: 0.5,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 135, rightKneeAngle: 135, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 95, scaleMultiplier: 0.65, ankleYOffset: -0.20),
        timestampSeconds: 1.0,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 95, rightKneeAngle: 95, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 125, scaleMultiplier: 0.65, ankleYOffset: -0.20),
        timestampSeconds: 1.5,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 125, rightKneeAngle: 125, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 165, scaleMultiplier: 0.65, ankleYOffset: -0.20),
        timestampSeconds: 2.0,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final res = squatSM.processFrame(frame, feats);

      expect(res, isNull, reason: 'Walking backward must not count as squat rep');
      expect(squatSM.repCount, equals(0));
    });

    test('4. Single-leg raise -> counts 0 squat reps (unilateral knee flexion rejected)', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Frame 1: Standing
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 2: Left knee lifts to 80 deg, right knee remains straight at 170 deg!
      // Hips do NOT drop, left ankle lifts into air
      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 80, isSingleLegLift: true, ankleYOffset: -0.30),
        timestampSeconds: 0.5,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 80, rightKneeAngle: 170, leftElbowAngle: 165, rightElbowAngle: 165);
      final res = squatSM.processFrame(frame, feats);

      expect(res, isNull);
      expect(squatSM.currentState, equals(ExerciseState.standing), reason: 'Unilateral knee flexion must not even enter descending');
      expect(squatSM.repCount, equals(0));
    });

    test('5. Single-leg raise + lower -> counts 0 squat reps', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Standing
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Leg lifts up
      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 80, isSingleLegLift: true, ankleYOffset: -0.35),
        timestampSeconds: 0.5,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 80, rightKneeAngle: 170, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Leg held at top
      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 75, isSingleLegLift: true, ankleYOffset: -0.40),
        timestampSeconds: 1.0,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 75, rightKneeAngle: 170, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Leg lowered back down to floor
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 1.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final res = squatSM.processFrame(frame, feats);

      expect(res, isNull, reason: 'Single-leg raise and lower must not count as squat');
      expect(squatSM.repCount, equals(0));
    });

    test('6. Shallow squat -> counts 1 rep but receives SHALLOW_DEPTH flag', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Frame 1: Standing
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 2: Descending (130 deg)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 130), timestampSeconds: 0.4, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 130, rightKneeAngle: 130, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);
      expect(squatSM.currentState, equals(ExerciseState.descending));

      // Frame 3: Shallow depth inflection (115 deg)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 115), timestampSeconds: 0.8, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 115, rightKneeAngle: 115, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 4: Rebound to bottom (123 deg > 115 + 6)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 123), timestampSeconds: 1.2, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 123, rightKneeAngle: 123, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);
      expect(squatSM.currentState, equals(ExerciseState.bottom));

      // Frame 5: Ascending (135 deg)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 135), timestampSeconds: 1.6, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 135, rightKneeAngle: 135, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);
      expect(squatSM.currentState, equals(ExerciseState.ascending));

      // Frame 6: Standing lockout (165 deg)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 2.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final shallowRep = squatSM.processFrame(frame, feats); // rep complete

      expect(shallowRep, isNotNull);
      expect(squatSM.repCount, equals(1));
      final completedShallow = shallowRep!;
      expect(completedShallow.formStatus, equals('bad'));
      expect(completedShallow.activeFlags.contains('SHALLOW_DEPTH'), isTrue);
    });

    test('7. Proper squat with slight natural lateral/forward movement -> still counts correctly', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Frame 1: Standing
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 2: Descending with slight natural sway (5% hip shift, 3% ankle shift, 5% scale shift)
      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 130, hipXOffset: 0.02, ankleXOffset: 0.01, scaleMultiplier: 1.03),
        timestampSeconds: 0.5,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 130, rightKneeAngle: 130, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 3: Deep bottom
      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 88, hipXOffset: 0.04, ankleXOffset: 0.02, scaleMultiplier: 1.05),
        timestampSeconds: 1.0,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 88, rightKneeAngle: 88, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 4: Ascending
      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 125, hipXOffset: 0.02, ankleXOffset: 0.01, scaleMultiplier: 1.02),
        timestampSeconds: 1.5,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 125, rightKneeAngle: 125, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 5: Lockout
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 2.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final res = squatSM.processFrame(frame, feats);

      expect(res, isNotNull, reason: 'Natural body sway within tolerance must still count');
      expect(squatSM.repCount, equals(1));
      expect(res!.formStatus, equals('good'));
    });

    test('8. Two consecutive proper squats -> counts exactly 2', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // --- SQUAT 1 ---
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 130), timestampSeconds: 0.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 130, rightKneeAngle: 130, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 88), timestampSeconds: 1.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 88, rightKneeAngle: 88, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 125), timestampSeconds: 1.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 125, rightKneeAngle: 125, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 2.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final rep1 = squatSM.processFrame(frame, feats);
      expect(rep1, isNotNull);
      expect(squatSM.repCount, equals(1));

      // Pause at standing
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 2.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // --- SQUAT 2 ---
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 130), timestampSeconds: 3.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 130, rightKneeAngle: 130, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 85), timestampSeconds: 3.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 85, rightKneeAngle: 85, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 125), timestampSeconds: 4.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 125, rightKneeAngle: 125, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 4.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final rep2 = squatSM.processFrame(frame, feats);

      expect(rep2, isNotNull);
      expect(squatSM.repCount, equals(2));
      expect(rep2!.repNumber, equals(2));
    });

    test('9. Walking forward with natural stride (12% scale drift) -> counts 0 reps', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Frame 1: Standing
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 2: Walking step forward - slight knee bend (133 deg) and 7% scale increase
      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 133, scaleMultiplier: 1.07, ankleYOffset: 0.08),
        timestampSeconds: 0.4,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 133, rightKneeAngle: 133, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 3: Knee rebound at 133 deg (never reached squat depth) and 13% scale increase
      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 140, scaleMultiplier: 1.13, ankleYOffset: 0.12),
        timestampSeconds: 0.8,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 140, rightKneeAngle: 140, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 4: Returns to standing closer to camera
      frame = PoseFrame(
        landmarks: createSyntheticLandmarks(kneeAngle: 165, scaleMultiplier: 1.13, ankleYOffset: 0.12),
        timestampSeconds: 1.2,
        isDetected: true,
      );
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final res = squatSM.processFrame(frame, feats);

      expect(res, isNull, reason: 'Walking forward with scale drift must not count as squat');
      expect(squatSM.repCount, equals(0));
    });

    test('10. Walking stride knee oscillation (rebounding at 134 deg) -> resets candidate cleanly', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Frame 1: Standing
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 2: Slight knee flexion from walking stride (134 deg)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 134), timestampSeconds: 0.3, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 134, rightKneeAngle: 134, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);
      expect(squatSM.currentState, equals(ExerciseState.descending));

      // Frame 3: Knee rebound past 134 + 6 = 140 deg without reaching squat depth (<= 128)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 142), timestampSeconds: 0.6, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 142, rightKneeAngle: 142, leftElbowAngle: 165, rightElbowAngle: 165);
      final res = squatSM.processFrame(frame, feats);

      expect(res, isNull);
      expect(squatSM.currentState, equals(ExerciseState.standing), reason: 'Candidate should cancel back to standing');
      expect(squatSM.lastRejectionReason, equals('REJECT_INSUFFICIENT_KNEE_DEPTH'));
      expect(squatSM.repCount, equals(0));
    });

    test('11. Squat with excessive forward lean -> flagged FORWARD_LEAN with chest proud feedback', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Frame 1: Standing
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165, trunkInclination: 15);
      squatSM.processFrame(frame, feats);

      // Frame 2: Descending with forward lean
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 130), timestampSeconds: 0.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 130, rightKneeAngle: 130, leftElbowAngle: 165, rightElbowAngle: 165, trunkInclination: 40);
      squatSM.processFrame(frame, feats);

      // Frame 3: Deep bottom but excessive forward trunk lean (86 deg > 82 deg)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 88), timestampSeconds: 1.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 88, rightKneeAngle: 88, leftElbowAngle: 165, rightElbowAngle: 165, trunkInclination: 86);
      squatSM.processFrame(frame, feats);

      // Frame 4: Ascending
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 125), timestampSeconds: 1.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 125, rightKneeAngle: 125, leftElbowAngle: 165, rightElbowAngle: 165, trunkInclination: 35);
      squatSM.processFrame(frame, feats);

      // Frame 5: Standing
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 2.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165, trunkInclination: 15);
      final res = squatSM.processFrame(frame, feats);

      expect(res, isNotNull);
      expect(squatSM.repCount, equals(1));
      expect(res!.formStatus, equals('bad'));
      expect(res.activeFlags.contains('FORWARD_LEAN'), isTrue);
      expect(res.activeFlags.contains('SHALLOW_DEPTH'), isFalse);
      expect(res.feedback, contains('chest proud'));
    });

    test('12. Standing posture does not trigger shallow depth feedback in PoseClassifierService', () {
      final feats = createSyntheticFeatures(
        leftKneeAngle: 168,
        rightKneeAngle: 168,
        leftElbowAngle: 165,
        rightElbowAngle: 165,
        trunkInclination: 18,
      );

      final pred = service.predict(feats, enforceExercise: 'squat');
      expect(pred.feedback, contains('Stand ready'));
      expect(pred.feedback, isNot(contains('Squat deeper')));
    });

    test('13. Walking forward 3 steps -> 0 squat reps (rejected by leg compression / depth gate)', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Standing frame at start
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Step 1: Forward step, swing knee 125°, scale grows, legs do not compress (dropOverride: 0.01)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 125, scaleMultiplier: 1.05, dropOverride: 0.01), timestampSeconds: 0.4, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 125, rightKneeAngle: 125, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 145, scaleMultiplier: 1.08, dropOverride: 0.005), timestampSeconds: 0.8, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 145, rightKneeAngle: 145, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Step 2: Next forward step, swing knee 122°, scale grows
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 122, scaleMultiplier: 1.14, dropOverride: 0.015), timestampSeconds: 1.2, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 122, rightKneeAngle: 122, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 145, scaleMultiplier: 1.18, dropOverride: 0.005), timestampSeconds: 1.6, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 145, rightKneeAngle: 145, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Step 3: Third forward step, swing knee 124°
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 124, scaleMultiplier: 1.22, dropOverride: 0.01), timestampSeconds: 2.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 124, rightKneeAngle: 124, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Final standing frame
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165, scaleMultiplier: 1.25, dropOverride: 0.0), timestampSeconds: 2.4, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final res = squatSM.processFrame(frame, feats);

      expect(res, isNull);
      expect(squatSM.repCount, equals(0), reason: 'Walking forward 3 steps must not count as squat rep');
    });

    test('14. Walking backward 3 steps -> 0 squat reps', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Standing
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Step 1: Step back, scale shrinks
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 125, scaleMultiplier: 0.94, dropOverride: 0.01), timestampSeconds: 0.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 125, rightKneeAngle: 125, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Step 2: Step back further
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 125, scaleMultiplier: 0.88, dropOverride: 0.01), timestampSeconds: 1.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 125, rightKneeAngle: 125, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Step 3: Step back further and stand
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 125, scaleMultiplier: 0.82, dropOverride: 0.01), timestampSeconds: 1.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 125, rightKneeAngle: 125, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165, scaleMultiplier: 0.82, dropOverride: 0.0), timestampSeconds: 2.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final res = squatSM.processFrame(frame, feats);

      expect(res, isNull);
      expect(squatSM.repCount, equals(0), reason: 'Walking backward 3 steps must not count as squat rep');
    });

    test('15. Forward/backward rocking -> 0 reps (net drift zero but no leg compression)', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Standing
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Rock forward: knees 126 deg, scale slightly up, legs uncompressed (dropOverride 0.01)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 126, scaleMultiplier: 1.05, dropOverride: 0.01), timestampSeconds: 0.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 126, rightKneeAngle: 126, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Rebound/sway
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 134, scaleMultiplier: 1.03, dropOverride: 0.008), timestampSeconds: 1.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 134, rightKneeAngle: 134, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Rock back to exact starting point: scale 1.0, knees return to standing 165
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165, scaleMultiplier: 1.0, dropOverride: 0.0), timestampSeconds: 1.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final res = squatSM.processFrame(frame, feats);

      expect(res, isNull);
      expect(squatSM.repCount, equals(0), reason: 'Forward/backward rocking must not count as squat rep');
    });

    test('16. Alternating walking stride -> 0 reps (rejected by asymmetry / unilateral flexion)', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Standing
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Left swing (knee 120), right stance (knee 165) -> kneeDiff 45 > 32
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 140, isSingleLegLift: true), timestampSeconds: 0.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 120, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Right swing (knee 120), left stance (knee 165)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 140, isSingleLegLift: true), timestampSeconds: 1.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 120, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Both feet down standing
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 1.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final res = squatSM.processFrame(frame, feats);

      expect(res, isNull);
      expect(squatSM.repCount, equals(0), reason: 'Alternating walking strides must not count as squat rep');
    });

    test('17. Genuine shallow squat around 115° -> 1 rep', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Frame 1: Standing
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 2: Descending
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 135), timestampSeconds: 0.4, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 135, rightKneeAngle: 135, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);
      expect(squatSM.currentState, equals(ExerciseState.descending));

      // Frame 3: Shallow depth inflection (115° <= 118°)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 115), timestampSeconds: 0.8, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 115, rightKneeAngle: 115, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 4: Rebound inflection to bottom (123° > 115 + 6)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 123), timestampSeconds: 1.2, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 123, rightKneeAngle: 123, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);
      expect(squatSM.currentState, equals(ExerciseState.bottom));

      // Frame 5: Ascending (135°)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 135), timestampSeconds: 1.6, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 135, rightKneeAngle: 135, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);
      expect(squatSM.currentState, equals(ExerciseState.ascending));

      // Frame 6: Standing lockout (165°) -> Rep complete!
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 2.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final res = squatSM.processFrame(frame, feats);

      expect(res, isNotNull);
      expect(squatSM.repCount, equals(1));
      expect(res!.formStatus, equals('bad'));
      expect(res.activeFlags.contains('SHALLOW_DEPTH'), isTrue);
    });

    test('18. Genuine deep squat around 80° -> 1 rep', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Frame 1: Standing
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 2: Descending
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 130), timestampSeconds: 0.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 130, rightKneeAngle: 130, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);
      expect(squatSM.currentState, equals(ExerciseState.descending));

      // Frame 3: Deep bottom inflection at 80° (<= 105°)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 80), timestampSeconds: 1.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 80, rightKneeAngle: 80, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);
      expect(squatSM.currentState, equals(ExerciseState.bottom));

      // Frame 4: Ascending (125°)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 125), timestampSeconds: 1.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 125, rightKneeAngle: 125, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);
      expect(squatSM.currentState, equals(ExerciseState.ascending));

      // Frame 5: Standing lockout (165°) -> Rep complete!
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 2.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final res = squatSM.processFrame(frame, feats);

      expect(res, isNotNull);
      expect(squatSM.repCount, equals(1));
      expect(res!.formStatus, equals('good'));
      expect(res.activeFlags, isEmpty);
    });

    test('19. Bottom -> immediate lockout without an ascent frame -> rejected by minAscendingFrames', () {
      final squatSM = SquatStateMachine(classifierService: service);

      // Frame 1: Standing
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 2: Descending
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 130), timestampSeconds: 0.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 130, rightKneeAngle: 130, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);

      // Frame 3: Bottom (80°)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 80), timestampSeconds: 1.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 80, rightKneeAngle: 80, leftElbowAngle: 165, rightElbowAngle: 165);
      squatSM.processFrame(frame, feats);
      expect(squatSM.currentState, equals(ExerciseState.bottom));

      // Frame 4: Instantly jump straight to standing (165°) without ANY ascending frame
      frame = PoseFrame(landmarks: createSyntheticLandmarks(kneeAngle: 165), timestampSeconds: 1.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final res = squatSM.processFrame(frame, feats);

      expect(res, isNull, reason: 'Instantaneous jump from bottom to standing must be rejected');
      expect(squatSM.repCount, equals(0));
      expect(squatSM.lastRejectionReason, equals('REJECT_INSUFFICIENT_FRAMES'));
    });
  });

  group('Push-up State Machine', () {
    test('PlankHigh -> Descending -> Bottom -> Ascending -> PlankHigh full rep cycle', () {
      final pushupSM = PushupStateMachine(classifierService: service);

      // Frame 1: High plank (160 deg)
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 160, rightElbowAngle: 160, trunkInclination: 85);
      var res = pushupSM.processFrame(frame, feats);
      expect(res, isNull);
      expect(pushupSM.repCount, equals(0));

      // Frame 2: Descending (120 deg)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 0.6, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 120, rightElbowAngle: 120, trunkInclination: 85);
      res = pushupSM.processFrame(frame, feats);
      expect(res, isNull);
      expect(pushupSM.currentState, equals(ExerciseState.descending));

      // Frame 3: Bottom inflection (85 deg deep pushup)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 1.2, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 85, rightElbowAngle: 85, trunkInclination: 85);
      res = pushupSM.processFrame(frame, feats);
      expect(res, isNull);
      expect(pushupSM.currentState, equals(ExerciseState.bottom));

      // Frame 4: Ascending (125 deg)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 1.8, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 125, rightElbowAngle: 125, trunkInclination: 85);
      res = pushupSM.processFrame(frame, feats);
      expect(res, isNull);
      expect(pushupSM.currentState, equals(ExerciseState.ascending));

      // Frame 5: High plank Lockout (155 deg) -> +1 Rep!
      frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 2.4, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 155, rightElbowAngle: 155, trunkInclination: 85);
      res = pushupSM.processFrame(frame, feats);
      expect(res, isNotNull, reason: 'Push-up rep must complete on return to high plank');
      expect(pushupSM.repCount, equals(1));
      final completedPushup = res!;
      expect(completedPushup.exercise, equals('push_up'));
      expect(completedPushup.formStatus, equals('good'));
    });

    test('Standing posture with bent elbows does NOT trigger push-up (requires horizontal alignment)', () {
      final pushupSM = PushupStateMachine(classifierService: service);

      // Frame 1: Standing upright (trunk 15 deg from vertical)
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 160, rightElbowAngle: 160, trunkInclination: 15);
      pushupSM.processFrame(frame, feats);

      // Frame 2: Bend elbows while standing upright (e.g. bicep curl or arm wave)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 0.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 80, rightElbowAngle: 80, trunkInclination: 15);
      final res = pushupSM.processFrame(frame, feats);

      expect(res, isNull);
      expect(pushupSM.currentState, equals(ExerciseState.plankHigh),
          reason: 'Non-horizontal trunk must never start a push-up descent');
      expect(pushupSM.repCount, equals(0));
    });

    test('Shallow arm bounce in plank (min elbow 120 deg) resets candidate cleanly without rep', () {
      final pushupSM = PushupStateMachine(classifierService: service);

      // Frame 1: High plank
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 160, rightElbowAngle: 160, trunkInclination: 85);
      pushupSM.processFrame(frame, feats);

      // Frame 2: Slight descent to 120 deg (does not reach 108 deg depth)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 0.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 120, rightElbowAngle: 120, trunkInclination: 85);
      pushupSM.processFrame(frame, feats);
      expect(pushupSM.currentState, equals(ExerciseState.descending));

      // Frame 3: Early rebound back to high plank lockout (145 deg) without reaching depth
      frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 1.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 145, rightElbowAngle: 145, trunkInclination: 85);
      final res = pushupSM.processFrame(frame, feats);

      expect(res, isNull);
      expect(pushupSM.currentState, equals(ExerciseState.plankHigh),
          reason: 'Candidate without sufficient depth must reset to plankHigh');
      expect(pushupSM.repCount, equals(0));
    });

    test('Push-up with sagging hips is flagged HIP_SAG with bad form', () {
      final pushupSM = PushupStateMachine(classifierService: service);

      // Frame 1: High plank
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 160, rightElbowAngle: 160, trunkInclination: 85, hipAngle: 135);
      pushupSM.processFrame(frame, feats);

      // Frame 2: Descending
      frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 0.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 120, rightElbowAngle: 120, trunkInclination: 85, hipAngle: 135);
      pushupSM.processFrame(frame, feats);

      // Frame 3: Bottom inflection (85 deg) with sagging hips (135 deg < 140 deg)
      frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 1.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 85, rightElbowAngle: 85, trunkInclination: 85, hipAngle: 135);
      pushupSM.processFrame(frame, feats);

      // Frame 4: Ascending
      frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 1.5, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 125, rightElbowAngle: 125, trunkInclination: 85, hipAngle: 135);
      pushupSM.processFrame(frame, feats);

      // Frame 5: Lockout
      frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 2.0, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 155, rightElbowAngle: 155, trunkInclination: 85, hipAngle: 135);
      final res = pushupSM.processFrame(frame, feats);

      expect(res, isNotNull);
      expect(pushupSM.repCount, equals(1));
      expect(res!.formStatus, equals('bad'));
      expect(res.activeFlags.contains('HIP_SAG_OR_PIKE'), isTrue);
      expect(res.feedback, contains('core'));
    });

    test('Side-camera view with occluded arm (leftElbow: 85 deg, rightElbow: 155 deg) counts rep correctly', () {
      final pushupSM = PushupStateMachine(classifierService: service);

      // Frame 1: High plank in side view
      var frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 0.0, isDetected: true);
      var feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 150, rightElbowAngle: 155, trunkInclination: 85);
      pushupSM.processFrame(frame, feats);

      // Frame 2: Descending - visible arm bends to 110 deg, far arm occluded at 150 deg
      frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 0.6, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 110, rightElbowAngle: 150, trunkInclination: 85);
      pushupSM.processFrame(frame, feats);
      expect(pushupSM.currentState, equals(ExerciseState.descending));

      // Frame 3: Bottom - visible arm hits 85 deg, far arm occluded behind chest at 155 deg
      frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 1.2, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 85, rightElbowAngle: 155, trunkInclination: 85);
      pushupSM.processFrame(frame, feats);
      expect(pushupSM.currentState, equals(ExerciseState.bottom));

      // Frame 4: Ascending
      frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 1.8, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 125, rightElbowAngle: 150, trunkInclination: 85);
      pushupSM.processFrame(frame, feats);
      expect(pushupSM.currentState, equals(ExerciseState.ascending));

      // Frame 5: Lockout at top
      frame = PoseFrame(landmarks: createSyntheticLandmarks(), timestampSeconds: 2.4, isDetected: true);
      feats = createSyntheticFeatures(leftKneeAngle: 175, rightKneeAngle: 175, leftElbowAngle: 145, rightElbowAngle: 150, trunkInclination: 85);
      final res = pushupSM.processFrame(frame, feats);

      expect(res, isNotNull, reason: 'Side-view pushup must count rep even if one arm is occluded');
      expect(pushupSM.repCount, equals(1));
      expect(res!.exercise, equals('push_up'));
      expect(res.formStatus, equals('good'));
    });
  });

  group('Visibility Handling', () {
    test('Low visibility frames safely rejected without state corruption', () {
      final squatSM = SquatStateMachine(classifierService: service);
      final lowVisLandmarks = createSyntheticLandmarks(visibility: 0.1);
      final frame = PoseFrame(landmarks: lowVisLandmarks, timestampSeconds: 5.0, isDetected: true);
      expect(frame.hasMinimumVisibility(), isFalse);

      final feats = createSyntheticFeatures(leftKneeAngle: 165, rightKneeAngle: 165, leftElbowAngle: 165, rightElbowAngle: 165);
      final res = squatSM.processFrame(frame, feats);
      expect(res, isNull, reason: 'Low visibility frame must not corrupt state or trigger false reps');
    });
  });
}
