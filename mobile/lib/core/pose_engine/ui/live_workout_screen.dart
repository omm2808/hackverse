import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../theme/app_theme.dart';
import '../models/landmark.dart';
import '../models/pose_frame.dart';
import '../models/prediction_result.dart';
import '../pose_intelligence_engine.dart';

/// Live Workout Screen presenting real-time on-device Pose Intelligence inference.
/// Displays:
/// - Exercise name & phase (Standing, Descending, Bottom, Ascending)
/// - Rep count
/// - Form status (Good / Bad)
/// - Confidence percentage
/// - Real-time coaching feedback
/// - Historical rep log
class LiveWorkoutScreen extends StatefulWidget {
  final String initialExercise;

  const LiveWorkoutScreen({
    super.key,
    this.initialExercise = 'squat',
  });

  @override
  State<LiveWorkoutScreen> createState() => _LiveWorkoutScreenState();
}

class _LiveWorkoutScreenState extends State<LiveWorkoutScreen> {
  PoseIntelligenceEngine? _engine;
  bool _isLoading = true;
  String? _errorMessage;

  String _currentExercise = 'squat';
  int _repCount = 0;
  ExerciseState _currentState = ExerciseState.standing;
  String _formStatus = 'idle';
  double _formConfidence = 0.0;
  String _feedback = 'Position your camera to begin exercise.';
  final List<RepAnalysisResult> _repHistory = [];

  // Simulation timer for camera-free testing
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
    _currentExercise = widget.initialExercise;
    _initializeEngine();
  }

  Future<void> _initializeEngine() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final exJson = await rootBundle.loadString('assets/models/exercise_classifier.json');
      final sqJson = await rootBundle.loadString('assets/models/squat_form_classifier.json');
      final puJson = await rootBundle.loadString('assets/models/pushup_form_classifier.json');

      final engine = PoseIntelligenceEngine.fromModelJsonStrings(
        exerciseClassifierJson: exJson,
        squatFormJson: sqJson,
        pushupFormJson: puJson,
        defaultExercise: _currentExercise,
      );

      setState(() {
        _engine = engine;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load local ML models: $e';
      });
    }
  }

  void _onExerciseChanged(String newExercise) {
    if (_engine == null) return;
    setState(() {
      _currentExercise = newExercise;
      _engine!.setActiveExercise(newExercise);
      _repCount = 0;
      _currentState = ExerciseState.standing;
      _formStatus = 'idle';
      _formConfidence = 0.0;
      _feedback = 'Ready for $newExercise.';
      _repHistory.clear();
    });
  }

  void _onResetWorkout() {
    if (_engine == null) return;
    setState(() {
      _engine!.reset();
      _repCount = 0;
      _currentState = ExerciseState.standing;
      _formStatus = 'idle';
      _formConfidence = 0.0;
      _feedback = 'Workout reset. Ready to begin.';
      _repHistory.clear();
    });
  }

  /// Process an incoming pose frame through the complete pipeline
  void processPoseFrame(PoseFrame frame) {
    if (_engine == null) return;

    final repResult = _engine!.processFrame(frame);

    setState(() {
      _repCount = _engine!.repCount;
      _currentState = _engine!.currentState;

      if (repResult != null) {
        _repHistory.insert(0, repResult);
        _formStatus = repResult.formStatus;
        _formConfidence = repResult.formConfidence;
        _feedback = repResult.feedback;
      } else if (_engine!.latestFramePrediction != null) {
        // While rep in progress, show active guidance
        if (_currentState == ExerciseState.bottom) {
          _feedback = 'Bottom inflection reached — drive up!';
        } else if (_currentState == ExerciseState.descending) {
          _feedback = 'Keep descent controlled...';
        } else if (_currentState == ExerciseState.ascending) {
          _feedback = 'Drive through heels to lockout!';
        }
      }
    });
  }

  /// Simulate a full synthetic repetition for verification & demonstration
  Future<void> _simulateRepetition({required bool goodForm}) async {
    if (_engine == null || _isSimulating) return;

    setState(() {
      _isSimulating = true;
    });

    final kneeAngles = goodForm
        ? [170.0, 155.0, 135.0, 110.0, 85.0, 85.0, 110.0, 135.0, 155.0, 170.0]
        : [170.0, 155.0, 140.0, 125.0, 122.0, 122.0, 135.0, 150.0, 165.0, 170.0];

    for (int i = 0; i < kneeAngles.length; i++) {
      if (!mounted) break;

      final knee = kneeAngles[i];
      final lms = _createSyntheticPose(kneeAngle: knee);
      final frame = PoseFrame(
        landmarks: lms,
        timestampSeconds: DateTime.now().millisecondsSinceEpoch / 1000.0,
        isDetected: true,
      );

      processPoseFrame(frame);
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }

    if (mounted) {
      setState(() {
        _isSimulating = false;
      });
    }
  }

  List<Landmark> _createSyntheticPose({required double kneeAngle}) {
    final lms = List.generate(33, (i) => Landmark(index: i, x: 0.5, y: 0.5, z: 0.0, visibility: 0.99));
    lms[Landmark.leftHip] = const Landmark(index: 23, x: 0.45, y: 0.6, z: 0.0, visibility: 0.99);
    lms[Landmark.rightHip] = const Landmark(index: 24, x: 0.55, y: 0.6, z: 0.0, visibility: 0.99);
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

    return lms;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Live ${_currentExercise.toUpperCase().replaceAll('_', ' ')} Workout',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Workout',
            onPressed: _onResetWorkout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryGold),
                  SizedBox(height: 16),
                  Text('Loading on-device ML models...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.alertRed, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _initializeEngine,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Exercise Selector Pills
                        _buildExerciseSelector(),
                        const SizedBox(height: 16),

                        // Rep Count & State Card
                        _buildMainMetricsCard(),
                        const SizedBox(height: 16),

                        // Form Feedback & Coaching Card
                        _buildFeedbackCard(),
                        const SizedBox(height: 16),

                        // Testing Simulation Controls (Offline & Verification)
                        _buildTestingControls(),
                        const SizedBox(height: 20),

                        // Rep History
                        _buildRepHistorySection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildExerciseSelector() {
    final exercises = [
      {'id': 'squat', 'label': 'Squat'},
      {'id': 'push_up', 'label': 'Push-Up'},
      {'id': 'plank', 'label': 'Plank'},
    ];

    return Row(
      children: exercises.map((ex) {
        final isSelected = _currentExercise == ex['id'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Center(
                child: Text(
                  ex['label']!,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.primaryGold,
              backgroundColor: AppTheme.surfaceDark,
              onSelected: (selected) {
                if (selected) _onExerciseChanged(ex['id']!);
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMainMetricsCard() {
    final formColor = _formStatus == 'good'
        ? AppTheme.accentGreen
        : _formStatus == 'bad'
            ? AppTheme.alertRed
            : Colors.white38;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _formStatus == 'good'
              ? AppTheme.accentGreen.withValues(alpha: 0.5)
              : _formStatus == 'bad'
                  ? AppTheme.alertRed.withValues(alpha: 0.5)
                  : Colors.white10,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Rep counter
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REPETITIONS',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_repCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ],
              ),

              // Form badge & confidence
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: formColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: formColor, width: 1.5),
                    ),
                    child: Text(
                      _formStatus.toUpperCase(),
                      style: TextStyle(
                        color: formColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_formConfidence > 0)
                    Text(
                      '${(_formConfidence * 100).toStringAsFixed(1)}% Confidence',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 28),

          // Exercise state / phase
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Phase', style: TextStyle(color: Colors.white54)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentState.name.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.secondaryCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.fitness_center, color: AppTheme.primaryGold, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COACHING FEEDBACK',
                  style: TextStyle(
                    color: AppTheme.primaryGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _feedback,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestingControls() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ON-DEVICE INFERENCE DEMO & VERIFICATION',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Simulate Good Rep', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: _isSimulating ? null : () => _simulateRepetition(goodForm: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.warning_amber_outlined, size: 18),
                  label: const Text('Simulate Bad Rep', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.alertRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: _isSimulating ? null : () => _simulateRepetition(goodForm: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepHistorySection() {
    if (_repHistory.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            'Completed repetitions will appear here with form analysis.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COMPLETED REPETITIONS',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        ..._repHistory.map((rep) {
          final isGood = rep.formStatus == 'good';
          final badgeColor = isGood ? AppTheme.accentGreen : AppTheme.alertRed;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            color: AppTheme.surfaceDark,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: badgeColor.withValues(alpha: 0.2),
                child: Text(
                  '#${rep.repNumber}',
                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold),
                ),
              ),
              title: Row(
                children: [
                  Text(
                    rep.exercise.toUpperCase().replaceAll('_', ' '),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      rep.formStatus.toUpperCase(),
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                rep.feedback,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              trailing: Text(
                '${(rep.formConfidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
