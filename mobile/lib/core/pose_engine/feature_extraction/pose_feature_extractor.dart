import 'dart:math' as math;
import '../models/landmark.dart';
import 'landmark_normalizer.dart';

/// Computes the complete 140-feature representation from 33 body landmarks.
/// Mirrors Python `ml.preprocessing.feature_engineering` exactly.
class PoseFeatureExtractor {
  // Ordered list of 140 feature names matching Python training
  static final List<String> featureNames = _buildFeatureNames();

  static List<String> _buildFeatureNames() {
    final names = <String>[];
    // Group A: 99 normalized landmark coordinates
    for (int i = 0; i < 33; i++) {
      names.add('norm_lm_${i}_x');
      names.add('norm_lm_${i}_y');
      names.add('norm_lm_${i}_z');
    }
    // Group B: 12 Joint angles
    names.addAll([
      'angle_left_knee',
      'angle_right_knee',
      'angle_left_hip',
      'angle_right_hip',
      'angle_left_elbow',
      'angle_right_elbow',
      'angle_left_shoulder',
      'angle_right_shoulder',
      'angle_left_ankle',
      'angle_right_ankle',
      'angle_trunk_inclination',
      'angle_neck',
    ]);
    // Group C: 12 Relative distances
    names.addAll([
      'dist_left_ankle_to_hip',
      'dist_right_ankle_to_hip',
      'dist_left_wrist_to_shoulder',
      'dist_right_wrist_to_shoulder',
      'dist_left_wrist_to_hip',
      'dist_right_wrist_to_hip',
      'dist_left_knee_to_hip',
      'dist_right_knee_to_hip',
      'dist_ankle_spread',
      'dist_wrist_spread',
      'dist_hip_width',
      'dist_shoulder_width',
    ]);
    // Group D: 17 Temporal kinematics
    names.addAll([
      'vel_left_ankle',
      'vel_right_ankle',
      'vel_left_knee',
      'vel_right_knee',
      'vel_left_hip',
      'vel_right_hip',
      'vel_left_wrist',
      'vel_right_wrist',
      'vel_mid_hip_y',
      'vel_mid_shoulder_y',
      'd_angle_left_knee',
      'd_angle_right_knee',
      'd_angle_left_hip',
      'd_angle_right_hip',
      'd_angle_left_elbow',
      'd_angle_right_elbow',
      'd_angle_trunk',
    ]);
    return names;
  }

  // Temporal state memory
  List<Landmark>? _prevNormLandmarks;
  double? _prevTimestamp;
  final Map<String, double> _prevAngles = {};

  /// Resets state between workout sessions.
  void reset() {
    _prevNormLandmarks = null;
    _prevTimestamp = null;
    _prevAngles.clear();
  }

  /// Calculates 3D angle ABC in degrees with vertex at b.
  static double calculate3dAngle(Landmark a, Landmark b, Landmark c) {
    final bax = a.x - b.x;
    final bay = a.y - b.y;
    final baz = a.z - b.z;

    final bcx = c.x - b.x;
    final bcy = c.y - b.y;
    final bcz = c.z - b.z;

    final normBa = math.sqrt(bax * bax + bay * bay + baz * baz);
    final normBc = math.sqrt(bcx * bcx + bcy * bcy + bcz * bcz);

    if (normBa < 1e-6 || normBc < 1e-6) {
      return 0.0;
    }

    final dot = bax * bcx + bay * bcy + baz * bcz;
    double cosine = dot / (normBa * normBc);
    if (cosine > 1.0) cosine = 1.0;
    if (cosine < -1.0) cosine = -1.0;

    return math.acos(cosine) * 180.0 / math.pi;
  }

  /// Calculates Euclidean distance between two landmarks.
  static double distance(Landmark a, Landmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final dz = a.z - b.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Extracts the exact 140 features in canonical order from raw landmarks.
  List<double> extractFeatures(
    List<Landmark> rawLandmarks, {
    double? timestampSeconds,
    bool isNormalized = false,
  }) {
    // 1. Normalize landmarks if not already normalized
    final List<Landmark> normLandmarks;
    if (isNormalized) {
      normLandmarks = rawLandmarks;
    } else {
      normLandmarks = LandmarkNormalizer.normalize(rawLandmarks).landmarks;
    }

    final feats = <String, double>{};

    // Group A: 99 Normalized landmark coordinates
    for (int i = 0; i < 33; i++) {
      final lm = normLandmarks[i];
      feats['norm_lm_${i}_x'] = lm.x;
      feats['norm_lm_${i}_y'] = lm.y;
      feats['norm_lm_${i}_z'] = lm.z;
    }

    // Group B: 12 Joint angles
    final leftHip = normLandmarks[Landmark.leftHip];
    final rightHip = normLandmarks[Landmark.rightHip];
    final leftKnee = normLandmarks[Landmark.leftKnee];
    final rightKnee = normLandmarks[Landmark.rightKnee];
    final leftAnkle = normLandmarks[Landmark.leftAnkle];
    final rightAnkle = normLandmarks[Landmark.rightAnkle];
    final leftShoulder = normLandmarks[Landmark.leftShoulder];
    final rightShoulder = normLandmarks[Landmark.rightShoulder];
    final leftElbow = normLandmarks[Landmark.leftElbow];
    final rightElbow = normLandmarks[Landmark.rightElbow];
    final leftWrist = normLandmarks[Landmark.leftWrist];
    final rightWrist = normLandmarks[Landmark.rightWrist];
    final leftFootIndex = normLandmarks[Landmark.leftFootIndex];
    final rightFootIndex = normLandmarks[Landmark.rightFootIndex];
    final nose = normLandmarks[Landmark.nose];

    feats['angle_left_knee'] = calculate3dAngle(leftHip, leftKnee, leftAnkle);
    feats['angle_right_knee'] = calculate3dAngle(rightHip, rightKnee, rightAnkle);
    feats['angle_left_hip'] = calculate3dAngle(leftShoulder, leftHip, leftKnee);
    feats['angle_right_hip'] = calculate3dAngle(rightShoulder, rightHip, rightKnee);
    feats['angle_left_elbow'] = calculate3dAngle(leftShoulder, leftElbow, leftWrist);
    feats['angle_right_elbow'] = calculate3dAngle(rightShoulder, rightElbow, rightWrist);
    feats['angle_left_shoulder'] = calculate3dAngle(leftElbow, leftShoulder, leftHip);
    feats['angle_right_shoulder'] = calculate3dAngle(rightElbow, rightShoulder, rightHip);
    feats['angle_left_ankle'] = calculate3dAngle(leftKnee, leftAnkle, leftFootIndex);
    feats['angle_right_ankle'] = calculate3dAngle(rightKnee, rightAnkle, rightFootIndex);

    // Torso inclination angle
    final midHipX = (leftHip.x + rightHip.x) / 2.0;
    final midHipY = (leftHip.y + rightHip.y) / 2.0;
    final midHipZ = (leftHip.z + rightHip.z) / 2.0;

    final midShX = (leftShoulder.x + rightShoulder.x) / 2.0;
    final midShY = (leftShoulder.y + rightShoulder.y) / 2.0;
    final midShZ = (leftShoulder.z + rightShoulder.z) / 2.0;

    final torsoDx = midShX - midHipX;
    final torsoDy = midShY - midHipY;
    final torsoDz = midShZ - midHipZ;
    final normTorso = math.sqrt(torsoDx * torsoDx + torsoDy * torsoDy + torsoDz * torsoDz);

    if (normTorso > 1e-6) {
      // verticalUp is [0.0, -1.0, 0.0] -> dot product is -torsoDy
      double cosTrunk = -torsoDy / normTorso;
      if (cosTrunk > 1.0) cosTrunk = 1.0;
      if (cosTrunk < -1.0) cosTrunk = -1.0;
      feats['angle_trunk_inclination'] = math.acos(cosTrunk) * 180.0 / math.pi;
    } else {
      feats['angle_trunk_inclination'] = 0.0;
    }

    // Neck angle
    final neckDx = nose.x - midShX;
    final neckDy = nose.y - midShY;
    final neckDz = nose.z - midShZ;
    final normNeck = math.sqrt(neckDx * neckDx + neckDy * neckDy + neckDz * neckDz);

    if (normTorso > 1e-6 && normNeck > 1e-6) {
      final dotNeck = neckDx * torsoDx + neckDy * torsoDy + neckDz * torsoDz;
      double cosNeck = dotNeck / (normNeck * normTorso);
      if (cosNeck > 1.0) cosNeck = 1.0;
      if (cosNeck < -1.0) cosNeck = -1.0;
      feats['angle_neck'] = math.acos(cosNeck) * 180.0 / math.pi;
    } else {
      feats['angle_neck'] = 0.0;
    }

    // Group C: 12 Relative distances
    feats['dist_left_ankle_to_hip'] = distance(leftAnkle, leftHip);
    feats['dist_right_ankle_to_hip'] = distance(rightAnkle, rightHip);
    feats['dist_left_wrist_to_shoulder'] = distance(leftWrist, leftShoulder);
    feats['dist_right_wrist_to_shoulder'] = distance(rightWrist, rightShoulder);
    feats['dist_left_wrist_to_hip'] = distance(leftWrist, leftHip);
    feats['dist_right_wrist_to_hip'] = distance(rightWrist, rightHip);
    feats['dist_left_knee_to_hip'] = distance(leftKnee, leftHip);
    feats['dist_right_knee_to_hip'] = distance(rightKnee, rightHip);
    feats['dist_ankle_spread'] = distance(leftAnkle, rightAnkle);
    feats['dist_wrist_spread'] = distance(leftWrist, rightWrist);
    feats['dist_hip_width'] = distance(leftHip, rightHip);
    feats['dist_shoulder_width'] = distance(leftShoulder, rightShoulder);

    // Group D: 17 Temporal kinematics
    if (_prevNormLandmarks == null || timestampSeconds == null || _prevTimestamp == null) {
      feats['vel_left_ankle'] = 0.0;
      feats['vel_right_ankle'] = 0.0;
      feats['vel_left_knee'] = 0.0;
      feats['vel_right_knee'] = 0.0;
      feats['vel_left_hip'] = 0.0;
      feats['vel_right_hip'] = 0.0;
      feats['vel_left_wrist'] = 0.0;
      feats['vel_right_wrist'] = 0.0;
      feats['vel_mid_hip_y'] = 0.0;
      feats['vel_mid_shoulder_y'] = 0.0;
      feats['d_angle_left_knee'] = 0.0;
      feats['d_angle_right_knee'] = 0.0;
      feats['d_angle_left_hip'] = 0.0;
      feats['d_angle_right_hip'] = 0.0;
      feats['d_angle_left_elbow'] = 0.0;
      feats['d_angle_right_elbow'] = 0.0;
      feats['d_angle_trunk'] = 0.0;
    } else {
      final dt = math.max(1e-4, timestampSeconds - _prevTimestamp!);
      final prev = _prevNormLandmarks!;

      feats['vel_left_ankle'] = distance(leftAnkle, prev[Landmark.leftAnkle]) / dt;
      feats['vel_right_ankle'] = distance(rightAnkle, prev[Landmark.rightAnkle]) / dt;
      feats['vel_left_knee'] = distance(leftKnee, prev[Landmark.leftKnee]) / dt;
      feats['vel_right_knee'] = distance(rightKnee, prev[Landmark.rightKnee]) / dt;
      feats['vel_left_hip'] = distance(leftHip, prev[Landmark.leftHip]) / dt;
      feats['vel_right_hip'] = distance(rightHip, prev[Landmark.rightHip]) / dt;
      feats['vel_left_wrist'] = distance(leftWrist, prev[Landmark.leftWrist]) / dt;
      feats['vel_right_wrist'] = distance(rightWrist, prev[Landmark.rightWrist]) / dt;

      final prevMidHipY = (prev[Landmark.leftHip].y + prev[Landmark.rightHip].y) / 2.0;
      final currMidHipY = midHipY;
      feats['vel_mid_hip_y'] = (currMidHipY - prevMidHipY) / dt;

      final prevMidShY = (prev[Landmark.leftShoulder].y + prev[Landmark.rightShoulder].y) / 2.0;
      final currMidShY = midShY;
      feats['vel_mid_shoulder_y'] = (currMidShY - prevMidShY) / dt;

      feats['d_angle_left_knee'] = (feats['angle_left_knee']! - (_prevAngles['angle_left_knee'] ?? feats['angle_left_knee']!)) / dt;
      feats['d_angle_right_knee'] = (feats['angle_right_knee']! - (_prevAngles['angle_right_knee'] ?? feats['angle_right_knee']!)) / dt;
      feats['d_angle_left_hip'] = (feats['angle_left_hip']! - (_prevAngles['angle_left_hip'] ?? feats['angle_left_hip']!)) / dt;
      feats['d_angle_right_hip'] = (feats['angle_right_hip']! - (_prevAngles['angle_right_hip'] ?? feats['angle_right_hip']!)) / dt;
      feats['d_angle_left_elbow'] = (feats['angle_left_elbow']! - (_prevAngles['angle_left_elbow'] ?? feats['angle_left_elbow']!)) / dt;
      feats['d_angle_right_elbow'] = (feats['angle_right_elbow']! - (_prevAngles['angle_right_elbow'] ?? feats['angle_right_elbow']!)) / dt;
      feats['d_angle_trunk'] = (feats['angle_trunk_inclination']! - (_prevAngles['angle_trunk_inclination'] ?? feats['angle_trunk_inclination']!)) / dt;
    }

    // Update temporal memory
    _prevNormLandmarks = normLandmarks;
    _prevTimestamp = timestampSeconds;
    _prevAngles['angle_left_knee'] = feats['angle_left_knee']!;
    _prevAngles['angle_right_knee'] = feats['angle_right_knee']!;
    _prevAngles['angle_left_hip'] = feats['angle_left_hip']!;
    _prevAngles['angle_right_hip'] = feats['angle_right_hip']!;
    _prevAngles['angle_left_elbow'] = feats['angle_left_elbow']!;
    _prevAngles['angle_right_elbow'] = feats['angle_right_elbow']!;
    _prevAngles['angle_trunk_inclination'] = feats['angle_trunk_inclination']!;

    // Return features in exact canonical order
    final result = List<double>.generate(140, (i) => feats[featureNames[i]] ?? 0.0);
    return result;
  }
}
