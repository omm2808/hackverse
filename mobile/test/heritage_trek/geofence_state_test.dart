import 'package:flutter_test/flutter_test.dart';
import 'package:fit_odyssey/core/heritage_trek/models/geofence_state.dart';

void main() {
  group('GeofenceState', () {
    test('initial state has zero hits and not arrived', () {
      const state = GeofenceState();
      expect(state.consecutiveHitsInZone, 0);
      expect(state.hasArrived, false);
    });

    test('single reading inside radius increments counter', () {
      const state = GeofenceState();
      final next = state.processReading(20.0); // 20m < 30m
      expect(next.consecutiveHitsInZone, 1);
      expect(next.hasArrived, false);
    });

    test('reading outside radius resets counter to zero', () {
      const state = GeofenceState(consecutiveHitsInZone: 3);
      final next = state.processReading(50.0); // 50m > 30m
      expect(next.consecutiveHitsInZone, 0);
      expect(next.hasArrived, false);
    });

    test('reading exactly at 30m radius counts as inside', () {
      const state = GeofenceState();
      final next = state.processReading(30.0); // boundary
      expect(next.consecutiveHitsInZone, 1);
      expect(next.hasArrived, false);
    });

    test('reading at 30.001m is outside radius', () {
      const state = GeofenceState();
      final next = state.processReading(30.001);
      expect(next.consecutiveHitsInZone, 0);
      expect(next.hasArrived, false);
    });

    test('5 consecutive hits triggers arrival', () {
      var state = const GeofenceState();
      for (var i = 0; i < 5; i++) {
        state = state.processReading(15.0);
      }
      expect(state.consecutiveHitsInZone, 5);
      expect(state.hasArrived, true);
    });

    test('4 consecutive hits does NOT trigger arrival', () {
      var state = const GeofenceState();
      for (var i = 0; i < 4; i++) {
        state = state.processReading(10.0);
      }
      expect(state.consecutiveHitsInZone, 4);
      expect(state.hasArrived, false);
    });

    test('jitter at hit 4 resets counter — arrival requires restart', () {
      var state = const GeofenceState();
      // 4 consecutive hits inside
      for (var i = 0; i < 4; i++) {
        state = state.processReading(15.0);
      }
      expect(state.consecutiveHitsInZone, 4);

      // GPS jitter pushes outside
      state = state.processReading(45.0);
      expect(state.consecutiveHitsInZone, 0);
      expect(state.hasArrived, false);

      // Must restart the 5-hit sequence
      for (var i = 0; i < 4; i++) {
        state = state.processReading(15.0);
      }
      expect(state.consecutiveHitsInZone, 4);
      expect(state.hasArrived, false);

      // 5th hit completes arrival
      state = state.processReading(15.0);
      expect(state.consecutiveHitsInZone, 5);
      expect(state.hasArrived, true);
    });

    test('once arrived, further readings do not change state', () {
      const arrivedState = GeofenceState(
        consecutiveHitsInZone: 5,
        hasArrived: true,
      );

      // Reading inside
      final s1 = arrivedState.processReading(10.0);
      expect(s1.hasArrived, true);
      expect(s1.consecutiveHitsInZone, 5);

      // Reading outside
      final s2 = arrivedState.processReading(100.0);
      expect(s2.hasArrived, true);
      expect(s2.consecutiveHitsInZone, 5);
    });

    test('zero distance counts as inside', () {
      const state = GeofenceState();
      final next = state.processReading(0.0);
      expect(next.consecutiveHitsInZone, 1);
    });

    test('negative distance counts as inside', () {
      // Shouldn't happen in practice, but defensive behavior.
      const state = GeofenceState();
      final next = state.processReading(-5.0);
      expect(next.consecutiveHitsInZone, 1);
    });

    test('mixed inside-outside pattern never arrives', () {
      var state = const GeofenceState();
      // Alternating inside/outside for 20 readings
      for (var i = 0; i < 20; i++) {
        final distance = (i % 2 == 0) ? 15.0 : 50.0;
        state = state.processReading(distance);
      }
      expect(state.hasArrived, false);
      // Last reading was outside (i=19, odd → 50m), so counter = 0
      expect(state.consecutiveHitsInZone, 0);
    });

    test('equality and hashCode', () {
      const a = GeofenceState(consecutiveHitsInZone: 3, hasArrived: false);
      const b = GeofenceState(consecutiveHitsInZone: 3, hasArrived: false);
      const c = GeofenceState(consecutiveHitsInZone: 3, hasArrived: true);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('toString contains hit count and arrival status', () {
      const state = GeofenceState(consecutiveHitsInZone: 3, hasArrived: false);
      expect(state.toString(), contains('3'));
      expect(state.toString(), contains('false'));
    });

    test('constants are correct', () {
      expect(GeofenceState.arrivalRadiusMeters, 30.0);
      expect(GeofenceState.requiredConsecutiveHits, 5);
    });
  });

  group('GeofenceState — stress', () {
    test('exactly requiredConsecutiveHits readings at boundary arrive', () {
      var state = const GeofenceState();
      for (var i = 0; i < GeofenceState.requiredConsecutiveHits; i++) {
        state = state.processReading(GeofenceState.arrivalRadiusMeters);
      }
      expect(state.hasArrived, true);
    });

    test('many readings just outside never trigger arrival', () {
      var state = const GeofenceState();
      for (var i = 0; i < 1000; i++) {
        state = state.processReading(30.1);
      }
      expect(state.hasArrived, false);
      expect(state.consecutiveHitsInZone, 0);
    });
  });
}
