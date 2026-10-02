import 'dart:math' as math;
import '../models/landmark.dart';
import '../models/pose_frame.dart';
import '../models/prediction_result.dart';

/// Configuration thresholds for the Squat Repetition Gate.
class SquatGateConfig {
  // A. Bilateral Knee Movement
  final double maxBilateralKneeDiff; // degrees
  final double maxSingleKneeDescentThreshold; // degrees
  final double maxKneeDepthThreshold; // degrees (minimum depth required to be a squat rep)

  // B. Squat-Specific Hip/Pelvis Movement
  final double minNormalizedHipDrop; // fraction of torso scale
  final double maxHipReturnTolerance; // fraction of torso scale

  // C. Whole-Body Translation / Walking Rejection
  final double maxTorsoScaleChange; // fraction of start torso scale
  final double maxNetScaleDrift; // net start-to-end scale drift from walking toward/away
  final double maxHorizontalTranslation; // fraction of torso scale

  // D. Foot/Ankle Stability
  final double maxAnkleDisplacement; // fraction of torso scale

  // E. Temporal Validation
  final int minDescendingFrames;
  final int minBottomFrames;
  final int minAscendingFrames;
  final int minTotalFrames;
  final double minRepDurationSeconds;
  final double maxRepDurationSeconds;
  final double cooldownSeconds;

  // F. Exercise Classifier Gating
  final double minSquatClassificationRatio;
  final double minSquatConfidence;

  const SquatGateConfig({
    this.maxBilateralKneeDiff = 32.0,
    this.maxSingleKneeDescentThreshold = 145.0,
    this.maxKneeDepthThreshold = 128.0,
    this.minNormalizedHipDrop = 0.09,
    this.maxHipReturnTolerance = 0.30,
    this.maxTorsoScaleChange = 0.22,
    this.maxNetScaleDrift = 0.12,
    this.maxHorizontalTranslation = 0.35,
    this.maxAnkleDisplacement = 0.28,
    this.minDescendingFrames = 1,
    this.minBottomFrames = 1,
    this.minAscendingFrames = 0,
    this.minTotalFrames = 4,
    this.minRepDurationSeconds = 0.40,
    this.maxRepDurationSeconds = 8.0,
    this.cooldownSeconds = 0.20,
    this.minSquatClassificationRatio = 0.40,
    this.minSquatConfidence = 0.40,
  });
}

/// Body geometry extracted from a PoseFrame for rep trajectory tracking.
class BodyMetrics {
  final double midHipX;
  final double midHipY;
  final double midHipZ;
  final double midShoulderX;
  final double midShoulderY;
  final double torsoScale;
  final double leftAnkleX;
  final double leftAnkleY;
  final double rightAnkleX;
  final double rightAnkleY;

  const BodyMetrics({
    required this.midHipX,
    required this.midHipY,
    required this.midHipZ,
    required this.midShoulderX,
    required this.midShoulderY,
    required this.torsoScale,
    required this.leftAnkleX,
    required this.leftAnkleY,
    required this.rightAnkleX,
    required this.rightAnkleY,
  });

  factory BodyMetrics.fromFrame(PoseFrame frame) {
    if (frame.landmarks.length < 33) {
      return const BodyMetrics(
        midHipX: 0.5,
        midHipY: 0.5,
        midHipZ: 0.0,
        midShoulderX: 0.5,
        midShoulderY: 0.25,
        torsoScale: 0.30,
        leftAnkleX: 0.45,
        leftAnkleY: 0.90,
        rightAnkleX: 0.55,
        rightAnkleY: 0.90,
      );
    }

    final lms = frame.landmarks;
    final leftHip = lms[Landmark.leftHip];
    final rightHip = lms[Landmark.rightHip];
    final leftShoulder = lms[Landmark.leftShoulder];
    final rightShoulder = lms[Landmark.rightShoulder];
    final leftAnkle = lms[Landmark.leftAnkle];
    final rightAnkle = lms[Landmark.rightAnkle];

    final hipX = (leftHip.x + rightHip.x) / 2.0;
    final hipY = (leftHip.y + rightHip.y) / 2.0;
    final hipZ = (leftHip.z + rightHip.z) / 2.0;

    final shX = (leftShoulder.x + rightShoulder.x) / 2.0;
    final shY = (leftShoulder.y + rightShoulder.y) / 2.0;

    final dx = shX - hipX;
    final dy = shY - hipY;
    final dist = math.sqrt(dx * dx + dy * dy);

    // Fallback if torso distance is collapsed / dummy
    final scale = dist > 0.02 ? dist : 0.30;

    return BodyMetrics(
      midHipX: hipX,
      midHipY: hipY,
      midHipZ: hipZ,
      midShoulderX: shX,
      midShoulderY: shY,
      torsoScale: scale,
      leftAnkleX: leftAnkle.x,
      leftAnkleY: leftAnkle.y,
      rightAnkleX: rightAnkle.x,
      rightAnkleY: rightAnkle.y,
    );
  }
}

/// Tracks the lifecycle and biomechanical telemetry of a single candidate squat rep.
class SquatCandidateTracker {
  final double startTime;
  double lastFrameTime;
  final BodyMetrics startMetrics;

  // Frame counts
  int descendingFrames = 0;
  int bottomFrames = 0;
  int ascendingFrames = 0;
  int totalFrames = 0;

  // A. Bilateral Knee Participation
  bool leftKneeDescended = false;
  bool rightKneeDescended = false;
  double minLeftKnee = 180.0;
  double minRightKnee = 180.0;
  double maxKneeDiff = 0.0;

  // B. Hip Vertical Trajectory
  double maxHipDrop = 0.0; // max normalized downward displacement
  double endHipReturn = 0.0; // final return to start position

  // C. Whole-Body Translation
  double maxTorsoScaleChange = 0.0;
  double maxHorizontalTranslation = 0.0;
  double finalTorsoScale = 0.0;

  // D. Foot/Ankle Stability
  double maxLeftAnkleDisp = 0.0;
  double maxRightAnkleDisp = 0.0;

  // F. Exercise Classifier Tracking
  int squatClassifierVotes = 0;
  int totalClassifierVotes = 0;
  String? bottomPredictedExercise;
  double? bottomExerciseConfidence;

  SquatCandidateTracker({
    required this.startTime,
    required this.startMetrics,
  })  : lastFrameTime = startTime,
        finalTorsoScale = startMetrics.torsoScale;

  void recordFrame({
    required PoseFrame frame,
    required double leftKnee,
    required double rightKnee,
    required ExerciseState state,
    required double descentThreshold,
  }) {
    totalFrames++;
    lastFrameTime = frame.timestampSeconds;

    switch (state) {
      case ExerciseState.descending:
        descendingFrames++;
        break;
      case ExerciseState.bottom:
        bottomFrames++;
        break;
      case ExerciseState.ascending:
        ascendingFrames++;
        break;
      default:
        break;
    }

    // A. Bilateral knee tracking
    if (leftKnee < minLeftKnee) minLeftKnee = leftKnee;
    if (rightKnee < minRightKnee) minRightKnee = rightKnee;

    if (leftKnee <= descentThreshold) leftKneeDescended = true;
    if (rightKnee <= descentThreshold) rightKneeDescended = true;

    final kneeDiff = (leftKnee - rightKnee).abs();
    if (kneeDiff > maxKneeDiff) maxKneeDiff = kneeDiff;

    // Biomechanics
    final current = BodyMetrics.fromFrame(frame);
    final scale = startMetrics.torsoScale > 0.02 ? startMetrics.torsoScale : 0.30;
    finalTorsoScale = current.torsoScale;

    // B. Hip vertical movement (Y increases downwards in camera coordinates)
    final hipDrop = (current.midHipY - startMetrics.midHipY) / scale;
    if (hipDrop > maxHipDrop) maxHipDrop = hipDrop;
    endHipReturn = ((current.midHipY - startMetrics.midHipY) / scale).abs();

    // C. Translation / Scale change
    final scaleChange = ((current.torsoScale - startMetrics.torsoScale) / startMetrics.torsoScale).abs();
    if (scaleChange > maxTorsoScaleChange) maxTorsoScaleChange = scaleChange;

    final horizTrans = ((current.midHipX - startMetrics.midHipX) / scale).abs();
    if (horizTrans > maxHorizontalTranslation) maxHorizontalTranslation = horizTrans;

    // D. Ankle stability
    final lAnkDx = current.leftAnkleX - startMetrics.leftAnkleX;
    final lAnkDy = current.leftAnkleY - startMetrics.leftAnkleY;
    final lAnkDisp = math.sqrt(lAnkDx * lAnkDx + lAnkDy * lAnkDy) / scale;
    if (lAnkDisp > maxLeftAnkleDisp) maxLeftAnkleDisp = lAnkDisp;

    final rAnkDx = current.rightAnkleX - startMetrics.rightAnkleX;
    final rAnkDy = current.rightAnkleY - startMetrics.rightAnkleY;
    final rAnkDisp = math.sqrt(rAnkDx * rAnkDx + rAnkDy * rAnkDy) / scale;
    if (rAnkDisp > maxRightAnkleDisp) maxRightAnkleDisp = rAnkDisp;
  }

  void recordClassifierPrediction(String exercise, double confidence) {
    totalClassifierVotes++;
    if (exercise == 'squat') {
      squatClassifierVotes++;
    }
  }

  void recordBottomInflection(String exercise, double confidence) {
    bottomPredictedExercise = exercise;
    bottomExerciseConfidence = confidence;
  }
}

/// Validation result with detailed diagnostic telemetry.
class SquatValidationResult {
  final bool isValid;
  final String? rejectionReason;
  final Map<String, dynamic> diagnostics;

  const SquatValidationResult({
    required this.isValid,
    this.rejectionReason,
    this.diagnostics = const {},
  });

  static const valid = SquatValidationResult(isValid: true);

  factory SquatValidationResult.reject(String reason, [Map<String, dynamic> diag = const {}]) {
    return SquatValidationResult(
      isValid: false,
      rejectionReason: reason,
      diagnostics: diag,
    );
  }
}

/// Independent multi-signal Squat Repetition Gate implementing signals A - F.
class SquatRepGate {
  final SquatGateConfig config;

  const SquatRepGate({this.config = const SquatGateConfig()});

  /// Evaluates an incoming candidate against all independent gating criteria.
  SquatValidationResult validate(SquatCandidateTracker candidate) {
    final diag = <String, dynamic>{
      'descendingFrames': candidate.descendingFrames,
      'bottomFrames': candidate.bottomFrames,
      'ascendingFrames': candidate.ascendingFrames,
      'totalFrames': candidate.totalFrames,
      'minLeftKnee': candidate.minLeftKnee,
      'minRightKnee': candidate.minRightKnee,
      'maxKneeDiff': candidate.maxKneeDiff,
      'maxHipDrop': candidate.maxHipDrop,
      'endHipReturn': candidate.endHipReturn,
      'maxTorsoScaleChange': candidate.maxTorsoScaleChange,
      'maxHorizontalTranslation': candidate.maxHorizontalTranslation,
      'maxLeftAnkleDisp': candidate.maxLeftAnkleDisp,
      'maxRightAnkleDisp': candidate.maxRightAnkleDisp,
      'squatVotes': candidate.squatClassifierVotes,
      'totalVotes': candidate.totalClassifierVotes,
    };

    // E. Temporal Validation
    final duration = candidate.lastFrameTime - candidate.startTime;
    diag['durationSeconds'] = duration;

    if (candidate.descendingFrames < config.minDescendingFrames ||
        candidate.bottomFrames < config.minBottomFrames ||
        (config.minAscendingFrames > 0 && candidate.ascendingFrames < config.minAscendingFrames) ||
        candidate.totalFrames < config.minTotalFrames ||
        duration < config.minRepDurationSeconds) {
      return SquatValidationResult.reject('REJECT_INSUFFICIENT_FRAMES', diag);
    }

    if (duration > config.maxRepDurationSeconds) {
      return SquatValidationResult.reject('REJECT_DURATION_TIMEOUT', diag);
    }

    // A. Bilateral Knee Participation & Minimum Squat Depth
    if (!candidate.leftKneeDescended || !candidate.rightKneeDescended) {
      return SquatValidationResult.reject('REJECT_UNILATERAL_KNEE_MOVEMENT', diag);
    }

    if (candidate.minLeftKnee >= config.maxSingleKneeDescentThreshold ||
        candidate.minRightKnee >= config.maxSingleKneeDescentThreshold) {
      return SquatValidationResult.reject('REJECT_UNILATERAL_KNEE_MOVEMENT', diag);
    }

    // Must reach actual squat depth (at least one knee <= maxKneeDepthThreshold)
    if (candidate.minLeftKnee > config.maxKneeDepthThreshold &&
        candidate.minRightKnee > config.maxKneeDepthThreshold) {
      return SquatValidationResult.reject('REJECT_INSUFFICIENT_KNEE_DEPTH', diag);
    }

    if (candidate.maxKneeDiff > config.maxBilateralKneeDiff) {
      return SquatValidationResult.reject('REJECT_ASYMMETRIC_KNEES', diag);
    }

    // B. Squat-Specific Hip/Pelvis Trajectory
    if (candidate.maxHipDrop < config.minNormalizedHipDrop) {
      return SquatValidationResult.reject('REJECT_INSUFFICIENT_HIP_DROP', diag);
    }

    if (candidate.endHipReturn > config.maxHipReturnTolerance) {
      return SquatValidationResult.reject('REJECT_HIP_NOT_RETURNED', diag);
    }

    // C. Whole-Body Translation / Walking Rejection (Toward/Away & Lateral)
    if (candidate.maxTorsoScaleChange > config.maxTorsoScaleChange) {
      return SquatValidationResult.reject('REJECT_WALKING_SCALE_TRANSLATION', diag);
    }

    // Net scale drift: detects moving towards/away from camera
    final startScale = candidate.startMetrics.torsoScale > 0.02 ? candidate.startMetrics.torsoScale : 0.30;
    final netScaleDrift = ((candidate.finalTorsoScale - candidate.startMetrics.torsoScale) / startScale).abs();
    diag['netScaleDrift'] = netScaleDrift;
    if (netScaleDrift > config.maxNetScaleDrift) {
      return SquatValidationResult.reject('REJECT_WALKING_SCALE_TRANSLATION', diag);
    }

    if (candidate.maxHorizontalTranslation > config.maxHorizontalTranslation) {
      return SquatValidationResult.reject('REJECT_HORIZONTAL_BODY_TRANSLATION', diag);
    }

    // D. Foot/Ankle Stability
    if (candidate.maxLeftAnkleDisp > config.maxAnkleDisplacement ||
        candidate.maxRightAnkleDisp > config.maxAnkleDisplacement) {
      return SquatValidationResult.reject('REJECT_UNSTABLE_FEET', diag);
    }

    // F. Exercise Classifier Gating
    if (candidate.totalClassifierVotes > 0) {
      final squatRatio = candidate.squatClassifierVotes / candidate.totalClassifierVotes;
      diag['squatRatio'] = squatRatio;

      if (squatRatio < config.minSquatClassificationRatio) {
        return SquatValidationResult.reject('REJECT_CLASSIFIER_MISMATCH', diag);
      }
    }

    return SquatValidationResult(isValid: true, diagnostics: diag);
  }
}
