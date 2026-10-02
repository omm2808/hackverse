import 'dart:async';

import 'package:pedometer_2/pedometer_2.dart';

/// Pedometer step tracking service for Heritage Trek.
///
/// Wraps the [pedometer_2] package to provide a stream of step counts
/// relative to the session start. Steps are tracked SEPARATELY from
/// GPS distance and are NEVER converted to or added to GPS distance.
///
/// Steps are displayed for user interest only.
class StepTrackerService {
  StreamSubscription<int>? _subscription;
  final StreamController<int> _controller =
      StreamController<int>.broadcast();

  /// The absolute step count when the session started.
  /// Used to compute relative steps (current − baseline).
  int? _baselineSteps;

  /// The [Pedometer] instance.
  final Pedometer _pedometer = Pedometer();

  /// Stream of step counts relative to session start.
  /// First emission is always 0 (or close to 0).
  Stream<int> get stepStream => _controller.stream;

  /// Start listening to the device pedometer.
  ///
  /// Call this when a trek session begins. The stream emits integer
  /// step deltas from the session start.
  ///
  /// Does nothing if already listening.
  void startListening() {
    if (_subscription != null) return;

    _baselineSteps = null;

    _subscription = _pedometer.stepCountStream().listen(
      (steps) {
        _baselineSteps ??= steps;
        final relativeSteps = steps - _baselineSteps!;
        _controller.add(relativeSteps);
      },
      onError: (Object error) {
        // Pedometer may not be available on all devices or activity recognition
        // permission may be withheld. Steps are supplementary, so we avoid
        // propagating fatal stream errors.
      },
    );
  }

  /// Stop listening to the pedometer.
  ///
  /// Call this when the trek session ends or the screen closes.
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _baselineSteps = null;
  }

  /// Clean up resources.
  Future<void> dispose() async {
    stopListening();
    await _controller.close();
  }
}
