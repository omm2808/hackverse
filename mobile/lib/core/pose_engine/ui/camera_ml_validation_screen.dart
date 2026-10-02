import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../bridge/ml_kit_adapter.dart';
import '../models/landmark.dart';
import '../models/pose_frame.dart';
import '../../theme/app_theme.dart';

/// Minimal on-device validation screen.
/// Purpose: prove that Camera → ML Kit BlazePose → MlKitPoseAdapter → PoseFrame works
/// on a real physical device. No Pose Engine inference is run here.
class CameraMLValidationScreen extends StatefulWidget {
  const CameraMLValidationScreen({super.key});

  @override
  State<CameraMLValidationScreen> createState() =>
      _CameraMLValidationScreenState();
}

class _CameraMLValidationScreenState
    extends State<CameraMLValidationScreen> with WidgetsBindingObserver {
  // Camera
  List<CameraDescription>? _cameras;
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;

  // ML Kit
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    ),
  );

  // State
  bool _isInitializing = true;
  bool _isProcessing = false;
  String? _errorMessage;
  PoseFrame? _latestFrame;
  int _fps = 0;
  int _frameCount = 0;
  DateTime _fpsTimer = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
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

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'No cameras found on this device.';
        });
        return;
      }

      await _startCamera(_selectedCameraIndex);
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Camera init failed: $e';
      });
    }
  }

  Future<void> _startCamera(int index) async {
    await _cameraController?.dispose();

    final camera = _cameras![index];
    final controller = CameraController(
      camera,
      ResolutionPreset.medium, // 720p — good balance of speed vs. quality
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21, // Required for ML Kit on Android
    );

    _cameraController = controller;

    try {
      await controller.initialize();
      if (!mounted) return;
      await _startImageStream();
      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Camera start failed: $e';
      });
    }
  }

  Future<void> _startImageStream() async {
    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (ctrl.value.isStreamingImages) return;

    await ctrl.startImageStream(_onCameraImage);
  }

  void _onCameraImage(CameraImage image) {
    if (_isProcessing) return; // Drop frames while processing
    _isProcessing = true;

    // Run ML Kit on background isolate via async
    _processCameraImage(image).then((_) {
      _isProcessing = false;
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final ctrl = _cameraController;
    if (ctrl == null) return;

    try {
      final camera = _cameras![_selectedCameraIndex];
      final sensorOrientation = camera.sensorOrientation;
      final rotation = _getInputImageRotation(sensorOrientation, camera.lensDirection);

      final inputImage = InputImage.fromBytes(
        bytes: _concatenatePlanes(image.planes),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final poses = await _poseDetector.processImage(inputImage);

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

      // FPS calculation
      _frameCount++;
      final elapsed = DateTime.now().difference(_fpsTimer).inMilliseconds;
      if (elapsed >= 1000) {
        _fps = ((_frameCount * 1000) / elapsed).round();
        _frameCount = 0;
        _fpsTimer = DateTime.now();
      }

      if (mounted) {
        setState(() {
          _latestFrame = frame;
        });
      }
    } catch (e) {
      // Silently drop processing errors — next frame will retry
    }
  }

  /// Efficient plane combination for ML Kit without creating massive GC churn.
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

  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    setState(() {
      _isInitializing = true;
      _latestFrame = null;
    });
    await _startCamera(_selectedCameraIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Camera ML Validation',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (_cameras != null && _cameras!.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_android, color: Colors.white),
              tooltip: 'Flip Camera',
              onPressed: _toggleCamera,
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
            Text(
              'Initializing camera & ML Kit...',
              style: TextStyle(color: Colors.white70),
            ),
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
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final ctrl = _cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const Center(
        child: Text('Camera not ready', style: TextStyle(color: Colors.white70)),
      );
    }

    final frame = _latestFrame;
    final isDetected = frame?.isDetected ?? false;
    final landmarkCount = frame == null
        ? 0
        : frame.landmarks.where((lm) => lm.visibility > 0.4).length;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        CameraPreview(ctrl),

        // Skeleton overlay
        if (frame != null && isDetected)
          CustomPaint(
            painter: _SkeletonPainter(
              frame: frame,
              previewSize: ctrl.value.previewSize!,
            ),
          ),

        // Status HUD
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildHUD(isDetected, landmarkCount),
        ),

        // Landmark table
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildLandmarkPanel(frame),
        ),
      ],
    );
  }

  Widget _buildHUD(bool isDetected, int landmarkCount) {
    final statusColor = isDetected ? AppTheme.accentGreen : Colors.redAccent;
    final statusLabel = isDetected ? '✅  POSE DETECTED' : '🔍  NO POSE';

    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            statusLabel,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$landmarkCount / 33 landmarks',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              Text(
                '$_fps FPS',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLandmarkPanel(PoseFrame? frame) {
    if (frame == null || !frame.isDetected) {
      return Container(
        color: Colors.black54,
        padding: const EdgeInsets.all(12),
        child: const Text(
          'Waiting for pose...',
          style: TextStyle(color: Colors.white54, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Show top 8 most-visible landmarks by name
    final named = {
      0: 'Nose',
      11: 'L.Shoulder',
      12: 'R.Shoulder',
      23: 'L.Hip',
      24: 'R.Hip',
      25: 'L.Knee',
      26: 'R.Knee',
      27: 'L.Ankle',
      28: 'R.Ankle',
    };

    final rows = named.entries.map((e) {
      final lm = frame.landmarks[e.key];
      final vis = lm.visibility;
      final color = vis > 0.7
          ? AppTheme.accentGreen
          : vis > 0.4
              ? AppTheme.primaryGold
              : Colors.redAccent;
      return DataRow(cells: [
        DataCell(Text(e.value,
            style: const TextStyle(color: Colors.white70, fontSize: 11))),
        DataCell(Text(
          '(${lm.x.toStringAsFixed(2)}, ${lm.y.toStringAsFixed(2)})',
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        )),
        DataCell(Text(
          '${(vis * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
        )),
      ]);
    }).toList();

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 24,
          dataRowMinHeight: 20,
          dataRowMaxHeight: 24,
          columnSpacing: 12,
          columns: const [
            DataColumn(label: Text('Landmark', style: TextStyle(color: Colors.white54, fontSize: 10))),
            DataColumn(label: Text('X, Y', style: TextStyle(color: Colors.white54, fontSize: 10))),
            DataColumn(label: Text('Visibility', style: TextStyle(color: Colors.white54, fontSize: 10))),
          ],
          rows: rows,
        ),
      ),
    );
  }
}

/// Paints the 33 BlazePose skeleton on top of the camera preview.
class _SkeletonPainter extends CustomPainter {
  final PoseFrame frame;
  final Size previewSize;

  _SkeletonPainter({required this.frame, required this.previewSize});

  // BlazePose skeleton connections (index pairs)
  static const List<List<int>> _connections = [
    [11, 12], // shoulders
    [11, 13], [13, 15], // left arm
    [12, 14], [14, 16], // right arm
    [11, 23], [12, 24], // torso sides
    [23, 24], // hip bar
    [23, 25], [25, 27], // left leg
    [24, 26], [26, 28], // right leg
    [27, 31], [28, 32], // feet
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppTheme.accentGreen.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = AppTheme.primaryGold
      ..style = PaintingStyle.fill;

    final lowVisPaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // Map normalized [0,1] coords to canvas coords
    Offset toCanvas(Landmark lm) {
      return Offset(lm.x * size.width, lm.y * size.height);
    }

    // Draw connections
    for (final conn in _connections) {
      final a = frame.landmarks[conn[0]];
      final b = frame.landmarks[conn[1]];
      if (a.visibility > 0.4 && b.visibility > 0.4) {
        canvas.drawLine(toCanvas(a), toCanvas(b), linePaint);
      }
    }

    // Draw landmark dots
    for (final lm in frame.landmarks) {
      if (lm.visibility > 0.4) {
        final radius = lm.visibility > 0.7 ? 5.0 : 3.5;
        canvas.drawCircle(
          toCanvas(lm),
          radius,
          lm.visibility > 0.7 ? dotPaint : lowVisPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SkeletonPainter oldDelegate) => true;
}


