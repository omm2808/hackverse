/// Single-frame inference result from custom ML models.
class PredictionResult {
  final String predictedClass;
  final double confidence;
  final String exercise;
  final String formStatus;
  final double formConfidence;
  final Map<String, double> biomechanics;
  final String feedback;

  const PredictionResult({
    required this.predictedClass,
    required this.confidence,
    required this.exercise,
    required this.formStatus,
    required this.formConfidence,
    required this.biomechanics,
    required this.feedback,
  });

  Map<String, dynamic> toJson() => {
        'predictedClass': predictedClass,
        'confidence': confidence,
        'exercise': exercise,
        'formStatus': formStatus,
        'formConfidence': formConfidence,
        'biomechanics': biomechanics,
        'feedback': feedback,
      };

  factory PredictionResult.fromJson(Map<String, dynamic> json) =>
      PredictionResult(
        predictedClass: json['predictedClass'] as String? ?? 'unknown',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        exercise: json['exercise'] as String? ?? 'unknown',
        formStatus: json['formStatus'] as String? ?? 'good',
        formConfidence: (json['formConfidence'] as num?)?.toDouble() ?? 0.0,
        biomechanics: (json['biomechanics'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            ) ??
            {},
        feedback: json['feedback'] as String? ?? '',
      );
}

/// Movement states for exercise state machine.
enum ExerciseState {
  standing,
  descending,
  bottom,
  ascending,
  plankHigh,
  plankHold,
}

/// Analysis result generated upon repetition completion.
class RepAnalysisResult {
  final int repNumber;
  final String exercise;
  final String formStatus; // 'good' or 'bad'
  final double formConfidence;
  final List<String> activeFlags;
  final String feedback;
  final int durationMs;
  final Map<String, double> peakMetrics;

  const RepAnalysisResult({
    required this.repNumber,
    required this.exercise,
    required this.formStatus,
    required this.formConfidence,
    required this.activeFlags,
    required this.feedback,
    required this.durationMs,
    required this.peakMetrics,
  });

  Map<String, dynamic> toJson() => {
        'repNumber': repNumber,
        'exercise': exercise,
        'formStatus': formStatus,
        'formConfidence': formConfidence,
        'activeFlags': activeFlags,
        'feedback': feedback,
        'durationMs': durationMs,
        'peakMetrics': peakMetrics,
      };

  @override
  String toString() =>
      'Rep $repNumber ($exercise): $formStatus (${(formConfidence * 100).toStringAsFixed(1)}%) — $feedback';
}
