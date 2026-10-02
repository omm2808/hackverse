import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../heritage_trek/models/heritage_challenge.dart';
import '../../heritage_trek/providers/heritage_trek_providers.dart';
import '../../theme/app_theme.dart';
import '../bridge/ml_kit_adapter.dart';
import '../models/prediction_result.dart';
import '../pose_intelligence_engine.dart';

/// Live Squat Test Screen — Stage 2 of physical-device ML validation.
///
/// Connects the live camera pipeline to the full Pose Engine:
///   Camera → ML Kit → MlKitPoseAdapter → 140 features → Decision Forest
///   → SquatStateMachine → RepAnalysisResult
///
/// When launched with a [HeritageChallenge], it tracks target reps,
/// updates the HUD, awards XP upon completion, and returns the user
/// to the Odyssey Map.
class LiveSquatTestScreen extends ConsumerStatefulWidget {
  final HeritageChallenge? challenge;

  const LiveSquatTestScreen({
    super.key,
    this.challenge,
  });

  @override
  ConsumerState<LiveSquatTestScreen> createState() => _LiveSquatTestScreenState();
}

class _LiveSquatTestScreenState extends ConsumerState<LiveSquatTestScreen>
    with WidgetsBindingObserver {
  // ── Camera ──────────────────────────────────────────────────────────────
  List<CameraDescription>? _cameras;
  CameraController? _cameraController;

  // ── ML Kit ───────────────────────────────────────────────────────────────
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    ),
  );

  // ── Pose Engine ──────────────────────────────────────────────────────────
  PoseIntelligenceEngine? _engine;

  // ── UI state ─────────────────────────────────────────────────────────────
  bool _isInitializing = true;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _challengeCompleted = false;

  // Live metrics updated every processed frame
  bool _poseDetected = false;
  int _landmarkCount = 0;
  String _selectedExercise = 'squat'; // 'squat' or 'push_up'
  String _detectedExercise = 'squat';
  ExerciseState _squatState = ExerciseState.standing;
  int _repCount = 0;
  String _formStatus = 'idle';
  double _formConfidence = 0.0;
  String _feedback = 'Stand in front of the camera and perform a squat.';
  List<String> _activeFlags = [];
  final List<RepAnalysisResult> _repHistory = [];

  int _fps = 0;
  int _frameCount = 0;
  DateTime _fpsTimer = DateTime.now();
  int _selectedCameraIndex = 0; // 0 = back, 1 = front

  // Biomechanics for debug panel
  double _kneeAngleLeft = 180.0;
  double _kneeAngleRight = 180.0;
  double _elbowAngleLeft = 180.0;
  double _elbowAngleRight = 180.0;
  double _trunkInclination = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.challenge != null) {
      _selectedExercise = widget.challenge!.exerciseType;
    }
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      _startImageStream();
    }
  }

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> _initialize() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      // 1. Load the three Decision Forest JSON bundles
      final exJson =
          await rootBundle.loadString('assets/models/exercise_classifier.json');
      final sqJson =
          await rootBundle.loadString('assets/models/squat_form_classifier.json');
      final puJson =
          await rootBundle.loadString('assets/models/pushup_form_classifier.json');

      _engine = PoseIntelligenceEngine.fromModelJsonStrings(
        exerciseClassifierJson: exJson,
        squatFormJson: sqJson,
        pushupFormJson: puJson,
        defaultExercise: _selectedExercise,
      );

      // 2. Initialize camera
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'No camera found on this device.';
        });
        return;
      }

      await _startCamera();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Initialization failed: $e';
        });
      }
    }
  }

  Future<void> _startCamera() async {
    await _cameraController?.dispose();

    final camera = _cameras![_selectedCameraIndex];
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    _cameraController = controller;

    await controller.initialize();
    if (!mounted) return;

    await _startImageStream();
    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _toggleCamera() async {
    final cameras = _cameras;
    if (cameras == null || cameras.length < 2) return;
    if (_cameraController?.value.isStreamingImages ?? false) {
      await _cameraController!.stopImageStream();
    }
    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras.length;
      _isInitializing = true;
    });
    await _startCamera();
  }

  Future<void> _startImageStream() async {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (ctrl.value.isStreamingImages) return;
    await ctrl.startImageStream(_onCameraImage);
  }

  // ── Camera → ML Kit → Pose Engine pipeline ───────────────────────────────

  void _onCameraImage(CameraImage image) {
    if (_isProcessing) return;
    _isProcessing = true;
    _processCameraImage(image).whenComplete(() => _isProcessing = false);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final ctrl = _cameraController;
    final engine = _engine;
    if (ctrl == null || engine == null) return;

    try {
      // Step 1: Build ML Kit InputImage
      final camera = _cameras![_selectedCameraIndex];
      final rotation =
          _getInputImageRotation(camera.sensorOrientation, camera.lensDirection);

      final inputImage = InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      // Step 2: ML Kit BlazePose
      final poses = await _poseDetector.processImage(inputImage);

      // Step 3: MlKitPoseAdapter → PoseFrame
      final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final pose = poses.isNotEmpty ? poses.first : null;
      final isRotated90or270 =
          rotation == InputImageRotation.rotation90deg ||
          rotation == InputImageRotation.rotation270deg;
      final orientedWidth =
          isRotated90or270 ? image.height.toDouble() : image.width.toDouble();
      final orientedHeight =
          isRotated90or270 ? image.width.toDouble() : image.height.toDouble();

      final frame = MlKitPoseAdapter.adaptPose(
        pose,
        timestampSeconds: now,
        imageWidth: orientedWidth,
        imageHeight: orientedHeight,
      );

      // Step 4: PoseIntelligenceEngine (140 features → forest → state machine)
      RepAnalysisResult? repResult;
      if (frame.isDetected) {
        repResult = engine.processFrame(frame);
      }

      // Step 5: Extract raw biomechanics for debug panel
      final features = engine.latestFeatures;
      final kneL = features.length > 100 ? features[99] : 180.0;
      final kneR = features.length > 101 ? features[100] : 180.0;
      final elbL = features.length > 104 ? features[103] : 180.0;
      final elbR = features.length > 105 ? features[104] : 180.0;
      final trunk = features.length > 110 ? features[109] : 0.0;

      // Step 6: Extract detected exercise from classifier
      final prediction = engine.latestFramePrediction;

      // FPS
      _frameCount++;
      final elapsed = DateTime.now().difference(_fpsTimer).inMilliseconds;
      if (elapsed >= 1000) {
        _fps = ((_frameCount * 1000) / elapsed).round();
        _frameCount = 0;
        _fpsTimer = DateTime.now();
      }

      if (!mounted) return;
      setState(() {
        _poseDetected = frame.isDetected;
        _landmarkCount =
            frame.landmarks.where((lm) => lm.visibility > 0.4).length;
        _squatState = engine.currentState;
        _repCount = engine.repCount;
        _kneeAngleLeft = kneL;
        _kneeAngleRight = kneR;
        _elbowAngleLeft = elbL;
        _elbowAngleRight = elbR;
        _trunkInclination = trunk;

        if (repResult != null) {
          _repHistory.insert(0, repResult);
          _formStatus = repResult.formStatus;
          _formConfidence = repResult.formConfidence;
          _activeFlags = repResult.activeFlags;
          _feedback = repResult.feedback;

          if (widget.challenge != null &&
              !_challengeCompleted &&
              _repCount >= widget.challenge!.targetReps) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _onChallengeCompleted();
            });
          }
        } else if (prediction != null) {
          _detectedExercise = _selectedExercise;

          if (_selectedExercise == 'squat') {
            if (_squatState == ExerciseState.descending) {
              _formStatus = 'good';
              _feedback = 'Descending — control tempo.';
            } else if (_squatState == ExerciseState.bottom) {
              final isDeep = math.min(kneL, kneR) <= 105.0;
              _formStatus = isDeep ? 'good' : 'warning';
              _feedback = isDeep
                  ? 'Great depth! Now drive up.'
                  : 'Reach parallel depth.';
            } else if (_squatState == ExerciseState.ascending) {
              _formStatus = 'good';
              _feedback = 'Drive up through heels to standing!';
            } else if (_repHistory.isEmpty) {
              _formStatus = 'idle';
              _formConfidence = 0.0;
              _activeFlags = [];
              _feedback = 'Position your camera and begin squatting.';
            }
          } else {
            // Push-up live coaching
            if (_squatState == ExerciseState.descending) {
              _formStatus = 'good';
              _feedback = 'Descending — control chest descent.';
            } else if (_squatState == ExerciseState.bottom) {
              final isDeep = math.min(elbL, elbR) <= 100.0;
              _formStatus = isDeep ? 'good' : 'warning';
              _feedback = isDeep
                  ? 'Solid depth! Push floor away.'
                  : 'Aim for 90° elbow flexion.';
            } else if (_squatState == ExerciseState.ascending) {
              _formStatus = 'good';
              _feedback = 'Push up to high plank lockout!';
            } else if (_repHistory.isEmpty) {
              _formStatus = 'idle';
              _formConfidence = 0.0;
              _activeFlags = [];
              _feedback = 'Position camera in high plank to begin.';
            }
          }
        }
      });
    } catch (_) {
      // Drop frame on error; next frame will retry
    }
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    if (planes.length == 1) return planes.first.bytes;
    final totalLength =
        planes.fold<int>(0, (prev, plane) => prev + plane.bytes.length);
    final bytes = Uint8List(totalLength);
    int offset = 0;
    for (final plane in planes) {
      bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return bytes;
  }

  InputImageRotation _getInputImageRotation(
      int sensorOrientation, CameraLensDirection lensDirection) {
    final ctrl = _cameraController;
    if (ctrl == null) {
      return InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;
    }

    final orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };

    var rotationCompensation =
        orientations[ctrl.value.deviceOrientation] ?? 0;
    if (lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation =
          (sensorOrientation - rotationCompensation + 360) % 360;
    }

    return InputImageRotationValue.fromRawValue(rotationCompensation) ??
        InputImageRotation.rotation0deg;
  }

  void _switchExercise(String exercise) {
    if (_selectedExercise == exercise) return;
    setState(() {
      _selectedExercise = exercise;
      _repCount = 0;
      _repHistory.clear();
      _squatState = exercise == 'push_up'
          ? ExerciseState.plankHigh
          : ExerciseState.standing;
      _formStatus = 'idle';
      _formConfidence = 0.0;
      _activeFlags = [];
      _feedback = exercise == 'push_up'
          ? 'Position camera in high plank to begin push-ups.'
          : 'Position your camera and begin squatting.';
    });
    _engine?.setActiveExercise(exercise);
  }

  void _resetEngine() {
    _engine?.reset();
    setState(() {
      _repCount = 0;
      _repHistory.clear();
      _squatState = _selectedExercise == 'push_up'
          ? ExerciseState.plankHigh
          : ExerciseState.standing;
      _formStatus = 'idle';
      _formConfidence = 0.0;
      _activeFlags = [];
      _feedback = _selectedExercise == 'push_up'
          ? 'Reset. Position camera in high plank to begin.'
          : 'Reset. Perform a squat to begin.';
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedExercise,
              dropdownColor: AppTheme.surfaceDark,
              icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryGold),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'squat',
                  child: Text('Squats 🏋️'),
                ),
                DropdownMenuItem(
                  value: 'push_up',
                  child: Text('Push-ups 💪'),
                ),
              ],
              onChanged: (val) {
                if (val != null) _switchExercise(val);
              },
            ),
          ),
        ),
        actions: [
          if (widget.challenge != null)
            IconButton(
              icon: const Icon(Icons.fast_forward, color: AppTheme.accentGreen),
              tooltip: 'Complete Reps (Demo)',
              onPressed: () {
                setState(() {
                  _repCount = widget.challenge!.targetReps;
                });
                _onChallengeCompleted();
              },
            ),
          if (_cameras != null && _cameras!.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_android,
                  color: Colors.white70),
              tooltip: 'Flip Camera',
              onPressed: _toggleCamera,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            tooltip: 'Reset',
            onPressed: _resetEngine,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryGold),
            SizedBox(height: 16),
            Text('Loading models & camera…',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _initialize, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const Center(
          child: Text('Camera not ready',
              style: TextStyle(color: Colors.white70)));
    }

    return Column(
      children: [
        // ── Camera preview (top half) ──────────────────────────────────────
        Expanded(
          flex: 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(ctrl),
              // Pose status HUD
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildCameraHUD(),
              ),
              // State badge centre
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: _buildStateBadge(),
              ),
            ],
          ),
        ),
        // ── Metrics panel (bottom half) ───────────────────────────────────
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                if (widget.challenge != null)
                  _buildChallengeBanner(widget.challenge!),
                _buildMainMetrics(),
                const SizedBox(height: 8),
                _buildBiomechanicsRow(),
                const SizedBox(height: 8),
                _buildFeedbackCard(),
                const SizedBox(height: 8),
                _buildRepHistory(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildChallengeBanner(HeritageChallenge challenge) {
    final progress = (_repCount / challenge.targetReps).clamp(0.0, 1.0);
    final exerciseName =
        challenge.exerciseType == 'push_up' ? 'Push-ups' : 'Squats';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGold.withValues(alpha: 0.2),
            AppTheme.surfaceElevated,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.temple_hindu,
                        color: AppTheme.primaryGold, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Heritage Challenge • ${challenge.siteNameEn}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+${challenge.rewardXp} XP',
                  style: const TextStyle(
                    color: AppTheme.primaryGold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_repCount / ${challenge.targetReps} $exerciseName',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.primaryGold),
            ),
          ),
        ],
      ),
    );
  }

  void _onChallengeCompleted() {
    if (_challengeCompleted) return;
    _challengeCompleted = true;

    final challenge = widget.challenge;
    if (challenge == null) return;

    _cameraController?.stopImageStream();

    ref.read(journeyProgressProvider.notifier).completeSite(
          challenge.siteId,
          challenge.rewardXp,
        );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.primaryGold, width: 2),
        ),
        title: Column(
          children: [
            const Icon(Icons.stars, color: AppTheme.primaryGold, size: 64),
            const SizedBox(height: 12),
            const Text(
              'CHALLENGE COMPLETE!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.primaryGold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              challenge.siteNameEn,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryGold.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, color: AppTheme.primaryGold, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '+${challenge.rewardXp} XP EARNED',
                    style: const TextStyle(
                      color: AppTheme.primaryGold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Completed ${challenge.targetReps} reps with verified form. The next heritage destination has unlocked on your map!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                context.go('/journey');
              },
              child: const Text(
                'Return to Odyssey Map',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraHUD() {
    final statusColor =
        _poseDetected ? AppTheme.accentGreen : Colors.redAccent;
    final statusLabel =
        _poseDetected ? '✅  POSE DETECTED' : '🔍  NO POSE';
    final challenge = widget.challenge;

    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (challenge != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fitness_center,
                        color: AppTheme.primaryGold, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Challenge: ${challenge.siteNameEn}',
                      style: const TextStyle(
                        color: AppTheme.primaryGold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$_repCount / ${challenge.targetReps}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(statusLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              Text('$_landmarkCount/33 landmarks  $_fps FPS',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStateBadge() {
    final displayName = _squatState == ExerciseState.plankHigh
        ? 'HIGH PLANK'
        : _squatState.name.toUpperCase();
    const stateColors = {
      'STANDING': Colors.white,
      'HIGH PLANK': Colors.white,
      'DESCENDING': Color(0xFFFFB300),
      'BOTTOM': Color(0xFF4CAF50),
      'ASCENDING': Color(0xFF29B6F6),
    };
    final color = stateColors[displayName] ?? Colors.white54;

    return Center(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          displayName,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.5),
        ),
      ),
    );
  }

  Widget _buildMainMetrics() {
    final formColor = _formStatus == 'good'
        ? AppTheme.accentGreen
        : _formStatus == 'bad'
            ? AppTheme.alertRed
            : Colors.white38;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // Rep counter
          Expanded(
            child: Column(
              children: [
                const Text('REPS',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0)),
                Text(
                  widget.challenge != null
                      ? '$_repCount/${widget.challenge!.targetReps}'
                      : '$_repCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.challenge != null ? 36 : 52,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 60, color: Colors.white12),
          // Exercise + form
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Exercise: ',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      Text(
                        _detectedExercise.toUpperCase().replaceAll('_', ' '),
                        style: const TextStyle(
                            color: AppTheme.secondaryCyan,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('Form: ',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: formColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: formColor, width: 1),
                        ),
                        child: Text(
                          _formStatus.toUpperCase(),
                          style: TextStyle(
                              color: formColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_formConfidence > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${(_formConfidence * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                  if (_activeFlags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: _activeFlags
                          .map((f) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.alertRed
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(f,
                                    style: const TextStyle(
                                        color: AppTheme.alertRed,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiomechanicsRow() {
    if (_selectedExercise == 'push_up') {
      return Row(
        children: [
          _biometricsChip(
              'L.Elbow', '${_elbowAngleLeft.toStringAsFixed(0)}°'),
          const SizedBox(width: 6),
          _biometricsChip(
              'R.Elbow', '${_elbowAngleRight.toStringAsFixed(0)}°'),
          const SizedBox(width: 6),
          _biometricsChip(
              'Trunk', '${_trunkInclination.toStringAsFixed(0)}°'),
        ],
      );
    }
    return Row(
      children: [
        _biometricsChip(
            'L.Knee', '${_kneeAngleLeft.toStringAsFixed(0)}°'),
        const SizedBox(width: 6),
        _biometricsChip(
            'R.Knee', '${_kneeAngleRight.toStringAsFixed(0)}°'),
        const SizedBox(width: 6),
        _biometricsChip(
            'Trunk', '${_trunkInclination.toStringAsFixed(0)}°'),
      ],
    );
  }

  Widget _biometricsChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.record_voice_over,
              color: AppTheme.primaryGold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _feedback,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepHistory() {
    if (_repHistory.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Completed reps will appear here.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('COMPLETED REPS',
            style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0)),
        const SizedBox(height: 6),
        ..._repHistory.take(5).map((rep) {
          final isGood = rep.formStatus == 'good';
          final badgeColor =
              isGood ? AppTheme.accentGreen : AppTheme.alertRed;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: badgeColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: badgeColor.withValues(alpha: 0.2),
                  child: Text(
                    '#${rep.repNumber}',
                    style: TextStyle(
                        color: badgeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            rep.formStatus.toUpperCase(),
                            style: TextStyle(
                                color: badgeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(rep.formConfidence * 100).toStringAsFixed(0)}%  ·  ${rep.durationMs}ms',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                      Text(
                        rep.feedback,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                      if (rep.activeFlags.isNotEmpty)
                        Text(
                          rep.activeFlags.join(' | '),
                          style: const TextStyle(
                              color: AppTheme.alertRed, fontSize: 10),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${rep.peakMetrics['minKneeAngle']?.toStringAsFixed(0)}° knee',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
