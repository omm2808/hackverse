import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Accumulates GPS-derived walking distance using Haversine calculations.
///
/// This is the PRIMARY distance metric for Heritage Trek. Each valid GPS
/// position is compared to the previous position, and the Haversine
/// distance between them is added to the cumulative total.
///
/// GPS readings with accuracy worse than [maxAccuracyMeters] are discarded
/// to prevent drift. This filtering is in addition to the filtering
/// already done by [LocationService].
class TrekDistanceCalculator {
  /// Maximum acceptable accuracy (meters) for a reading to be included.
  static const double maxAccuracyMeters = 25.0;

  /// Minimum distance (meters) between two readings to count.
  /// Prevents GPS micro-jitter from inflating distance.
  static const double minSegmentMeters = 2.0;

  /// Maximum distance (meters) between two readings to count.
  /// Prevents GPS teleportation artifacts from inflating distance.
  static const double maxSegmentMeters = 100.0;

  final Distance _haversine = const Distance();

  LatLng? _lastPosition;
  double _cumulativeMeters = 0.0;

  /// Current cumulative distance in meters.
  double get totalDistanceMeters => _cumulativeMeters;

  /// The GPS breadcrumb trail of accepted positions.
  final List<LatLng> _breadcrumbs = [];

  /// All accepted GPS positions as a breadcrumb trail.
  List<LatLng> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  /// Process a new GPS position reading.
  ///
  /// Returns the updated cumulative distance in meters.
  /// The position may be discarded if:
  /// - Its accuracy is worse than [maxAccuracyMeters]
  /// - The segment distance is below [minSegmentMeters] (jitter)
  /// - The segment distance exceeds [maxSegmentMeters] (teleport)
  double addPosition(Position position) {
    // Accuracy gate (redundant safety — LocationService also filters).
    if (position.accuracy > maxAccuracyMeters) {
      return _cumulativeMeters;
    }

    final current = LatLng(position.latitude, position.longitude);

    if (_lastPosition == null) {
      // First valid reading — establish baseline.
      _lastPosition = current;
      _breadcrumbs.add(current);
      return _cumulativeMeters;
    }

    final segmentMeters = _haversine.as(
      LengthUnit.Meter,
      _lastPosition!,
      current,
    );

    // Jitter gate: ignore micro-movements.
    if (segmentMeters < minSegmentMeters) {
      return _cumulativeMeters;
    }

    // Teleport gate: ignore impossibly large jumps.
    if (segmentMeters > maxSegmentMeters) {
      return _cumulativeMeters;
    }

    // Accept this segment.
    _cumulativeMeters += segmentMeters;
    _lastPosition = current;
    _breadcrumbs.add(current);

    return _cumulativeMeters;
  }

  /// Reset the calculator for a new session.
  void reset() {
    _lastPosition = null;
    _cumulativeMeters = 0.0;
    _breadcrumbs.clear();
  }
}
