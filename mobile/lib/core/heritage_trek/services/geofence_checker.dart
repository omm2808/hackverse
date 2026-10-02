import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/geofence_state.dart';
import '../models/heritage_site.dart';

/// Checks whether the user has arrived at a heritage site destination.
///
/// Uses Haversine distance from the current GPS position to the destination
/// coordinates. Feeds the distance into [GeofenceState] which requires
/// [GeofenceState.requiredConsecutiveHits] consecutive readings within
/// [GeofenceState.arrivalRadiusMeters] before confirming arrival.
///
/// This prevents GPS jitter from falsely completing a trek.
class GeofenceChecker {
  final Distance _haversine = const Distance();

  /// Check the current position against the destination and update the
  /// geofence state.
  ///
  /// Returns the updated [GeofenceState] after processing this reading.
  GeofenceState check({
    required Position currentPosition,
    required HeritageSite destination,
    required GeofenceState currentState,
  }) {
    final currentLatLng = LatLng(
      currentPosition.latitude,
      currentPosition.longitude,
    );
    final destinationLatLng = LatLng(
      destination.latitude,
      destination.longitude,
    );

    final distanceMeters = _haversine.as(
      LengthUnit.Meter,
      currentLatLng,
      destinationLatLng,
    );

    return currentState.processReading(distanceMeters);
  }

  /// Compute the raw distance in meters from a position to a site.
  /// Useful for UI display ("X meters to destination").
  double distanceToSite({
    required Position currentPosition,
    required HeritageSite destination,
  }) {
    return _haversine.as(
      LengthUnit.Meter,
      LatLng(currentPosition.latitude, currentPosition.longitude),
      LatLng(destination.latitude, destination.longitude),
    );
  }
}
