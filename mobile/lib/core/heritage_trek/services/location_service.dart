import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Foreground-only GPS location service for Heritage Trek.
///
/// Wraps the [geolocator] package to provide a filtered stream of GPS
/// positions. This service runs ONLY while an active trek screen is open;
/// it does NOT request or use background location.
///
/// GPS readings are filtered by [minAccuracyMeters] — readings with
/// accuracy worse than this threshold are silently discarded to prevent
/// GPS drift from corrupting distance calculations.
class LocationService {
  /// Maximum acceptable horizontal accuracy in meters.
  /// Readings above this are discarded.
  static const double minAccuracyMeters = 25.0;

  /// Minimum displacement in meters before the platform delivers an update.
  static const int distanceFilterMeters = 5;

  StreamSubscription<Position>? _subscription;
  final StreamController<Position> _controller =
      StreamController<Position>.broadcast();

  /// Stream of GPS positions that pass the accuracy filter.
  Stream<Position> get positionStream => _controller.stream;

  /// Request location permissions at runtime.
  ///
  /// Returns `true` if permission is granted (either already or freshly).
  /// Returns `false` if the user denied, or if location services are off.
  Future<bool> requestPermission() async {
    // Check if location services are enabled at the OS level.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    // Request the location permission.
    final status = await Permission.locationWhenInUse.request();

    // Also request activity recognition for step counting (Android 10+)
    try {
      if (await Permission.activityRecognition.isDenied) {
        await Permission.activityRecognition.request();
      }
    } catch (_) {
      // Hardware / platform without activity recognition support
    }

    return status.isGranted;
  }

  /// Start listening to GPS updates.
  ///
  /// Call this when the trek screen opens. The stream emits [Position]
  /// objects that have horizontal accuracy ≤ [minAccuracyMeters].
  ///
  /// Does nothing if already listening.
  Future<void> startListening() async {
    if (_subscription != null) return;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
    );

    _subscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) {
        // Accuracy filtering: discard noisy readings.
        if (position.accuracy <= minAccuracyMeters) {
          _controller.add(position);
        }
      },
      onError: (Object error) {
        _controller.addError(error);
      },
    );
  }

  /// Stop listening to GPS updates.
  ///
  /// Call this when the trek screen closes or the trek is completed.
  Future<void> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Clean up resources. Call when the service is disposed.
  Future<void> dispose() async {
    await stopListening();
    await _controller.close();
  }
}
