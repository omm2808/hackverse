/// Geofence arrival protection state machine.
///
/// Tracks consecutive GPS readings within the arrival radius to prevent
/// GPS jitter from falsely completing a trek. The user must remain within
/// [arrivalRadiusMeters] for [requiredConsecutiveHits] consecutive readings
/// before arrival is confirmed.
class GeofenceState {
  /// Radius in meters from the destination center within which a reading
  /// counts as "inside the geofence."
  static const double arrivalRadiusMeters = 30.0;

  /// Number of consecutive readings inside the geofence required to
  /// confirm arrival. Prevents single GPS spikes from triggering completion.
  static const int requiredConsecutiveHits = 5;

  /// How many consecutive GPS readings have been inside the geofence.
  final int consecutiveHitsInZone;

  /// Whether the user has been confirmed as arrived.
  final bool hasArrived;

  const GeofenceState({
    this.consecutiveHitsInZone = 0,
    this.hasArrived = false,
  });

  /// Process a new GPS distance reading to the destination.
  ///
  /// Returns a new [GeofenceState]:
  /// - If already arrived, returns `this` unchanged.
  /// - If [distanceToDestinationMeters] ≤ [arrivalRadiusMeters], increments
  ///   the consecutive hit counter. If counter reaches [requiredConsecutiveHits],
  ///   sets [hasArrived] to true.
  /// - If outside the radius, resets the counter to zero.
  GeofenceState processReading(double distanceToDestinationMeters) {
    if (hasArrived) return this;

    if (distanceToDestinationMeters <= arrivalRadiusMeters) {
      final newHits = consecutiveHitsInZone + 1;
      return GeofenceState(
        consecutiveHitsInZone: newHits,
        hasArrived: newHits >= requiredConsecutiveHits,
      );
    } else {
      // Outside the geofence — reset counter.
      return const GeofenceState();
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeofenceState &&
          runtimeType == other.runtimeType &&
          consecutiveHitsInZone == other.consecutiveHitsInZone &&
          hasArrived == other.hasArrived;

  @override
  int get hashCode => Object.hash(consecutiveHitsInZone, hasArrived);

  @override
  String toString() =>
      'GeofenceState(hits: $consecutiveHitsInZone, arrived: $hasArrived)';
}
