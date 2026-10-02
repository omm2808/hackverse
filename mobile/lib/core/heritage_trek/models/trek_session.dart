import 'package:latlong2/latlong.dart';

import 'geofence_state.dart';
import 'heritage_site.dart';

/// Represents the live state of an ongoing Heritage Trek session.
///
/// GPS distance and pedometer steps are tracked **completely separately**:
/// - [gpsDistanceMeters] is the primary measure, accumulated via Haversine.
/// - [pedometerSteps] is displayed for user interest only and is NOT
///   converted to or added to GPS distance.
class TrekSession {
  /// The heritage site the user is walking toward.
  final HeritageSite destination;

  /// Cumulative GPS-derived walking distance in meters.
  /// This is the PRIMARY distance metric.
  final double gpsDistanceMeters;

  /// Pedometer step count since session start.
  /// Tracked SEPARATELY — never added to [gpsDistanceMeters].
  final int pedometerSteps;

  /// GPS breadcrumb trail for map display.
  /// Each point is a filtered GPS reading accepted by the distance calculator.
  final List<LatLng> breadcrumbs;

  /// Arrival protection state machine.
  final GeofenceState geofenceState;

  /// When this trek session was started.
  final DateTime startedAt;

  /// Whether the trek has been completed (arrival confirmed by geofence).
  final bool isCompleted;

  const TrekSession({
    required this.destination,
    this.gpsDistanceMeters = 0.0,
    this.pedometerSteps = 0,
    this.breadcrumbs = const [],
    this.geofenceState = const GeofenceState(),
    required this.startedAt,
    this.isCompleted = false,
  });

  /// Create a modified copy of this session.
  TrekSession copyWith({
    HeritageSite? destination,
    double? gpsDistanceMeters,
    int? pedometerSteps,
    List<LatLng>? breadcrumbs,
    GeofenceState? geofenceState,
    DateTime? startedAt,
    bool? isCompleted,
  }) {
    return TrekSession(
      destination: destination ?? this.destination,
      gpsDistanceMeters: gpsDistanceMeters ?? this.gpsDistanceMeters,
      pedometerSteps: pedometerSteps ?? this.pedometerSteps,
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      geofenceState: geofenceState ?? this.geofenceState,
      startedAt: startedAt ?? this.startedAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  String toString() =>
      'TrekSession(dest: ${destination.id}, '
      'gps: ${gpsDistanceMeters.toStringAsFixed(1)}m, '
      'steps: $pedometerSteps, '
      'arrived: ${geofenceState.hasArrived})';
}
