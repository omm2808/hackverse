/// Fit Odyssey — 33 Body Landmarks representation mirroring MediaPipe / BlazePose.
class Landmark {
  final int index;
  final double x;
  final double y;
  final double z;
  final double visibility;
  final double presence;

  const Landmark({
    required this.index,
    required this.x,
    required this.y,
    required this.z,
    this.visibility = 1.0,
    this.presence = 1.0,
  });

  Landmark copyWith({
    int? index,
    double? x,
    double? y,
    double? z,
    double? visibility,
    double? presence,
  }) {
    return Landmark(
      index: index ?? this.index,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      visibility: visibility ?? this.visibility,
      presence: presence ?? this.presence,
    );
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'x': x,
        'y': y,
        'z': z,
        'visibility': visibility,
        'presence': presence,
      };

  factory Landmark.fromJson(Map<String, dynamic> json, int idx) => Landmark(
        index: json['index'] as int? ?? idx,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        z: (json['z'] as num).toDouble(),
        visibility: (json['visibility'] as num?)?.toDouble() ?? 1.0,
        presence: (json['presence'] as num?)?.toDouble() ?? 1.0,
      );

  // Landmark Indices Constants (MediaPipe 33 Keypoints)
  static const int nose = 0;
  static const int leftEyeInner = 1;
  static const int leftEye = 2;
  static const int leftEyeOuter = 3;
  static const int rightEyeInner = 4;
  static const int rightEye = 5;
  static const int rightEyeOuter = 6;
  static const int leftEar = 7;
  static const int rightEar = 8;
  static const int mouthLeft = 9;
  static const int mouthRight = 10;
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
  static const int leftElbow = 13;
  static const int rightElbow = 14;
  static const int leftWrist = 15;
  static const int rightWrist = 16;
  static const int leftPinky = 17;
  static const int rightPinky = 18;
  static const int leftIndex = 19;
  static const int rightIndex = 20;
  static const int leftThumb = 21;
  static const int rightThumb = 22;
  static const int leftHip = 23;
  static const int rightHip = 24;
  static const int leftKnee = 25;
  static const int rightKnee = 26;
  static const int leftAnkle = 27;
  static const int rightAnkle = 28;
  static const int leftHeel = 29;
  static const int rightHeel = 30;
  static const int leftFootIndex = 31;
  static const int rightFootIndex = 32;
}
