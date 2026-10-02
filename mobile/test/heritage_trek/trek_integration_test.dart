import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:fit_odyssey/core/heritage_trek/models/geofence_state.dart';
import 'package:fit_odyssey/core/heritage_trek/models/heritage_site.dart';
import 'package:fit_odyssey/core/heritage_trek/models/trek_session.dart';
import 'package:fit_odyssey/core/heritage_trek/repositories/heritage_site_repository.dart';
import 'package:fit_odyssey/core/heritage_trek/services/geofence_checker.dart';
import 'package:fit_odyssey/core/heritage_trek/services/trek_distance_calculator.dart';

/// Integration tests verifying the Heritage Trek business logic:
/// - Distance calculation pipeline
/// - Geofence checker + site integration
/// - TrekSession state transitions
/// - Repository-driven site lookup for trek flow
void main() {
  group('TrekDistanceCalculator', () {
    late TrekDistanceCalculator calculator;

    setUp(() {
      calculator = TrekDistanceCalculator();
    });

    test('first position sets baseline, distance remains 0', () {
      final pos = _makePosition(20.2388, 85.8340, accuracy: 10.0);
      final dist = calculator.addPosition(pos);
      expect(dist, 0.0);
      expect(calculator.breadcrumbs.length, 1);
    });

    test('two positions accumulate Haversine distance', () {
      calculator.addPosition(
          _makePosition(20.2388, 85.8340, accuracy: 10.0));
      final dist = calculator.addPosition(
          _makePosition(20.2390, 85.8342, accuracy: 10.0));
      // ~30m movement — should register
      expect(dist, greaterThan(5.0));
      expect(calculator.breadcrumbs.length, 2);
    });

    test('low accuracy reading is discarded', () {
      calculator.addPosition(
          _makePosition(20.2388, 85.8340, accuracy: 10.0));
      final dist = calculator.addPosition(
          _makePosition(20.2400, 85.8400, accuracy: 50.0)); // >25m accuracy
      expect(dist, 0.0);
      expect(calculator.breadcrumbs.length, 1);
    });

    test('jitter under 2m is discarded', () {
      calculator.addPosition(
          _makePosition(20.238800, 85.834000, accuracy: 5.0));
      // ~0.5m shift — well below 2m jitter gate
      final dist = calculator.addPosition(
          _makePosition(20.238803, 85.834003, accuracy: 5.0));
      expect(dist, 0.0);
      expect(calculator.breadcrumbs.length, 1);
    });

    test('teleport over 100m is discarded', () {
      calculator.addPosition(
          _makePosition(20.2388, 85.8340, accuracy: 10.0));
      // ~1km jump
      final dist = calculator.addPosition(
          _makePosition(20.2480, 85.8340, accuracy: 10.0));
      expect(dist, 0.0);
      expect(calculator.breadcrumbs.length, 1);
    });

    test('reset clears all state', () {
      calculator.addPosition(
          _makePosition(20.2388, 85.8340, accuracy: 10.0));
      calculator.addPosition(
          _makePosition(20.2390, 85.8342, accuracy: 10.0));
      expect(calculator.totalDistanceMeters, greaterThan(0));
      expect(calculator.breadcrumbs.length, 2);

      calculator.reset();
      expect(calculator.totalDistanceMeters, 0.0);
      expect(calculator.breadcrumbs, isEmpty);
    });

    test('multiple valid segments accumulate correctly', () {
      // Walk a path of ~4 valid segments
      calculator.addPosition(
          _makePosition(20.23880, 85.83400, accuracy: 10.0));
      calculator.addPosition(
          _makePosition(20.23910, 85.83420, accuracy: 10.0));
      calculator.addPosition(
          _makePosition(20.23940, 85.83440, accuracy: 10.0));
      calculator.addPosition(
          _makePosition(20.23970, 85.83460, accuracy: 10.0));

      expect(calculator.totalDistanceMeters, greaterThan(50.0));
      expect(calculator.breadcrumbs.length, 4);
    });
  });

  group('GeofenceChecker with real site', () {
    late GeofenceChecker checker;
    late HeritageSite lingarajTemple;

    setUp(() {
      checker = GeofenceChecker();
      final repo = HeritageSiteRepository();
      lingarajTemple = repo.getSiteById('lingaraj_temple')!;
    });

    test('user far from site returns zero hits', () {
      final state = checker.check(
        currentPosition: _makePosition(20.0, 85.0, accuracy: 10.0),
        destination: lingarajTemple,
        currentState: const GeofenceState(),
      );
      expect(state.consecutiveHitsInZone, 0);
      expect(state.hasArrived, false);
    });

    test('user at the exact site location increments hit', () {
      final state = checker.check(
        currentPosition: _makePosition(
          lingarajTemple.latitude,
          lingarajTemple.longitude,
          accuracy: 5.0,
        ),
        destination: lingarajTemple,
        currentState: const GeofenceState(),
      );
      expect(state.consecutiveHitsInZone, 1);
    });

    test('five consecutive readings at site triggers arrival', () {
      var state = const GeofenceState();
      for (var i = 0; i < 5; i++) {
        state = checker.check(
          currentPosition: _makePosition(
            lingarajTemple.latitude,
            lingarajTemple.longitude,
            accuracy: 5.0,
          ),
          destination: lingarajTemple,
          currentState: state,
        );
      }
      expect(state.hasArrived, true);
    });

    test('distanceToSite returns reasonable distance', () {
      // From a known point ~5km away
      final dist = checker.distanceToSite(
        currentPosition: _makePosition(20.1927, 85.8497, accuracy: 10.0),
        destination: lingarajTemple,
      );
      // Dhauli Stupa to Lingaraj is ~5-6 km
      expect(dist, greaterThan(3000));
      expect(dist, lessThan(10000));
    });
  });

  group('TrekSession state transitions', () {
    late HeritageSite site;

    setUp(() {
      final repo = HeritageSiteRepository();
      site = repo.getSiteById('konark_sun_temple')!;
    });

    test('new session starts with zero distance and steps', () {
      final session = TrekSession(
        destination: site,
        startedAt: DateTime.now(),
      );
      expect(session.gpsDistanceMeters, 0.0);
      expect(session.pedometerSteps, 0);
      expect(session.isCompleted, false);
      expect(session.breadcrumbs, isEmpty);
    });

    test('copyWith updates GPS distance independently of steps', () {
      var session = TrekSession(
        destination: site,
        startedAt: DateTime.now(),
      );

      // Update GPS distance
      session = session.copyWith(gpsDistanceMeters: 150.0);
      expect(session.gpsDistanceMeters, 150.0);
      expect(session.pedometerSteps, 0); // Steps unchanged

      // Update steps
      session = session.copyWith(pedometerSteps: 200);
      expect(session.gpsDistanceMeters, 150.0); // Distance unchanged
      expect(session.pedometerSteps, 200);
    });

    test('isCompleted follows geofence arrival', () {
      var session = TrekSession(
        destination: site,
        startedAt: DateTime.now(),
      );

      expect(session.isCompleted, false);

      // Simulate geofence arrival
      session = session.copyWith(
        geofenceState: const GeofenceState(
          consecutiveHitsInZone: 5,
          hasArrived: true,
        ),
        isCompleted: true,
      );

      expect(session.isCompleted, true);
      expect(session.geofenceState.hasArrived, true);
    });

    test('breadcrumbs update preserves other fields', () {
      var session = TrekSession(
        destination: site,
        startedAt: DateTime.now(),
        gpsDistanceMeters: 100.0,
        pedometerSteps: 50,
      );

      session = session.copyWith(
        breadcrumbs: [const LatLng(20.0, 85.0), const LatLng(20.1, 85.1)],
      );

      expect(session.breadcrumbs.length, 2);
      expect(session.gpsDistanceMeters, 100.0);
      expect(session.pedometerSteps, 50);
    });
  });

  group('Repository → Trek flow integration', () {
    late HeritageSiteRepository repo;

    setUp(() {
      repo = HeritageSiteRepository();
    });

    test('all sites can be used as trek destinations', () {
      final sites = repo.getSitesForJourney('odisha_golden_triangle');
      for (final site in sites) {
        final session = TrekSession(
          destination: site,
          startedAt: DateTime.now(),
        );
        expect(session.destination.id, site.id);
        expect(session.destination.latitude, isNotNaN);
        expect(session.destination.longitude, isNotNaN);
      }
    });

    test('getNextDestination sequences through all 5 sites', () {
      for (var i = 0; i < 5; i++) {
        final site = repo.getNextDestination('odisha_golden_triangle', i);
        expect(site, isNotNull);
        expect(site!.unlockOrder, i + 1);
      }
      // After all 5, returns null
      expect(repo.getNextDestination('odisha_golden_triangle', 5), isNull);
    });
  });
}

/// Helper: create a [Position] for testing.
Position _makePosition(double lat, double lng, {required double accuracy}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now(),
    accuracy: accuracy,
    altitude: 0.0,
    altitudeAccuracy: 0.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );
}
