import 'package:fit_odyssey/core/heritage_trek/providers/heritage_trek_providers.dart';
import 'package:fit_odyssey/core/heritage_trek/services/walking_route_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('WalkingRouteService', () {
    test('walkingRouteServiceProvider resolves WalkingRouteService singleton', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(walkingRouteServiceProvider);
      expect(service, isA<WalkingRouteService>());
    });

    test('fallback returns origin and destination when unreachable', () async {
      final service = WalkingRouteService();
      addTearDown(service.dispose);

      // Using non-routable / unreachable coordinates to test graceful fallback
      const origin = LatLng(0.0, 0.0);
      const destination = LatLng(0.001, 0.001);

      final route = await service.fetchWalkingRoute(
        origin: origin,
        destination: destination,
      );

      // Must never crash and return at least 2 points
      expect(route, isNotEmpty);
      expect(route.length, greaterThanOrEqualTo(2));
      expect(route.first.latitude, closeTo(origin.latitude, 0.001));
      expect(route.last.latitude, closeTo(destination.latitude, 0.001));
    });

    test('real road routing between nearby points returns valid coordinates', () async {
      final service = WalkingRouteService();
      addTearDown(service.dispose);

      // Bhubaneswar coordinates (Lingaraj temple area)
      const origin = LatLng(20.2388, 85.8340);
      const destination = LatLng(20.2450, 85.8400);

      final route = await service.fetchWalkingRoute(
        origin: origin,
        destination: destination,
      );

      expect(route, isNotEmpty);
      expect(route.length, greaterThanOrEqualTo(2));
      for (final pt in route) {
        expect(pt.latitude, inInclusiveRange(-90.0, 90.0));
        expect(pt.longitude, inInclusiveRange(-180.0, 180.0));
      }
    });
  });
}
